//
// ABCError+Internal.h
//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCError.h"
#import "AirbitzCore+Internal.h"

@interface ABCError (Internal)

/*
 * errorMap
 * @param  ABCConditionCode: error code to look up
 * @return NSString*       : text description of error
 */
+ (NSString *)conditionCodeMap:(const ABCConditionCode) code;

+ (NSError *)makeNSError:(tABC_Error)error;
+ (NSError *)makeNSError:(tABC_Error)error description:(NSString *)description;

@end