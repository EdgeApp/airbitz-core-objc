//
//  ABCTransaction.m
//  AirBitz
//
//  Created by Adam Harris on 3/3/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "AirbitzCore+Internal.h"

@interface ABCTransaction ()

@property                   ABCError            *abcError;

@end

@implementation ABCTransaction

#pragma mark - NSObject overrides

- (id)init
{
    self = [super init];
    if (self) 
    {
        self.strID = @"";
        self.strWalletName = @"";
        self.strName = @"";
        self.strAddress = @"";
        self.date = [NSDate date];
        self.strCategory = @"";
        self.strNotes = @"";
        self.outputs = [[NSArray alloc] init];
        self.bizId = 0;
        self.wallet = nil;
        self.abcError = [[ABCError alloc] init];
    }
    return self;
}

- (void)dealloc 
{
 
}

- (void)saveTransactionDetails;
{
    [self.wallet.user postToMiscQueue:^{
        
        tABC_Error Error;
        tABC_TxDetails *pDetails;
        tABC_CC result = ABC_GetTransactionDetails([self.wallet.user.name UTF8String],
                                                   [self.wallet.user.password UTF8String],
                                                   [self.wallet.strUUID UTF8String],
                                                   [self.strID UTF8String],
                                                   &pDetails, &Error);
        if (ABC_CC_Ok != result) {
            [self.abcError setLastErrors:Error];
            //            return false;
            return;
        }
        
        pDetails->szName = (char *) [self.strName UTF8String];
        pDetails->szCategory = (char *) [self.strCategory UTF8String];
        pDetails->szNotes = (char *) [self.strNotes UTF8String];
        pDetails->amountCurrency = self.amountFiat;
        pDetails->bizId = self.bizId;
        
        result = ABC_SetTransactionDetails([self.wallet.user.name UTF8String],
                                           [self.wallet.user.password UTF8String],
                                           [self.wallet.strUUID UTF8String],
                                           [self.strID UTF8String],
                                           pDetails, &Error);
        
        if (ABC_CC_Ok != result) {
            [self.abcError setLastErrors:Error];
            //            return false;
            return;
        }
        
        [self.wallet.user refreshWallets];
        //        return true;
        return;
    }];
    
    return; // This might as well be a void. async task return value can't ever really be tested
}



// overriding the NSObject isEqual
// allows us to call things like removeObject in array's of these
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[ABCTransaction class]])
    {
        ABCTransaction *transactionOther = object;

        if ([self.strID isEqualToString:transactionOther.strID])
        {
            return YES;
        }
    }

    // if we got this far then they are not equal
    return NO;
}

// overriding the NSObject hash
// since we are overriding isEqual, we have to override hash to make sure they agree
- (NSUInteger)hash
{
    return([self.strID hash]);
}

// overriding the description - used in debugging
- (NSString *)description
{
    return([NSString stringWithFormat:@"ABCTransaction - ID: %@, WalletUUID: %@, WalletName: %@, Name: %@, Address: %@, Date: %@, Confirmed: %@, Confirmations: %u, AmountSatoshi: %lli, AmountFiat: %lf, Balance: %lli, Category: %@, Notes: %@",
            self.strID,
            self.wallet.strUUID,
            self.strWalletName,
            self.strName,
            self.strAddress,
            [self.date descriptionWithLocale:[NSLocale currentLocale]],
            (self.bConfirmed == YES ? @"Yes" : @"No"),
            self.confirmations,
            self.amountSatoshi,
            self.amountFiat,
            self.balance,
            self.strCategory,
            self.strNotes
            ]);
}

@end
