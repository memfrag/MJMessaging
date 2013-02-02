//
//  MJMessageClientProxyImpl.m
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

#import "MJMessageClientProxyImpl.h"
#import "GCDAsyncSocket.h"

#define kMJMessageSizeTag 0L
#define kMJMessageContentTag 1L

@interface MJMessageClientProxyImpl ()


@end


@implementation MJMessageClientProxyImpl

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
    
    [self.socket writeData:sizeData withTimeout:-1 tag:kMJMessageSizeTag];
    [self.socket writeData:jsonData withTimeout:-1 tag:kMJMessageContentTag];
}

@end
