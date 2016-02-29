//
// ABCExchangeCache.m
//
// Created by Paul Puey on 2016/02/27
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCExchangeCache+Internal.h"

@interface ABCExchangeCache ()
{
//    ABCError                                        *abcError;
    
}

@property (atomic, strong)      AirbitzCore             *abc;
@property (atomic, strong)      ABCAccount              *account;

@end

@implementation ABCExchangeCache

- (id)init:(AirbitzCore *)abc;
{
    // get the currencies
    self.abc = abc;
    
    return self;
}

- (int) getCurrencyNumFromCode:(NSString *)code;
{
    int index = (int) [[ABCCurrency listCurrencyCodes] indexOfObject:code];
    NSNumber *currencyNum = [ABCCurrency listCurrencyNums][index];
    
    return (int)[currencyNum integerValue];
}

- (ABCCurrency *) getCurrencyFromCode:(NSString *)code;
{
    int index = (int) [[ABCCurrency listCurrencyCodes] indexOfObject:code];
    return [ABCCurrency listCurrencies][index];
}

- (NSString *) getCurrencyCodeFromNum:(int) num;
{
    int index = (int) [[ABCCurrency listCurrencyNums] indexOfObject:[NSNumber numberWithInt:num]];
    
    return [ABCCurrency listCurrencyCodes][index];
}

- (ABCCurrency *) getCurrencyFromNum:(int) num;
{
    int index = (int) [[ABCCurrency listCurrencyNums] indexOfObject:[NSNumber numberWithInt:num]];
    
    return [ABCCurrency listCurrencies][index];
}

- (double) satoshiToCurrency:(uint64_t) satoshi
                currencyCode:(NSString *)currencyCode
                       error:(NSError **)nserror;
{
    tABC_Error error;
    NSError *nserror2 = nil;
    double currency = 0.0;
    
    int currencyNum = [self getCurrencyNumFromCode:currencyCode];
    
    ABC_SatoshiToCurrency(nil, nil,
                          satoshi, &currency, currencyNum, &error);
    nserror2 = [ABCError makeNSError:error];
    if (nserror) *nserror = nserror2;
    
    return currency;
}

- (uint64_t) currencyToSatoshi:(double)currency
                  currencyCode:(NSString *)currencyCode
                         error:(NSError **)nserror;
{
    tABC_Error error;
    NSError *nserror2 = nil;
    int64_t satoshi = 0;
    
    int currencyNum = [self getCurrencyNumFromCode:currencyCode];
    
    ABC_CurrencyToSatoshi(nil, nil, currency, currencyNum, &satoshi, &error);
    nserror2 = [ABCError makeNSError:error];
    if (nserror) *nserror = nserror2;
    
    return (uint64_t) satoshi;
}

- (void)requestExchangeUpdateBlocking:(NSArray *)exchangeList arrayCurrency:(NSArray *)currency;
{
    tABC_Error error;
    for (ABCCurrency *c in currency)
    {
        int num = c.currencyNum;
        // We pass no callback so this call is blocking
        ABC_RequestExchangeRateUpdate(nil,
                                      nil,
                                      num, &error);
    }
}



@end

