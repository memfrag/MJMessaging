//
//  MJMessageClient.h
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
#import "GCDAsyncSocket.h"

@protocol MJMessageClientDelegate;


@interface MJMessageClient : NSObject <NSNetServiceDelegate, GCDAsyncSocketDelegate>

@property (nonatomic, weak) IBOutlet id<MJMessageClientDelegate> delegate;

- (void)connectToService:(NSNetService *)service;

- (void)connectToServiceByAddress:(NSData *)serviceAddress;

- (void)disconnect;

- (void)sendMessage:(NSDictionary *)message;

@end

@protocol MJMessageClientDelegate <NSObject>

- (void)client:(MJMessageClient *)client didConnectToHost:(NSString *)host port:(UInt16)port;

- (void)client:(MJMessageClient *)client didNotConnectToAddress:(NSData *)serviceAddress error:(NSError *)error;

- (void)client:(MJMessageClient *)client didNotResolveService:(NSNetService *)service error:(NSDictionary *)error;

- (void)client:(MJMessageClient *)client didDisconnectWithError:(NSError *)error;

- (void)client:(MJMessageClient *)client didReceiveMessage:(NSDictionary *)message;


@end
