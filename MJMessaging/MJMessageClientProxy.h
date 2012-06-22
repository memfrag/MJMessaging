//
//  MJMessageClientProxy.h
//  MJMessaging
//
//  Created by Martin Johannesson on 2012-06-16.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MJMessageClientProxyDelegate;

@protocol MJMessageClientProxy <NSObject>

@property (nonatomic, weak) id<MJMessageClientProxyDelegate> delegate;

@property (nonatomic, weak) id context;

- (void)sendMessage:(NSDictionary *)message;

@end


@protocol MJMessageClientProxyDelegate <NSObject>

- (void)didReceiveMessage:(NSDictionary *)message
               fromClient:(id<MJMessageClientProxy>)client;

@end
