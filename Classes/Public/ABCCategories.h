//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@interface ABCCategories : NSObject

@property (readonly, atomic, assign)      NSArray         *listCategories;

- (NSError *)addCategory:(NSString *)category;
- (NSError *)removeCategory:(NSString *)category;
- (NSError *)saveCategories:(NSArray *)arrayCategories;



@end