//
//  MJMessageClientProxyImpl.m
//  MJMessaging
//
//  Created by Martin Johannesson on 2012-06-16.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MJMessageClientProxyImpl.h"
#import "GCDAsyncSocket.h"

#define kMJMessageSizeTag 0L
#define kMJMessageContentTag 1L

@interface MJMessageClientProxyImpl ()


@end


@implementation MJMessageClientProxyImpl

@synthesize delegate = _delegate;
@synthesize context = _context;
@synthesize socket = _socket;

- (id)initWithSocket:(id)socket
{
    self = [super init];
    if (self) {
        self.socket = socket;
    }
    
    return self;
}

- (void)sendMessage:(NSDictionary *)message
{
    if (!self.socket)
        return;
    
    char messageSizeStr[9];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:0
                                                         error:nil];
    uint32_t messageSize = (uint32_t)jsonData.length;
    sprintf(messageSizeStr, "%8x", messageSize);
    NSData *sizeData = [NSData dataWithBytes:messageSizeStr
                                      length:8];
    
    [self.socket writeData:sizeData withTimeout:-1.0 tag:kMJMessageSizeTag];
    [self.socket writeData:jsonData withTimeout:-1.0 tag:kMJMessageContentTag];
}

@end
