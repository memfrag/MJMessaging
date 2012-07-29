//
//  MJMessageClient.m
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

#import "MJMessageClient.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

@interface MJMessageClient ()

#define kMJMessageSizeTag 0L
#define kMJMessageContentTag 1L

#define kMJMaximumMessageSize 1000000

@property (nonatomic, strong) id socket;

@end

@implementation MJMessageClient

@synthesize verboseLogging = _verboseLogging;
@synthesize delegate = _delegate;
@synthesize socket = _socket;

#pragma mark - Actions

- (void)connectToService:(NSNetService *)service
{
    service.delegate = self;
    
    if (service.addresses.count > 0) {
        NSData *remoteAddress = nil;
        
        for (NSData *address in service.addresses) {
            struct sockaddr *sockAddr = (struct sockaddr *)[address bytes];
            if (sockAddr->sa_family == AF_INET) {
                remoteAddress = address;
                break;
            }
        }
        
        [self connectToServiceByAddress:remoteAddress];
    } else {
        [service resolveWithTimeout:0];
    }
}

- (void)connectToServiceByAddress:(NSData *)serviceAddress
{
    if (self.socket) {
        [self.socket disconnect];
    }
    
    dispatch_queue_t defaultQueue = dispatch_get_global_queue(0, 0);
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                             delegateQueue:defaultQueue];
    
    NSError *error = nil;
    [self.socket connectToAddress:serviceAddress error:&error];
    
    if (error) {
        [self.delegate client:self didNotConnectToAddress:serviceAddress error:error];
    }
}

- (void)disconnect
{
	if (self.socket && [self.socket isConnected]) {
		[self.socket disconnect];
        [self.socket setDelegate:nil];
		self.socket = nil;
	}
}

- (void)sendMessage:(NSDictionary *)message
{
    if (self.socket)
    {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                           options:0
                                                             error:nil];
        
        char messageSizeStr[9];
        uint32_t messageSize = (uint32_t)jsonData.length;
        sprintf(messageSizeStr, "%8x", messageSize);
        NSData *sizeData = [NSData dataWithBytes:messageSizeStr
                                          length:(8 * sizeof(char))]; 
        
        [self.socket writeData:sizeData withTimeout:-1.0 tag:kMJMessageSizeTag];
        [self.socket writeData:jsonData withTimeout:-1.0 tag:kMJMessageContentTag];
    }
}

#pragma mark - GCDASyncSocket Delegate Methods

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    [self.delegate client:self didConnectToHost:host port:port];
    
    [self.socket readDataToLength:8 withTimeout:-1.0 tag:kMJMessageSizeTag];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    self.socket = nil;
    
    [self.delegate client:self didDisconnectWithError:err];
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == kMJMessageSizeTag)
	{
        char length[9];
        strncpy(length, [data bytes], 8);
        length[8] = 0;
        uint32_t messageSize;
        sscanf(length, "%x", &messageSize); 
        
        if (messageSize > kMJMaximumMessageSize) {
            if (self.verboseLogging) NSLog(@"Client: Message size (%u) exceeds max message size.", messageSize);
            [socket disconnect];
            return;
        }
        
        [socket readDataToLength:messageSize withTimeout:-1.0 tag:kMJMessageContentTag];
    }
    else if (tag == kMJMessageContentTag)
	{
        __autoreleasing NSError *error = nil;
        NSDictionary *message = [NSJSONSerialization JSONObjectWithData:data
                                                                options:0
                                                                  error:&error];
        
        if (error) {
            if (self.verboseLogging) NSLog(@"Client: %@", error.localizedDescription);
            [socket disconnect];
            return;
        }
        
        [self.delegate client:self didReceiveMessage:message];
        message = nil;
        
        // Request to read next message size
        [socket readDataToLength:8 withTimeout:-1.0 tag:kMJMessageSizeTag];
    }
    else
	{
        if (self.verboseLogging) NSLog(@"Client: Unknown tag in read of socket data %ld", tag);
        [socket disconnect];
    }
}

#pragma mark - Bonjour Net Service Delegate Methods

- (void)netServiceDidResolveAddress:(NSNetService *)aService
{
    NSData *remoteAddress = nil;
    
    for (NSData *address in aService.addresses) {
        struct sockaddr *sockAddr = (struct sockaddr *)[address bytes];
        if (sockAddr->sa_family == AF_INET) {
            remoteAddress = address;
            break;
        }
	}
    
    [self connectToServiceByAddress:remoteAddress];
}

- (void)netService:(NSNetService *)aService didNotResolve:(NSDictionary *)errorDict
{
    [self.delegate client:self didNotResolveService:aService error:errorDict];
}

@end
