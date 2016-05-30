//
//  ABCDenomination.m
//  Airbitz
//

#import "ABCDenomination.h"
#import "AirbitzCore+Internal.h"

@interface ABCDenomination ()

@end

static ABCDenomination *BTC = nil;
static ABCDenomination *mBTC = nil;
static ABCDenomination *uBTC = nil;
static NSString *decimalSymbol = nil;
static NSNumberFormatter *numberFormatter = nil;
static NSLocale *locale = nil;
static NSLocale *usLocale = nil;

@implementation ABCDenomination

+ (void)initDenominations;
{
    BTC = [ABCDenomination alloc];
    mBTC = [ABCDenomination alloc];
    uBTC = [ABCDenomination alloc];
    
    BTC.symbol = @"Ƀ";
    BTC.label = @"BTC";
    BTC.multiplier = ABCDenominationMultiplierBTC;
    BTC.index = 0;
    
    mBTC.symbol = @"mɃ";
    mBTC.label = @"mBTC";
    mBTC.multiplier = ABCDenominationMultiplierMBTC;
    mBTC.index = 1;
    
    uBTC.symbol = @"ƀ";
    uBTC.label = @"bits";
    uBTC.multiplier = ABCDenominationMultiplierUBTC;
    uBTC.index = 2;
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    decimalSymbol = [formatter decimalSeparator];
}

+ (ABCDenomination *) getDenominationForMultiplier:(ABCDenominationMultiplier)multiplier;
{
    if (!BTC)
    {
        [ABCDenomination initDenominations];
    }
    
    if (ABCDenominationMultiplierBTC == multiplier)
    {
        return BTC;
    }
    else if (ABCDenominationMultiplierMBTC == multiplier)
    {
        return mBTC;
    }
    else
    {
        return uBTC;
    }
}

+ (ABCDenomination *) getDenominationForIndex:(int)index;
{
    if (!BTC)
    {
        [ABCDenomination initDenominations];
    }
    
    if (0 == index)
    {
        return BTC;
    }
    else if (1 == index)
    {
        return mBTC;
    }
    else
    {
        return uBTC;
    }
}

- (int) prettyBitcoinDecimalPlaces;
{
    return [self maxBitcoinDecimalPlaces] - 2;
}

- (int) maxBitcoinDecimalPlaces
{
    return log10((double) self.multiplier);
}

- (int64_t) btcStringToSatoshi:(NSString *) amount;
{
    uint64_t parsedAmount = 0;
    int decimalPlaces = [self maxBitcoinDecimalPlaces];
    
    NSNumberFormatter *nf = [ABCDenomination generateNumberFormatter];
    [nf setLocale:locale];
    [nf setMinimumFractionDigits:0];
    [nf setMaximumFractionDigits:decimalPlaces];
    
    [nf setNumberStyle:NSNumberFormatterDecimalStyle];
    
    NSNumber *num = [nf numberFromString:amount];
    
    if (num)
    {
        NSString *cleanAmount = [num stringValue];
        if (cleanAmount)
        {
            if (ABC_ParseAmount([cleanAmount UTF8String], &parsedAmount, decimalPlaces) != ABC_CC_Ok) {
            }            
        }
    }
    return (int64_t) parsedAmount;
}

- (NSString *)satoshiToBTCString:(int64_t)amount;
{
    return [self satoshiToBTCString:amount withSymbol:true];
}

- (NSString *)satoshiToBTCString: (int64_t) amount withSymbol:(bool)symbol
{
    return [self satoshiToBTCString:amount withSymbol:symbol cropDecimals:NO];
}

- (NSString *)satoshiToBTCString:(int64_t)amount
                      withSymbol:(bool)symbol
                    cropDecimals:(BOOL)cropDecimals
{
    tABC_Error error;
    char *pFormatted = NULL;
    int decimalPlaces, prettyDecimalPlaces;
    
    decimalPlaces = [self maxBitcoinDecimalPlaces];
    
    if (cropDecimals)
    {
        prettyDecimalPlaces = [self prettyBitcoinDecimalPlaces];
    }
    else
    {
        prettyDecimalPlaces = decimalPlaces;
    }

    
    bool negative = amount < 0;
    amount = llabs(amount);
    if (ABC_FormatAmount(amount, &pFormatted, decimalPlaces, false, &error) != ABC_CC_Ok)
    {
        return nil;
    }
    else
    {
        NSMutableString *formatted = [[NSMutableString alloc] init];
        if (negative)
            [formatted appendString: @"-"];
        if (symbol)
        {
            [formatted appendString: self.symbol];
            [formatted appendString: @" "];
        }

        NSNumberFormatter *f = [ABCDenomination generateNumberFormatter];
        [f setMinimumFractionDigits:0];
        [f setMaximumFractionDigits:prettyDecimalPlaces];

        // Use NSNumberFormatter in US locale to convert ABC formatted string
        // to NSNumber
        [f setLocale:usLocale];
        NSString *str1 = [NSString stringWithUTF8String:pFormatted];
        NSNumber *nsnum = [f numberFromString:str1];

        // Use NSNumberFormatter to output an NSString in localized number format
        [f setLocale:locale];
        NSString *str2 = [f stringFromNumber:nsnum];
        
        [formatted appendString:str2];

        free(pFormatted);
        return formatted;
    }
}

+ (NSString *) getDecimalSymbol;
{
    return decimalSymbol;
}

+ (NSNumberFormatter *)generateNumberFormatter;
{
    if (!numberFormatter)
    {
        locale = [NSLocale autoupdatingCurrentLocale];
        usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        
        [numberFormatter setLocale:locale];
        numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    }
    return numberFormatter;
}





@end