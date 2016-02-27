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
        self.txid = @"";
        self.payeeName = @"";
        self.date = [NSDate date];
        self.category = @"";
        self.notes = @"";
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
    [self.wallet.account postToMiscQueue:^{
        
        tABC_Error Error;
        tABC_TxDetails *pDetails;
        tABC_CC result = ABC_GetTransactionDetails([self.wallet.account.name UTF8String],
                                                   [self.wallet.account.password UTF8String],
                                                   [self.wallet.uuid UTF8String],
                                                   [self.txid UTF8String],
                                                   &pDetails, &Error);
        if (ABC_CC_Ok != result) {
            return;
        }
        
        pDetails->szName = (char *) [self.payeeName UTF8String];
        pDetails->szCategory = (char *) [self.category UTF8String];
        pDetails->szNotes = (char *) [self.notes UTF8String];
        pDetails->amountCurrency = self.amountFiat;
        pDetails->bizId = self.bizId;
        
        result = ABC_SetTransactionDetails([self.wallet.account.name UTF8String],
                                           [self.wallet.account.password UTF8String],
                                           [self.wallet.uuid UTF8String],
                                           [self.txid UTF8String],
                                           pDetails, &Error);
        
        if (ABC_CC_Ok != result) {
            return;
        }
        
        [self.wallet.account refreshWallets];
        return;
    }];
}



// overriding the NSObject isEqual
// allows us to call things like removeObject in array's of these
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[ABCTransaction class]])
    {
        ABCTransaction *transactionOther = object;

        if ([self.txid isEqualToString:transactionOther.txid])
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
    return([self.txid hash]);
}

// overriding the description - used in debugging
- (NSString *)description
{
    return([NSString stringWithFormat:@"ABCTransaction - ID: %@, WalletUUID: %@, PayeeName: %@, Date: %@, Confirmed: %@, Confirmations: %u, AmountSatoshi: %lli, AmountFiat: %lf, Balance: %lli, Category: %@, Notes: %@",
                                      self.txid,
                                      self.wallet.uuid,
                                      self.payeeName,
                                      [self.date descriptionWithLocale:[NSLocale currentLocale]],
                                      (self.bConfirmed == YES ? @"Yes" : @"No"),
                                      self.confirmations,
                                      self.amountSatoshi,
                                      self.amountFiat,
                                      self.balance,
                                      self.category,
                                      self.notes
    ]);
}

@end
