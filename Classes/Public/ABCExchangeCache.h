//
// ABCExchangeCache.h
//
// Created by Paul Puey on 2016/02/27
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@class AirbitzCore;
@class ABCSpend;
@class ABCSettings;
@class ABCReceiveAddress;
@class ABCTransaction;

#define ABCArrayExchanges     @[@"Bitstamp", @"BraveNewCoin", @"Coinbase", @"CleverCoin"]

@interface ABCExchangeCache : NSObject

/// -----------------------------------------------------------------------------
/// @name ABCExchangeCache currency public read-only variables
/// -----------------------------------------------------------------------------

/**
 * Convert bitcoin amount in satoshis to a fiat currency amount
 * @param satoshi uint_64t amount to convert in satoshis
 * @param currencyCode NSSTring* ISO currency code of fiat currency to convert to.
 * ie "USD, CAD, EUR"
 * @param error NSError** pointer to NSError object
 * @return double resulting fiat currency value
 */
- (double) satoshiToCurrency:(uint64_t) satoshi
                currencyCode:(NSString *)currencyCode
                       error:(NSError **)error;

/**
 * Convert fiat currency amount to a bitcoin amount in satoshis
 * @param double Amount in fiat value to convert
 * @param currencyCode NSSTring* ISO currency code of fiat currency to convert to. 
 * ie "USD, CAD, EUR"
 * @param error NSError** pointer to NSError object
 * @return uint_64t Resulting value in satoshis
 */
- (uint64_t) currencyToSatoshi:(double)currency
                  currencyCode:(NSString *)currencyCode
                         error:(NSError **)error;


@end


