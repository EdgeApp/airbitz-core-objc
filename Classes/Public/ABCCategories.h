//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@class ABCError;

@interface ABCCategories : NSObject

@property (readonly, atomic, assign)      NSArray         *listCategories;

- (ABCError *)addCategory:(NSString *)category;
- (ABCError *)removeCategory:(NSString *)category;
- (ABCError *)saveCategories:(NSArray *)arrayCategories;



@end