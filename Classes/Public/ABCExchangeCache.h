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

#define ABCArrayExchanges     @[@"Bitstamp", @"Bitfinex", @"BitcoinAverage", @"BraveNewCoin", @"Coinbase"]

/**
 * ABCExchangeCache provides conversion routines to convert from any fiat currency
 * to BTC in satoshis or vice version. This object uses the exchange rate source
 * set it ABCSettings. Exchange values are cached globally and shared between all
 * incoming requests.
 */

@interface ABCExchangeCache : NSObject

/**
 * Convert bitcoin amount in satoshis to a fiat currency amount
 * @param satoshi uint_64t amount to convert in satoshis
 * @param currencyCode NSSTring* ISO currency code of fiat currency to convert to.
 * ie "USD, CAD, EUR"
 * @param error NSError** pointer to ABCError object
 * @return double resulting fiat currency value
 */
- (double) satoshiToCurrency:(uint64_t) satoshi
                currencyCode:(NSString *)currencyCode
                       error:(ABCError **)error;

/**
 * Convert fiat currency amount to a bitcoin amount in satoshis
 * @param currency (double) Amount in fiat value to convert
 * @param currencyCode NSString* ISO currency code of fiat currency to convert to.
 * ie "USD, CAD, EUR"
 * @param error NSError** pointer to ABCError object
 * @return uint_64t Resulting value in satoshis
 */
- (uint64_t) currencyToSatoshi:(double)currency
                  currencyCode:(NSString *)currencyCode
                         error:(ABCError **)error;


@end


