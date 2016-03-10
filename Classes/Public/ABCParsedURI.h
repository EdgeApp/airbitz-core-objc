//
// ABCParsedURI.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@interface ABCParsedURI : NSObject

@property                           NSString            *address;
@property                           NSString            *privateKey;
//@property                           NSString            *paymentProtocol;
@property                           NSString            *bitIDURI;


@property                           uint64_t            amountSatoshi;
@property                           NSString            *label;
@property                           NSString            *message;
@property                           NSString            *category;
@property                           NSString            *returnURI;

@end
