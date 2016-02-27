//
//  ABCSpend.m
//  AirBitz
//

#import "AirbitzCore+Internal.h"

@interface ABCSpend ()

@property (nonatomic)               tABC_SpendTarget        *pSpend;
@property (nonatomic, strong)       ABCWallet               *wallet;

@end

@implementation ABCSpend

- (id)init:(id)wallet;
{
    self = [super init];
    if (self) {
        self.pSpend = NULL;
        self.bizId = 0;
        self.wallet = wallet;
//        self.abcError = [[ABCError alloc] init];
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


- (NSError *)signTx:(NSMutableString *)txData;
{
    NSString *rawTx = nil;
    char *szRawTx = NULL;
    tABC_Error error;
    
    if (!txData)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }

    ABC_SpendSignTx([self.wallet.account.name UTF8String],
            [self.srcWallet.uuid UTF8String], _pSpend, &szRawTx, &error);
    NSError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        rawTx = [NSString stringWithUTF8String:szRawTx];
        free(szRawTx);
        [txData setString:rawTx];
    }
    return nserror;
}
- (void)signTx:(void (^)(NSString * txData)) completionHandler
        error:(void (^)(NSError *error)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        NSMutableString *txData = [[NSMutableString alloc] init];
        NSError *error = [self signTx:txData];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!error)
            {
                if (completionHandler) completionHandler(txData);
            }
            else
            {
                if (errorHandler) errorHandler(error);
            }
        });
    }];
}

- (void)signAndSaveTx:(void (^)(NSString * rawTx)) completionHandler
                error:(void (^)(NSError *error)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        NSMutableString *rawTx = [[NSMutableString alloc] init];
        NSMutableString *txId = [[NSMutableString alloc] init];

        NSError *error = [self signTx:rawTx];
        if (!error)
        {
            error = [self saveTx:rawTx txId:txId];
        }

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!error)
            {
                if (completionHandler) completionHandler(rawTx);
            }
            else
            {
                if (errorHandler) errorHandler(error);
            }
        });
    }];
}

- (NSError *)broadcastTx:(NSString *)rawTx;
{
    tABC_Error error;
    ABC_SpendBroadcastTx([self.wallet.account.name UTF8String],
        [self.srcWallet.uuid UTF8String], _pSpend, (char *)[rawTx UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (NSError *)saveTx:(NSString *)rawTx txId:(NSMutableString *)txId;
{
    NSString *txidTemp = nil;
    char *szTxId = NULL;
    tABC_Error error;
    NSError *nserror = nil;

    ABC_SpendSaveTx([self.wallet.account.name UTF8String],
        [self.srcWallet.uuid UTF8String], _pSpend, (char *)[rawTx UTF8String], &szTxId, &error);
    nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        txidTemp = [NSString stringWithUTF8String:szTxId];
        free(szTxId);
        [self updateTransaction:txidTemp];
        if (txId)
        {
            [txId setString:txidTemp];
        }
    }
    return nserror;
}

- (NSError *)signBroadcastSaveTx:(NSMutableString *)txId;
{
    NSMutableString *rawTx = [[NSMutableString alloc] init];
    NSError *nserror = [self signTx:rawTx];
    if (!nserror)
    {
        nserror = [self broadcastTx:rawTx];
        if (!nserror)
        {
            NSMutableString *txIdTemp = [[NSMutableString alloc] init];
            nserror = [self saveTx:rawTx txId:txIdTemp];
            if (!nserror && txId)
            {
                [txId setString:txIdTemp];
            }
        }
    }
    return nserror;
}

- (void)signBroadcastSaveTx:(void (^)(NSString * txId)) completionHandler
                      error:(void (^)(NSError *error)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        NSMutableString *txId = [[NSMutableString alloc] init];
        NSError *error = [self signBroadcastSaveTx:txId];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!error)
            {
                if (completionHandler) completionHandler(txId);
            }
            else
            {
                if (errorHandler) errorHandler(error);
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
        [self.srcWallet.uuid UTF8String], [txId UTF8String], &pTrans, &error);
    if (ABC_CC_Ok == error.code) {
        if (self.destWallet) {
            pTrans->pDetails->szName = strdup([self.destWallet.name UTF8String]);
            pTrans->pDetails->szCategory = strdup([[NSString stringWithFormat:@"%@%@", transferCategory, self.destWallet.name] UTF8String]);
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
            [self.srcWallet.uuid UTF8String], [txId UTF8String],
            pTrans->pDetails, &error);
    }
    ABC_FreeTransaction(pTrans);
    pTrans = NULL;

    // This was a transfer
    if (self.destWallet) {
        ABC_GetTransaction([self.wallet.account.name UTF8String], NULL,
            [self.destWallet.uuid UTF8String], [txId UTF8String], &pTrans, &error);
        if (ABC_CC_Ok == error.code) {
            pTrans->pDetails->szName = strdup([self.srcWallet.name UTF8String]);
            pTrans->pDetails->szCategory = strdup([[NSString stringWithFormat:@"%@%@", transferCategory, self.srcWallet.name] UTF8String]);

            ABC_SetTransactionDetails([self.wallet.account.name UTF8String], NULL,
                [self.destWallet.uuid UTF8String], [txId UTF8String],
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
        [self.wallet.uuid UTF8String], _pSpend, &result, &error);
    return result;
}

- (NSError *)calcSendFees:(uint64_t *)totalFees
{
    tABC_Error error;
    [self copyOBJCtoABC];
    ABC_SpendGetFee([self.wallet.account.name UTF8String],
        [self.wallet.uuid UTF8String], self.pSpend, totalFees, &error);
    return [ABCError makeNSError:error];
}

- (void)calcSendFees:(void (^)(uint64_t totalFees)) completionHandler
               error:(void (^)(NSError *error)) errorHandler;
{
    [self.wallet.account postToMiscQueue:^
    {
        uint64_t totalFees = 0;
        NSError *error = [self calcSendFees:&totalFees];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!error)
            {
                if (completionHandler) completionHandler(totalFees);
            }
            else
            {
                if (errorHandler) errorHandler(error);
            }
        });
    }];

}


@end
