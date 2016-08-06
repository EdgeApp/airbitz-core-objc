//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirbitzCore.h"

@interface ABCError : NSError

@property                        NSInteger code;
@property (nonatomic, strong)    NSDictionary *userInfo;
@property (nonatomic, strong)    NSDate *otpResetDate;
@property (nonatomic, strong)    NSString *otpResetToken;

+(ABCError *) errorWithDomain:(NSInteger) code
                     userInfo:(NSDictionary *)userInfo;
@end