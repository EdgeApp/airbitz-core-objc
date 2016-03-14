//
// ABCParsedURI.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@class ABCPaymentRequest;

@interface ABCParsedURI : NSObject

@property                           NSString            *address;
@property                           NSString            *privateKey;
@property                           NSString            *bitIDURI;
@property                           NSString            *paymentRequestURL;
@property                           uint64_t            amountSatoshi;
@property                           ABCMetaData         *metadata;
@property                           NSString            *returnURI;

- (ABCPaymentRequest *) getPaymentRequest:(NSError **)error;

@end
