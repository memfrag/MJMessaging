//
//  MJMessageClientProxyImpl.h
//  MJMessaging
//
//  Created by Martin Johannesson on 2012-06-16.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MJMessageClientProxy.h"

@interface MJMessageClientProxyImpl : NSObject <MJMessageClientProxy>

@property (nonatomic, weak) id<MJMessageClientProxyDelegate> delegate;

@property (nonatomic, weak) id context;

@property (nonatomic, strong) id socket;

- (id)initWithSocket:(id)socket;

@end
