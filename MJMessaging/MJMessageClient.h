//
//  MJMessageClient.h
//  MJMessaging
//
//  Created by Martin Johannesson on 2012-06-16.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
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
