//
// ABCDataStore.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@interface ABCDataStore : NSObject

- (NSError *)dataGet:(NSString *)folder withKey:(NSString *)key data:(NSMutableString *)data;
- (NSError *)dataSet:(NSString *)folder withKey:(NSString *)key withValue:(NSString *)value;
- (NSError *)dataRemoveKey:(NSString *)folder withKey:(NSString *)key;
- (NSError *)dataRemoveFolder:(NSString *)folder;

@end
