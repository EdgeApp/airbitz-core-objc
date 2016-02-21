//
//  ABCSpend.m
//  AirBitz
//

#import "AirbitzCore+Internal.h"

@interface ABCSpend ()

@property (nonatomic)               tABC_SpendTarget        *pSpend;
@property (nonatomic, strong)       ABCWallet               *wallet;
@property (nonatomic, strong)       ABCError                *abcError;

@end

@implementation ABCSpend

- (id)init:(id)wallet;
{
    self = [super init];
    if (self) {
        self.pSpend = NULL;
        self.bizId = 0;
        self.wallet = wallet;
        self.abcError = [[ABCError alloc] init];
    }
    return self;
}

- (void)dealloc
{
    if (self.pSpend != NULL) {
        ABC_SpendTargetFree(self.pSpend);
        self.pSpend = NULL;
    }
}

- (void)spendObjectSet:(void *)o;
{
    self.pSpend = (tABC_SpendTarget *)o;
    [self copyABCtoOBJC];
}

- (void)copyABCtoOBJC
{
    if (!self.pSpend) return;

    self.amount         = self.pSpend->amount;
    self.amountMutable  = self.pSpend->amountMutable;
    self.bSigned        = self.pSpend->bSigned;
    self.spendName      = self.pSpend->szName       ? [NSString stringWithUTF8String:self.pSpend->szName] : nil;
    self.returnURL      = self.pSpend->szRet        ? [NSString stringWithUTF8String:self.pSpend->szRet] : nil;
    self.destUUID       = self.pSpend->szDestUUID   ? [NSString stringWithUTF8String:self.pSpend->szDestUUID] : nil;
}

- (void)copyOBJCtoABC
{
    self.pSpend->amount              = self.amount       ;
}


- (ABCConditionCode)signTx:(NSString **)txData;
{
    NSString *rawTx = nil;
    char *szRawTx = NULL;
    tABC_Error error;

    ABC_SpendSignTx([self.wallet.account.name UTF8String],
            [self.srcWallet.strUUID UTF8String], _pSpend, &szRawTx, &error);
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        rawTx = [NSString stringWithUTF8String:szRawTx];
        free(szRawTx);
        *txData = rawTx;
    }
    return ccode;
}
- (void)signTx:(void (^)(NSString * txData)) completionHandler
        error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        NSString *txData;
        ABCConditionCode ccode = [self signTx:&txData];
        NSString *errorString  = [self.abcError getLastErrorString];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(txData);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    }];
}

- (void)signAndSaveTx:(void (^)(NSString * rawTx)) completionHandler
         error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        NSString *rawTx;
        NSString *txId;

        ABCConditionCode ccode = [self signTx:&rawTx];
        if (ABCConditionCodeOk == ccode)
        {
            ccode = [self saveTx:rawTx txId:&txId];
        }
        NSString *errorString  = [self.abcError getLastErrorString];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(rawTx);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    }];
}

- (ABCConditionCode)broadcastTx:(NSString *)rawTx;
{
    tABC_Error error;
    ABC_SpendBroadcastTx([self.wallet.account.name UTF8String],
        [self.srcWallet.strUUID UTF8String], _pSpend, (char *)[rawTx UTF8String], &error);
    return [self.abcError setLastErrors:error];
}

- (ABCConditionCode)saveTx:(NSString *)rawTx txId:(NSString **)txId
{
    NSString *txidTemp = nil;
    char *szTxId = NULL;
    tABC_Error error;

    ABC_SpendSaveTx([self.wallet.account.name UTF8String],
        [self.srcWallet.strUUID UTF8String], _pSpend, (char *)[rawTx UTF8String], &szTxId, &error);
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    if (ccode == ABCConditionCodeOk) {
        txidTemp = [NSString stringWithUTF8String:szTxId];
        free(szTxId);
        [self updateTransaction:txidTemp];
        *txId = txidTemp;
    }
    return ccode;
}

- (ABCConditionCode)signBroadcastSaveTx:(NSString **)txId;
{
    NSString *txIdTemp = nil;
    NSString *rawTx;
    ABCConditionCode ccode = [self signTx:&rawTx];
    if (nil != rawTx)
    {
        ccode = [self broadcastTx:rawTx];
        if (ABCConditionCodeOk == ccode)
        {
            ccode = [self saveTx:rawTx txId:&txIdTemp];
            if (ABCConditionCodeOk == ccode)
            {
                *txId = txIdTemp;
            }
        }
    }
    return ccode;
}

- (void)signBroadcastSaveTx:(void (^)(NSString * txId)) completionHandler
         error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        NSString *txId;
        ABCConditionCode ccode = [self signBroadcastSaveTx:&txId];
        NSString *errorString  = [self.abcError getLastErrorString];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(txId);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    }];

}

- (void)updateTransaction:(NSString *)txId
{
    NSString *transferCategory = NSLocalizedString(@"Transfer:Wallet:", nil);
    NSString *spendCategory = NSLocalizedString(@"Expense:", nil);

    tABC_Error error;
    tABC_TxInfo *pTrans = NULL;
    if (_pSpend->szDestUUID) {
        NSAssert((self.destWallet), @"destWallet missing");
    }
    ABC_GetTransaction([self.wallet.account.name UTF8String], NULL,
        [self.srcWallet.strUUID UTF8String], [txId UTF8String], &pTrans, &error);
    if (ABC_CC_Ok == error.code) {
        if (self.destWallet) {
            pTrans->pDetails->szName = strdup([self.destWallet.strName UTF8String]);
            pTrans->pDetails->szCategory = strdup([[NSString stringWithFormat:@"%@%@", transferCategory, self.destWallet.strName] UTF8String]);
        } else {
            if (!pTrans->pDetails->szCategory) {
                pTrans->pDetails->szCategory = strdup([[NSString stringWithFormat:@"%@", spendCategory] UTF8String]);
            }
        }
        if (_amountFiat > 0) {
            pTrans->pDetails->amountCurrency = _amountFiat;
        }
        if (0 < _bizId) {
            pTrans->pDetails->bizId = (unsigned int)_bizId;
        }
        ABC_SetTransactionDetails([self.wallet.account.name UTF8String], NULL,
            [self.srcWallet.strUUID UTF8String], [txId UTF8String],
            pTrans->pDetails, &error);
    }
    ABC_FreeTransaction(pTrans);
    pTrans = NULL;

    // This was a transfer
    if (self.destWallet) {
        ABC_GetTransaction([self.wallet.account.name UTF8String], NULL,
            [self.destWallet.strUUID UTF8String], [txId UTF8String], &pTrans, &error);
        if (ABC_CC_Ok == error.code) {
            pTrans->pDetails->szName = strdup([self.srcWallet.strName UTF8String]);
            pTrans->pDetails->szCategory = strdup([[NSString stringWithFormat:@"%@%@", transferCategory, self.srcWallet.strName] UTF8String]);

            ABC_SetTransactionDetails([self.wallet.account.name UTF8String], NULL,
                [self.destWallet.strUUID UTF8String], [txId UTF8String],
                pTrans->pDetails, &error);
        }
        ABC_FreeTransaction(pTrans);
        pTrans = NULL;
    }
}

- (BOOL)isMutable
{
    return _pSpend->amountMutable == true ? YES : NO;
}

- (uint64_t)maxSpendable;
{
    tABC_Error error;
    uint64_t result = 0;
    ABC_SpendGetMax([self.wallet.account.name UTF8String],
        [self.wallet.strUUID UTF8String], _pSpend, &result, &error);
    return result;
}

- (ABCConditionCode)calcSendFees:(NSString *)walletUUID
                       totalFees:(uint64_t *)totalFees
{
    tABC_Error error;
    [self copyOBJCtoABC];
    ABC_SpendGetFee([self.wallet.account.name UTF8String],
        [walletUUID UTF8String], self.pSpend, totalFees, &error);
    return [self.abcError setLastErrors:error];
}

- (void)calcSendFees:(NSString *)walletUUID
            complete:(void (^)(uint64_t totalFees)) completionHandler
               error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        uint64_t totalFees = 0;
        ABCConditionCode ccode = [self calcSendFees:walletUUID totalFees:&totalFees];
        NSString *errorString  = [self.abcError getLastErrorString];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(totalFees);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    }];

}


@end
