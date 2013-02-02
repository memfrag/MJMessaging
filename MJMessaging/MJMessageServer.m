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
#import "GCDAsyncSocket.h"
#import "MJMessageClientProxyImpl.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#define kMJMessageSizeTag 0L
#define kMJMessageContentTag 1L

#define kMJMaximumMessageSize 1000000

@implementation MJMessageServer {
    dispatch_queue_t _socketQueue;
    GCDAsyncSocket *_serverSocket;
    NSMutableArray *_connectedSockets;
    NSNetService *_service;
    NSMutableArray *_clients;
    
    uint16_t _port;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self registerForNotifications];
        
        _socketQueue = dispatch_queue_create("socketQueue", NULL);
    }
    
    return self;
}

#pragma mark - App state notifications

- (void)registerForNotifications
{
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stop)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(suspendServer)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resumeServer)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#endif
}

#pragma mark - Starting and stopping the server

- (void)startWithPort:(uint16_t)port;
{
    _connectedSockets = [NSMutableArray arrayWithCapacity:10];
    _clients = [NSMutableArray arrayWithCapacity:10];
    
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                               delegateQueue:_socketQueue];
    
    NSError __autoreleasing *error = nil;
    if(![_serverSocket acceptOnPort:port error:&error])
    {
        NSLog(@"ERROR: %@", @"Unable to accept on server socket.");
        _serverSocket = nil;
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(serverDidNotStart:error:)]) {
            [self.delegate serverDidNotStart:self error:error];
        }
    }
}

- (void)stop
{
    if ([_serverSocket isConnected]) {
        [_serverSocket disconnect];
    }
    _serverSocket = nil;
    
    for (GCDAsyncSocket *socket in _connectedSockets) {
        [socket disconnect];
    }
    
    [_connectedSockets removeAllObjects];
    _connectedSockets = nil;
    
    [_clients removeAllObjects];
    _clients = nil;
}

- (void)resumeServer
{
    [self startWithPort:_port];
}

- (void)suspendServer
{
    [self stop];
}

#pragma mark - GCDAsyncSocket delegate methods

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	// This method is executed on the socketQueue (not the main thread)
    MJMessageClientProxyImpl *newClient;
    
	@synchronized(_connectedSockets) {
		[_connectedSockets addObject:newSocket];
        
        newClient = [[MJMessageClientProxyImpl alloc] initWithSocket:newSocket];
        [_clients addObject:newClient];
        
        newSocket.userData = newClient;
	}
    
    if (_delegate && [_delegate respondsToSelector:@selector(server:clientDidConnect:)]) {
        [_delegate server:self clientDidConnect:newClient];
    }
	
	[newSocket readDataToLength:8 withTimeout:-1 tag:kMJMessageSizeTag];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)err
{
	if (socket != _serverSocket) {
        @synchronized(_connectedSockets) {
            [_clients removeObject:socket.userData];
			[_connectedSockets removeObject:socket];
		}
        
        if (_delegate && [_delegate respondsToSelector:@selector(server:clientDidConnect:)]) {
            [_delegate server:self clientDidDisconnect:nil];
        }
	}
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag
{
	// This method is executed on the socketQueue (not the main thread)
    if (tag == kMJMessageSizeTag) {
        char size[9];
        strncpy(size, [data bytes], 8);
        size[8] = 0;
        
        uint32_t messageSize;
        sscanf(size, "%x", &messageSize);
        
        if ((messageSize) > kMJMaximumMessageSize) {
            NSLog(@"ERROR: %@", @"Message exceeds maximum size!");
            NSAssert(NO, @"ASSERT: This message is too big.");
            return;
        }
        
        [socket readDataToLength:messageSize withTimeout:-1 tag:kMJMessageContentTag];
    } else if (tag == kMJMessageContentTag) {
        __autoreleasing NSError *error = nil;
        NSDictionary *message = [NSJSONSerialization JSONObjectWithData:data
                                                                options:0
                                                                  error:&error];
        if (error) {
            NSLog(@"ERROR: %@", error.localizedDescription);
            [socket disconnect];
            return;
        }
        
        MJMessageClientProxyImpl *client = socket.userData;
        
        if (client.delegate && [client.delegate respondsToSelector:@selector(didReceiveMessage:fromClient:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [client.delegate didReceiveMessage:message
                                        fromClient:client];
            });
        }
        
        [socket readDataToLength:8 withTimeout:-1 tag:kMJMessageSizeTag];
    } else {
        NSAssert(NO, @"ASSERT: This should not happen");
    }
}

- (void)sendMessage:(NSDictionary *)message
{
	for (MJMessageClientProxyImpl *client in _clients) {
        [self sendMessage:message toClient:client];
	}
}

- (void)sendMessage:(NSDictionary *)message
           toClient:(id<MJMessageClientProxy>)client
{
    if (client) {
        [client sendMessage:message];
    }
}

#pragma mark - Publish service using Bonjour

- (void)publishServiceWithName:(NSString *)name type:(NSString *)type
{
	[self publishServiceWithName:name type:type domain:@"local."];
}

- (void)publishServiceWithName:(NSString *)name type:(NSString *)type domain:(NSString *)domain
{
    if (_serverSocket) {
        _service = [[NSNetService alloc] initWithDomain:domain
                                                   type:type
                                                   name:name
                                                   port:_serverSocket.localPort];
        [_service scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _service.delegate = self;
        [_service publish];
    }
}

- (void)unpublishService
{
    if (_service) {
        [_service stop];
        [_service removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _service = nil;
    }
}

#pragma mark - Bonjour delegates

- (void)netServiceDidPublish:(NSNetService *)service
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(serviceDidPublish:)]) {
        [self.delegate serviceDidPublish:service];
    }
}

- (void)netService:(NSNetService *)service didNotPublish:(NSDictionary *)dict
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(serviceDidNotPublish:error:)]) {
        [self.delegate serviceDidNotPublish:service error:dict];
    }
}

- (void)netServiceDidStop:(NSNetService *)service
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(serviceDidStop:)]) {
        [self.delegate serviceDidStop:service];
    }
}

@end
