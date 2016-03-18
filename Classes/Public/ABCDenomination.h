//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

typedef NS_ENUM(NSUInteger, ABCDenominationMultiplier) {
    ABCDenominationMultiplierBTC = 100000000,
    ABCDenominationMultiplierMBTC = 100000,
    ABCDenominationMultiplierUBTC = 100,
};

/**
 * ABCDenomination represents a specific bitcoin denomination such as BTC, mBTC, or bits (uBTC).
 * The class also includes several utility methods to convert to/from 64 bit satoshi amounts and
 * user viewable strings in the current denomination.
 */
@interface ABCDenomination : NSObject

/// Index of this denomination in the list of denominations.<br>
/// 0 = BTC, 1 = mBTC, 2 = bits
@property (nonatomic)       int             index;

/// Number of satoshis to equal one unit of this  denomination<br>
/// ie. 1 BTC -> multiplier = 100,000,000<br>
/// 1 mBTC -> multipliers = 100,000
@property (nonatomic)       int             multiplier;

/// Denomination symbol such as "Ƀ"
@property (nonatomic)       NSString        *symbol;

/// Denomination label such as "BTC" or "bits"
@property (nonatomic)       NSString        *label;


/**
 * Returns the maximum number of decimal places represented by this denomination
 * @return int Maximum decimal places. BTC=8, mBTC=5, bits=2
 */
- (int) maxBitcoinDecimalPlaces;

/**
 * Returns the 'pretty' number of decimal places represented by this denomination.
 * Due to the large number of subunits of bitcoin, several decimal places represent
 * units of value considered to be uninteresting to users. This returns the number of
 * decimal places to represent no less than .001 USD.
 * @return int Maximum decimal places
 */
- (int) prettyBitcoinDecimalPlaces;

/**
 * Convert a 64 bit satoshi value to a string using the current denomination. Routine will automatically
 * apply the correct conversion to BTC/mBTC/bits based on this objects denomination
 * @param satoshi int64_t Signed satoshi amount to convert
 * @param symbol (optional) bool YES if routine should add a denomination symbol such as "Ƀ" before the amount
 * @param cropDecimals (optional) bool YES if routine should only show the number of decimal places specified by
 *  prettyBitcoinDecimalPlaces
 * @return NSString String representation of bitcoin amount
 */
- (NSString *)satoshiToBTCString:(int64_t) satoshi withSymbol:(bool) symbol cropDecimals:(bool) cropDecimals;
- (NSString *)satoshiToBTCString:(int64_t) satoshi withSymbol:(bool) symbol;
- (NSString *)satoshiToBTCString:(int64_t) satoshi;

/**
 * Parse an NSString to satoshi amount. Factors in the current denomination in the conversion.
 * @param amount NSString String value to parse
 * @return int64_t Signed 64 bit satoshi amount
 */
- (int64_t) btcStringToSatoshi:(NSString *) amount;

/**
 * Returns an ABCDenomination object for the given multipier enum
 * @param multiplier ABCDenominationMultiplier enum
 * @return ABCDenomination Corresponding ABCDenomination for the multiplier
 */
+ (ABCDenomination *) getDenominationForMultiplier:(ABCDenominationMultiplier)multiplier;

/**
 * Returns an ABCDenomination object for the given index into the enum list.
 * @param index int
 * @return ABCDenomination Corresponding ABCDenomination for the index<br>
 *  0 -> ABCDenominationMultiplierBTC
 *  1 -> ABCDenominationMultiplierMBTC
 *  2 -> ABCDenominationMultiplierUBTC
 */
+ (ABCDenomination *) getDenominationForIndex:(int)index;



@end