//
// ABCMetaData.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCContext.h"

@interface ABCMetaData : NSObject

/// Payee name to specify in the request. This should be the name of the entity intended to
/// pay the request. This is auto tagged to transaction meta data for all incoming
/// transactions to the address from this request
@property (nonatomic, copy)         NSString                *payeeName;

/// The category to tag all transactions incoming to this request's address
@property (nonatomic, copy)         NSString                *category;

/// Misc notes to tag all transactions incoming to this request's address
@property (nonatomic, copy)         NSString                *notes;

/// An Airbitz Directory bizid to tag all transactions incoming to this request's address
@property (nonatomic)               unsigned int            bizId;

/// Amount of transaction in fiat (USD, EUR, CAD) value.
@property (nonatomic)               double                  amountFiat;

@end
