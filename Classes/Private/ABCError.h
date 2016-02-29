//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirbitzCore+Internal.h"

@interface ABCError : NSObject

/*
 * errorMap
 * @param  ABCConditionCode: error code to look up
 * @return NSString*       : text description of error
 */
+ (NSString *)conditionCodeMap:(const ABCConditionCode) code;

+ (NSError *) makeNSError:(tABC_Error)error;

@end