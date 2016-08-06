//
// ABCExchangeCache+Internal.h
//
// Created by Paul Puey on 2016/02/27
// Copyright (c) 2016 Airbitz. All rights reserved.
//
#import "ABCExchangeCache.h"
#import "ABCContext+Internal.h"

@interface ABCExchangeCache (Internal)

@property (atomic, strong)      ABCContext *abc;
@property (atomic, strong)      ABCAccount              *account;

- (id)init:(ABCContext *)abc;
- (ABCCurrency *) getCurrencyFromCode:(NSString *)code;
- (int) getCurrencyNumFromCode:(NSString *)code;
- (NSString *) getCurrencyCodeFromNum:(int) num;
- (ABCCurrency *) getCurrencyFromNum:(int) num;
- (void)updateExchangeCache;
- (void)addCurrencyToCheck:(ABCCurrency *)currency;
- (void)addCurrenciesToCheck:(NSMutableArray *)currencies;

@end
