//
//  MJMessageServer.h
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

#import <Foundation/Foundation.h>
#import "MJMessageClientProxy.h"
#import "GCDAsyncSocket.h"

@protocol MJMessageServerDelegate;


@interface MJMessageServer : NSObject <GCDAsyncSocketDelegate, NSNetServiceDelegate>

@property (nonatomic, weak) id<MJMessageServerDelegate> delegate;

- (BOOL)startWithPort:(uint16_t)port error:(__autoreleasing NSError **)error;
- (void)stop;

// Type should be on the form @"_whatever._tcp."
- (void)publishServiceWithName:(NSString *)name type:(NSString *)type;
- (void)unpublishService;

- (void)sendMessage:(NSDictionary *)message;
- (void)sendMessage:(NSDictionary *)message
           toClient:(id<MJMessageClientProxy>)client;

@end


@protocol MJMessageServerDelegate <NSObject>

- (void)server:(MJMessageServer *)server clientDidConnect:(id<MJMessageClientProxy>)client;
- (void)server:(MJMessageServer *)server clientDidDisconnect:(id<MJMessageClientProxy>)client;

@optional

// Will be called for each active network interface.
- (void)serviceDidPublish:(NSNetService *)service;
- (void)serviceDidNotPublish:(NSNetService *)service error:(NSDictionary *)error;
- (void)serviceDidStop:(NSNetService *)service;

@end
