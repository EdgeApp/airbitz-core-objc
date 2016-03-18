//
// ABCCurrency.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@interface ABCCurrency : NSObject
@property (nonatomic)            int currencyNum;
@property (nonatomic, strong)    NSString *textDescription;
@property (nonatomic, strong)    NSString *code;
@property (nonatomic, strong)    NSString *symbol;

+ (ABCCurrency *) noCurrency;
+ (ABCCurrency *) defaultCurrency;

+ (NSArray *) listCurrencies;
+ (NSArray *) listCurrencyCodes;
+ (NSArray *) listCurrencyStrings;

+ (NSNumberFormatter *)generateNumberFormatter;
- (NSString *)doubleToPrettyCurrencyString:(double) fCurrency;
- (NSString *)doubleToPrettyCurrencyString:(double) fCurrency withSymbol:(bool)symbol;

@end
