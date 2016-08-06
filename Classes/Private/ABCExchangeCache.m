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
@property (atomic, strong)      NSMutableArray          *currenciesToCheck;

@end

@implementation ABCExchangeCache

- (id)init:(AirbitzCore *)abc;
{
    // get the currencies
    self.abc = abc;
    
    self.currenciesToCheck = [[NSMutableArray alloc] init];
    
    return self;
}

- (int) getCurrencyNumFromCode:(NSString *)code;
{
    int index = (int) [[ABCCurrency listCurrencyCodes] indexOfObject:code];
    if (index < 0)
        return [ABCCurrency noCurrency].currencyNum;
    if (index >= [[ABCCurrency listCurrencyNums] count])
        return [ABCCurrency noCurrency].currencyNum;
    
    NSNumber *currencyNum = [ABCCurrency listCurrencyNums][index];
    
    return (int)[currencyNum integerValue];
}

- (ABCCurrency *) getCurrencyFromCode:(NSString *)code;
{
    int index = (int) [[ABCCurrency listCurrencyCodes] indexOfObject:code];
    if (index < 0)
        return [ABCCurrency noCurrency];
    if (index >= [[ABCCurrency listCurrencies] count])
        return [ABCCurrency noCurrency];
    
    return [ABCCurrency listCurrencies][index];
}

- (NSString *) getCurrencyCodeFromNum:(int) num;
{
    int index = (int) [[ABCCurrency listCurrencyNums] indexOfObject:[NSNumber numberWithInt:num]];
    if (index < 0)
        return [ABCCurrency noCurrency].code;
    if (index >= [[ABCCurrency listCurrencyCodes] count])
        return [ABCCurrency noCurrency].code;
    
    return [ABCCurrency listCurrencyCodes][index];
}

- (ABCCurrency *) getCurrencyFromNum:(int) num;
{
    int index = (int) [[ABCCurrency listCurrencyNums] indexOfObject:[NSNumber numberWithInt:num]];
    if (index < 0)
        return [ABCCurrency noCurrency];
    if (index >= [[ABCCurrency listCurrencies] count])
        return [ABCCurrency noCurrency];
    
    return [ABCCurrency listCurrencies][index];
}

- (double) satoshiToCurrency:(uint64_t) satoshi
                currencyCode:(NSString *)currencyCode
                       error:(ABCError **)nserror;
{
    tABC_Error error;
    ABCError *nserror2 = nil;
    double currency = 0.0;
    
    int currencyNum = [self getCurrencyNumFromCode:currencyCode];
    
    ABC_SatoshiToCurrency(nil, nil,
                          satoshi, &currency, currencyNum, &error);
    nserror2 = [ABCError makeNSError:error];
    if (nserror2)
    {
        ABCCurrency *c = [self getCurrencyFromCode:currencyCode];
        [self addCurrencyToCheck:c];
        
        ABCAccount *account = self.abc.loggedInUsers[0];
        if (account)
            [account requestExchangeRateUpdate];
    }
    
    if (nserror) *nserror = nserror2;
    
    return currency;
}

- (uint64_t) currencyToSatoshi:(double)currency
                  currencyCode:(NSString *)currencyCode
                         error:(ABCError **)nserror;
{
    tABC_Error error;
    ABCError *nserror2 = nil;
    int64_t satoshi = 0;
    
    int currencyNum = [self getCurrencyNumFromCode:currencyCode];
    
    ABC_CurrencyToSatoshi(nil, nil, currency, currencyNum, &satoshi, &error);
    nserror2 = [ABCError makeNSError:error];
    if (nserror2)
    {
        ABCCurrency *c = [self getCurrencyFromCode:currencyCode];
        [self addCurrencyToCheck:c];
        
        ABCAccount *account = self.abc.loggedInUsers[0];
        if (account)
            [account requestExchangeRateUpdate];
    }

    if (nserror) *nserror = nserror2;
    
    return (uint64_t) satoshi;
}

- (void)addCurrencyToCheck:(ABCCurrency *)currency;
{
    [self.abc.exchangeQueue addOperationWithBlock:^{
        if ([self.currenciesToCheck indexOfObject:currency] == NSNotFound)
        {
            [self.currenciesToCheck addObject:currency];
        }
    }];
}

- (void)addCurrenciesToCheck:(NSMutableArray *)currencies;
{
    [self.abc.exchangeQueue addOperationWithBlock:^{
        for (ABCCurrency *c in currencies)
        {
            if ([self.currenciesToCheck indexOfObject:c] == NSNotFound)
            {
                [self.currenciesToCheck addObject:c];
            }
        }
    }];
}

- (void)updateExchangeCache;
{
    tABC_Error error;
    
    [self.abc.exchangeQueue addOperationWithBlock:^{
        for (ABCCurrency *c in self.currenciesToCheck)
        {
            // We pass no callback so this call is blocking
            ABC_RequestExchangeRateUpdate(nil,
                                          nil,
                                          c.currencyNum, &error);
            
        }
        [[NSThread currentThread] setName:@"Exchange Rate Update"];
    }];
}



@end

