//
//  MJMessageServer.h
//  MJMessaging
//
//  Created by Martin Johannesson on 2012-06-16.
//  Copyright (c) 2012 Martin Johannesson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "MJMessageClientProxy.h"

@protocol MJMessageServerDelegate;


@interface MJMessageServer : NSObject <GCDAsyncSocketDelegate, NSNetServiceDelegate>

@property (nonatomic, weak) id<MJMessageServerDelegate> delegate;

- (id)init;

- (BOOL)startWithPort:(uint16_t)port error:(__autoreleasing NSError **)error;
- (void)stop;

- (void)publishServiceWithName:(NSString *)name type:(NSString *)type;
- (void)unpublishService;

- (void)sendMessage:(NSDictionary *)message;
- (void)sendMessage:(NSDictionary *)message
           toClient:(id<MJMessageClientProxy>)client;

@end


@protocol MJMessageServerDelegate <NSObject>

- (void)server:(MJMessageServer *)server clientDidConnect:(id<MJMessageClientProxy>)client;
- (void)server:(MJMessageServer *)server clientDidDisconnect:(id<MJMessageClientProxy>)client;

// Will be called for each active network interface.
- (void)serviceDidPublish:(NSNetService *)service;
- (void)serviceDidNotPublish:(NSNetService *)service error:(NSDictionary *)error;
- (void)serviceDidStop:(NSNetService *)service;

@end
