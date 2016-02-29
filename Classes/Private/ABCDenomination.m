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
    uint64_t parsedAmount;
    int decimalPlaces = [self maxBitcoinDecimalPlaces];
    NSString *cleanAmount = [amount stringByReplacingOccurrencesOfString:@"," withString:@""];
    if (ABC_ParseAmount([cleanAmount UTF8String], &parsedAmount, decimalPlaces) != ABC_CC_Ok) {
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

/**
 * formatSatoshi
 *
 * forceDecimals specifies the number of decimals to shift to
 * the left when converting from satoshi to BTC/mBTC/uBTC etc.
 * ie. for BTC decimals = 8
 *
 * formatSatoshi will use the settings by default if
 * forceDecimals is not supplied
 *
 * cropDecimals will crop the maximum number of digits to the
 * right of the decimal. cropDecimals = 3 will make
 * "1234.12345" -> "1234.123"
 *
 **/

- (NSString *)satoshiToBTCString:(int64_t)amount
                      withSymbol:(bool)symbol
                    cropDecimals:(BOOL)cropDecimals
{
    tABC_Error error;
    char *pFormatted = NULL;
    int decimalPlaces;
    
    if (cropDecimals)
    {
        decimalPlaces = [self prettyBitcoinDecimalPlaces];
    }
    else
    {
        decimalPlaces = [self maxBitcoinDecimalPlaces];
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
        const char *p = pFormatted;
        const char *decimal = strstr(pFormatted, ".");
        const char *start = (decimal == NULL) ? p + strlen(p) : decimal;
        int offset = (start - pFormatted) % 3;
        NSNumberFormatter *f = [ABCCurrency generateNumberFormatter];
        
        for (int i = 0; i < strlen(pFormatted) && p - start <= decimalPlaces; ++i, ++p)
        {
            if (p < start)
            {
                if (i != 0 && (i - offset) % 3 == 0)
                    [formatted appendString:[f groupingSeparator]];
                [formatted appendFormat: @"%c", *p];
            }
            else if (p == decimal)
                [formatted appendString:[f currencyDecimalSeparator]];
            else
                [formatted appendFormat: @"%c", *p];
        }
        free(pFormatted);
        return formatted;
    }
}






@end