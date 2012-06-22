//
//  MJMessageServer.m
//  MJMessaging
//
//  Created by Martin Johannesson on 2012-06-16.
//  Copyright (c) 2012 Martin Johannesson
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "MJMessageServer.h"
#import "MJMessageClientProxyImpl.h"

#define kMJMessageSizeTag 0L
#define kMJMessageContentTag 1L

#define kMJMaximumMessageSize 1000000

@interface MJMessageServer ()

@property (nonatomic, strong) GCDAsyncSocket *serverSocket; 
@property (nonatomic, strong) NSMutableSet *clients;
@property (nonatomic, strong) NSNetService *service;

@end

@implementation MJMessageServer

@synthesize delegate = _delegate;
@synthesize serverSocket = _serverSocket;
@synthesize clients = _clients;
@synthesize service = _service;

- (id)init
{
    self = [super init];
    if (self) {
        self.clients = [NSMutableSet setWithCapacity:10];
    }
    
    return self;
}

#pragma mark - Starting/Stopping Service

- (BOOL)startWithPort:(uint16_t)port error:(__autoreleasing NSError **)error
{
    *error = nil;
    
    dispatch_queue_t defaultQueue = dispatch_get_global_queue(0, 0);
    
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                   delegateQueue:defaultQueue];
    if (![self.serverSocket acceptOnPort:port error:error]) {
        self.serverSocket = nil;
        return NO;
    }
    
    return YES;
}

- (void)stop
{
    if ([self.serverSocket isConnected]) {
        [self.serverSocket disconnect];
    }
    
    self.serverSocket = nil;
}

#pragma mark - Publish Service Using Bonjour

- (void)publishServiceWithName:(NSString *)name type:(NSString *)type
{
	[self publishServiceWithName:name type:type domain:@"local."];
}

- (void)publishServiceWithName:(NSString *)name type:(NSString *)type domain:(NSString *)domain
{
	self.service = [[NSNetService alloc] initWithDomain:domain type:type name:name port:self.serverSocket.localPort];
	[self.service scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	self.service.delegate = self;
	[self.service publish];
}

- (void)unpublishService
{
	[self.service stop];
	[self.service removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	self.service = nil;
}

#pragma mark - Sending Messages

- (void)sendMessage:(NSDictionary *)message
{
	for (MJMessageClientProxyImpl *client in self.clients) {
        [self sendMessage:message toClient:client];
	}    
}

- (void)sendMessage:(NSDictionary *)message toClient:(id<MJMessageClientProxy>)client
{
    [client sendMessage:message];
}

#pragma mark - GCDAsyncSocket Delegate Methods

- (void)socket:(GCDAsyncSocket *)socket didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    MJMessageClientProxyImpl *client = [[MJMessageClientProxyImpl alloc] initWithSocket:newSocket];
    newSocket.userData = newSocket;
    [self.clients addObject:client];
}

- (void)socket:(GCDAsyncSocket *)socket didConnectToHost:(NSString *)host port:(uint16_t)port
{
    MJMessageClientProxyImpl *client = socket.userData;

    if ([self.delegate conformsToProtocol:@protocol(MJMessageServerDelegate)]) {
        [self.delegate server:self clientDidConnect:client];
    }
    
    [socket readDataToLength:8 withTimeout:-1.0 tag:kMJMessageSizeTag];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)err
{
    MJMessageClientProxyImpl *client = socket.userData;
    client.socket = nil;
    
    if ([self.delegate conformsToProtocol:@protocol(MJMessageServerDelegate)]) {
        [self.delegate server:self clientDidDisconnect:client];
    }
    
    [self.clients removeObject:client];
    socket.userData = nil;
}


- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag
{
    MJMessageClientProxyImpl *client = socket.userData;
    
    if (tag == kMJMessageSizeTag) {
        char length[9];
        strncpy(length, [data bytes], 8);
        length[8] = 0;
        
        uint32_t messageSize;
        sscanf(length, "%x", &messageSize); 
        
        if (messageSize > kMJMaximumMessageSize) {
            NSLog(@"Server: Message size (%u) exceeds max message size.", messageSize);
            [socket disconnect];
            return;
        }
        
        // Request to read message content
        [socket readDataToLength:messageSize
                     withTimeout:-1.0
                             tag:kMJMessageContentTag];
    } else if (tag == kMJMessageContentTag) {
        __autoreleasing NSError *error = nil;
        NSDictionary *message = [NSJSONSerialization JSONObjectWithData:data
                                                                options:0
                                                                  error:&error];
        if (error) {
            NSLog(@"Server: %@", error.localizedDescription);
            [socket disconnect];
            return;
        }
        
        [client.delegate didReceiveMessage:message fromClient:client];
        
        // Request to read next message size
        [socket readDataToLength:8
                     withTimeout:-1.0
                             tag:kMJMessageSizeTag];

    } else {
        NSLog(@"Server: Unknown tag in read of socket data %ld", tag);
        [socket disconnect];
    }
}

#pragma mark - Bonjour Net Service Delegate Methods

- (void)netServiceDidPublish:(NSNetService *)service
{
    [self.delegate serviceDidPublish:service];
}

- (void)netServiceDidStop:(NSNetService *)service
{
    [self.delegate serviceDidStop:service];
}

- (void)netService:(NSNetService *)service didNotPublish:(NSDictionary *)dict
{
    [self.delegate serviceDidNotPublish:service error:dict];
}

@end
