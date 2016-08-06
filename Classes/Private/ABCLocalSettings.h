//
// ABCLocalSettings.h
//
// Created by Paul P on 1/31/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ABCContext.h"

@class ABCContext;

@interface ABCLocalSettings : NSObject

@property (retain)   NSString        *lastLoggedInAccount;
@property (retain)   NSMutableArray  *touchIDUsersEnabled;
@property (retain)   NSMutableArray  *touchIDUsersDisabled;

- (id)init:(ABCContext *)abc;
- (void)loadAll;
- (void)saveAll;

@end