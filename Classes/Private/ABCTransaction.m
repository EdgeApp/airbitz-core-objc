//
//  ABCTransaction.m
//  AirBitz
//
//  Created by Adam Harris on 3/3/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "ABCTransaction.h"
#import "AirbitzCore+Internal.h"

@interface ABCTransaction ()

@end

@implementation ABCTransaction

#pragma mark - NSObject overrides

- (id)initWithWallet:(ABCWallet *)wallet;
{
    self = [super init];
    if (self) 
    {
        self.metaData = [ABCMetaData alloc];
        self.txid = @"";
        self.date = [NSDate date];
        self.inputList = [[NSArray alloc] init];
        self.outputList = [[NSArray alloc] init];
        self.metaData.payeeName = @"";
        self.metaData.category = @"";
        self.metaData.notes = @"";
        self.metaData.bizId = 0;
        self.wallet = wallet;
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
        
        pDetails->szName = (char *) [self.metaData.payeeName UTF8String];
        pDetails->szCategory = (char *) [self.metaData.category UTF8String];
        pDetails->szNotes = (char *) [self.metaData.notes UTF8String];
        pDetails->amountCurrency = self.metaData.amountFiat;
        pDetails->bizId = self.metaData.bizId;
        
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
    return([NSString stringWithFormat:@"ABCTransaction - ID: %@, WalletUUID: %@, PayeeName: %@, Date: %@, AmountSatoshi: %lli, AmountFiat: %lf, Balance: %lli, Category: %@, Notes: %@",
                                      self.txid,
                                      self.wallet.uuid,
                                      self.metaData.payeeName,
                                      [self.date descriptionWithLocale:[NSLocale currentLocale]],
                                      self.amountSatoshi,
                                      self.metaData.amountFiat,
                                      self.balance,
                                      self.metaData.category,
                                      self.metaData.notes
    ]);
}

@end
