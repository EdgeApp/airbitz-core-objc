//
//  ABCWallet.m
//  Airbitz
//
//  Created by Paul Puey.
//  Copyright (c) 2016 AirBitz. All rights reserved.
//

#import "ABCWallet+Internal.h"
#import "ABCContext+Internal.h"


#define HIDDEN_BITZ_URI_SCHEME                          @"hbits"
static const int importTimeout                  = 30;

@interface ABCWallet ()
{
    int                 _blockHeight;
}

@property (nonatomic, strong)   ABCError                    *abcError;
@property (nonatomic, strong)   void                        (^importCompletionHandler)(ABCImportDataModel dataModel, NSString *address, ABCTransaction *transaction, uint64_t amount);
@property (nonatomic, strong)   void                        (^importErrorHandler)(ABCError *error);
@property                       ABCImportDataModel          importDataModel;
@property (nonatomic, strong)   NSString                    *sweptAddress;
@property (nonatomic, strong)   NSTimer                     *importCallbackTimer;
@property                       BOOL                        bBlockHeightChanged;



@end

@implementation ABCWallet

#pragma mark - NSObject overrides

- (id)initWithUser:(ABCAccount *) account;
{
    self = [super init];
    if (self) 
	{
        self.uuid = @"";
        self.name = @"";
        self.arrayTransactions = [[NSArray alloc] init];
        self.abcError = [[ABCError alloc] init];
        self.account = account;
        self.bBlockHeightChanged = YES;

    }
    return self;
}

- (void)dealloc 
{

}

- (ABCError *) renameWallet:(NSString *)newName;
{
    tABC_Error error;
    ABC_RenameWallet([self.account.name UTF8String],
                     [self.account.password UTF8String],
                     [self.uuid UTF8String],
                     (char *)[newName UTF8String],
                     &error);
    [self.account refreshWallets];
    return [ABCError makeNSError:error];
}

- (ABCError *)removeWallet
{
    // Check if we are trying to delete the current wallet
    if ([self.account.currentWallet.uuid isEqualToString:self.uuid])
    {
        // Find a non-archived wallet that isn't the wallet we're going to delete
        // and make it the current wallet
        for (ABCWallet *wallet in self.account.arrayWallets)
        {
            if (![wallet.uuid isEqualToString:self.uuid])
            {
                if (!wallet.archived)
                {
                    [self.account makeCurrentWallet:wallet];
                    break;
                }
            }
        }
    }
    ABCLog(1,@"Deleting wallet [%@]", self.uuid);
    tABC_Error error;
    
    ABC_WalletRemove([self.account.name UTF8String], [self.uuid UTF8String], &error);
    
    [self.account refreshWallets];
    return [ABCError makeNSError:error];
}

- (void) removeWallet:(void(^)(void))completionHandler
                error:(void (^)(ABCError *error)) errorHandler;
{
    // Check if we are trying to delete the current wallet
    if ([self.account.currentWallet.uuid isEqualToString:self.uuid])
    {
        // Find a non-archived wallet that isn't the wallet we're going to delete
        // and make it the current wallet
        for (ABCWallet *w in self.account.arrayWallets)
        {
            if (![w.uuid isEqualToString:self.uuid])
            {
                if (!w.archived)
                {
                    [self.account makeCurrentWallet:w];
                    break;
                }
            }
        }
    }
    
    [self.account postToMiscQueue:^
     {
         ABCLog(1,@"Deleting wallet [%@]", self.uuid);
         tABC_Error error;
         
         ABC_WalletRemove([self.account.name UTF8String], [self.uuid UTF8String], &error);
         ABCError *nserror = [ABCError makeNSError:error];
         
         [self.account refreshWallets];
         
         dispatch_async(dispatch_get_main_queue(),^{
             if (!nserror) {
                 if (completionHandler) completionHandler();
             } else {
                 if (errorHandler) errorHandler(nserror);
             }
         });
     }];
}

- (ABCReceiveAddress *)createNewReceiveAddress;
{
    return [self createNewReceiveAddress:nil];
}
- (ABCReceiveAddress *)createNewReceiveAddress:(ABCError **)nserror;
{
    ABCReceiveAddress *receiveAddress = [[ABCReceiveAddress alloc] initWithWallet:self];

    ABCError *error = [receiveAddress createAddress];

    if (nserror)
        *nserror = error;

    return receiveAddress;

}

- (void)createNewReceiveAddress:(void (^)(ABCReceiveAddress *))completionHandler
                          error:(void (^)(ABCError *error)) errorHandler
{
    [self.account postToGenQRQueue:^(void)
     {
         ABCError *error = nil;
         ABCReceiveAddress *receiveAddress = [self createNewReceiveAddress:&error];

         dispatch_async(dispatch_get_main_queue(), ^(void)
                        {
                            if (!error)
                            {
                                if (completionHandler) completionHandler(receiveAddress);
                            }
                            else
                            {
                                if (errorHandler) errorHandler(error);
                            }
                        });
         
     }];
}

- (ABCReceiveAddress *)getReceiveAddress:(NSString *)address;
{
    return [self getReceiveAddress:address error:nil];
}
- (ABCReceiveAddress *)getReceiveAddress:(NSString *)address error:(ABCError **)nserror;
{
    ABCReceiveAddress *receiveAddress = [[ABCReceiveAddress alloc] initWithWallet:self];

    receiveAddress.address = address;

    return receiveAddress;
}

- (ABCSpend *)createNewSpend:(ABCError **)nserror;
{
    ABCSpend *spend = nil;
    tABC_Error error;
    ABCError *lnserror = nil;
    void *ptr;
    
    ABC_SpendNew([self.account.name UTF8String], [[self uuid] UTF8String], &ptr, &error);
    lnserror = [ABCError makeNSError:error];
    
    if (!lnserror)
    {
        spend = [[ABCSpend alloc]init:self];
        spend.pSpend = ptr;
        spend.feeLevel = ABCSpendFeeLevelStandard;
    }
    
    if (nserror) *nserror = lnserror;
    
    return spend;
}

- (void)importPrivateKey:(NSString *)privateKey
               importing:(void (^)(NSString *address)) importingHandler
                complete:(void (^)(ABCImportDataModel dataModel, NSString *address, ABCTransaction *transaction, uint64_t amount)) completionHandler
                   error:(void (^)(ABCError *error)) errorHandler;
{
    bool bSuccess = NO;
    tABC_Error error;
    ABCError *nserror = nil;
    
    // We will use the sweep callback to call these GUI handlers when done.
    self.importCompletionHandler = completionHandler;
    self.importErrorHandler = errorHandler;
    
    if (!privateKey || !self.uuid)
    {
        error.code = ABC_CC_NULLPtr;
        nserror = [ABCError makeNSError:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errorHandler) errorHandler(nserror);
        });
        return;
    }
    
    privateKey = [privateKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange schemeMarkerRange = [privateKey rangeOfString:@"://"];
    
    if (NSNotFound != schemeMarkerRange.location)
    {
        NSString *scheme = [privateKey substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
        if (nil != scheme && 0 != [scheme length])
        {
            if (NSNotFound != [scheme rangeOfString:HIDDEN_BITZ_URI_SCHEME].location)
            {
                self.importDataModel = ABCImportHBitsURI;
                
                privateKey = [privateKey substringFromIndex:schemeMarkerRange.location + schemeMarkerRange.length];
                bSuccess = YES;
            }
        }
    }
    else
    {
        self.importDataModel = ABCImportWIF;
        bSuccess = YES;
    }
    if (bSuccess)
    {
        ABCParsedURI *parsedURI = [ABCUtil parseURI:privateKey error:nil];
        self.sweptAddress = parsedURI.address;
        
        NSString *dummyAddress; // To be deprecated from ABC_SweepKey
        nserror = [self sweepKey:privateKey
                      intoWallet:self.uuid
                         address:&dummyAddress];
        
        if (nil != self.sweptAddress && !nserror)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (importingHandler) importingHandler(self.sweptAddress);
            });
            // If the sweep never completes, expireImport will call the errorHandler
            self.importCallbackTimer = [NSTimer scheduledTimerWithTimeInterval:importTimeout
                                                                        target:self
                                                                      selector:@selector(expireImport)
                                                                      userInfo:nil
                                                                       repeats:NO];
        }
        else
        {
            // no address associated with the private key, must be invalid
            error.code = ABC_CC_ParseError;
            nserror = [ABCError makeNSError:error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errorHandler) errorHandler(nserror);
            });
            return;
        }
    }
    
    if (!bSuccess)
    {
        error.code = ABC_CC_ParseError;
        nserror = [ABCError makeNSError:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errorHandler) errorHandler(nserror);
        });
        return;
    }
}


- (ABCError *)exportTransactionsToCSV:(NSMutableString *) csv;
{
    return [self exportTransactionsToCSV:csv start:nil end:nil];
}

- (ABCError *)exportTransactionsToCSV:(NSMutableString *) csv start:(NSDate *)start end:(NSDate* )end;
{
    char *szCsvData = nil;
    tABC_Error error;
    int64_t startTime;
    int64_t endTime;
    
    if (!start)
        startTime = 0;
    else
        startTime = [start timeIntervalSince1970];
    
    if (!end)
        endTime = 0x0FFFFFFFFFFFFFFF;
    else
        endTime = [end timeIntervalSince1970];
    
    if (!csv)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }
    ABC_CsvExport([self.account.name UTF8String],
                  [self.account.password UTF8String],
                  [self.uuid UTF8String],
                  startTime, endTime, &szCsvData, &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [csv setString:[NSString stringWithCString:szCsvData encoding:NSASCIIStringEncoding]];
    }
    
    if (szCsvData) free(szCsvData);
    return nserror;
}

- (ABCError *)exportTransactionsToQBO:(NSMutableString *) qbo;
{
    return [self exportTransactionsToQBO:qbo start:nil end:nil];
}

- (ABCError *)exportTransactionsToQBO:(NSMutableString *) qbo start:(NSDate *)start end:(NSDate* )end;
{
    char *szQBOData = nil;
    tABC_Error error;
    int64_t startTime;
    int64_t endTime;
    
    if (!start)
        startTime = 0;
    else
        startTime = [start timeIntervalSince1970];
    
    if (!end)
        endTime = 0x0FFFFFFFFFFFFFFF;
    else
        endTime = [end timeIntervalSince1970];
    
    if (!qbo)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }
    ABC_QBOExport([self.account.name UTF8String],
                  [self.account.password UTF8String],
                  [self.uuid UTF8String],
                  startTime, endTime, &szQBOData, &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [qbo setString:[NSString stringWithCString:szQBOData encoding:NSASCIIStringEncoding]];
    }
    
    if (szQBOData) free(szQBOData);
    return nserror;
}

- (ABCError *)exportWalletPrivateSeed:(NSMutableString *) seed
{
    tABC_Error error;
    char *szSeed = NULL;
    if (!seed)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }
    ABC_ExportWalletSeed([self.account.name UTF8String],
                         [self.account.password UTF8String],
                         [self.uuid UTF8String],
                         &szSeed, &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [seed setString:[NSString stringWithUTF8String:szSeed]];
    }
    if (szSeed) free(szSeed);
    return nserror;
}

- (ABCError *)exportWalletXPub:(NSMutableString *) seed
{
    tABC_Error error;
    char *szSeed = NULL;
    if (!seed)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }
    ABC_ExportWalletXPub([self.account.name UTF8String],
                         [self.account.password UTF8String],
                         [self.uuid UTF8String],
                         &szSeed, &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [seed setString:[NSString stringWithUTF8String:szSeed]];
    }
    if (szSeed) free(szSeed);
    return nserror;
}

- (void)deprioritizeAllAddresses;
{
    [self.account postToWatcherQueue:^{
        tABC_Error Error;
        ABC_PrioritizeAddress([self.account.name UTF8String],
                              [self.account.password UTF8String],
                              [self.uuid UTF8String],
                              NULL,
                              &Error);
    }];
}

- (ABCTransaction *)getTransaction:(NSString *) txId;
{
    tABC_Error Error;
    ABCTransaction *transaction = nil;
    tABC_TxInfo *pTrans = NULL;
    
    tABC_CC result = ABC_GetTransaction([self.account.name UTF8String],
                                        [self.account.password UTF8String],
                                        [self.uuid UTF8String], [txId UTF8String],
                                        &pTrans, &Error);
    if (ABC_CC_Ok == result)
    {
        transaction = [[ABCTransaction alloc] initWithWallet:self];
        [self setTransaction:transaction coreTx:pTrans];
    }
    else
    {
        ABCLog(2,@("Error: ABCContext.loadTransactions:  %s\n"), Error.szDescription);
    }
    ABC_FreeTransaction(pTrans);
    return transaction;
}

- (int64_t)getTotalSentToday
{
    int64_t total = 0;
    
    if ([self.arrayTransactions count] == 0)
        return 0;
    
    for (ABCTransaction *t in self.arrayTransactions)
    {
        if ([[NSCalendar currentCalendar] isDateInToday:t.date])
        {
            if (t.amountSatoshi < 0)
            {
                total += t.amountSatoshi * -1;
            }
        }
    }
    return total;
    
}

- (void) loadTransactions;
{
    tABC_Error Error;
    unsigned int tCount = 0;
    ABCTransaction *transaction;
    tABC_TxInfo **aTransactions = NULL;
    tABC_CC result = ABC_GetTransactions([self.account.name UTF8String],
                                         [self.account.password UTF8String],
                                         [self.uuid UTF8String],
                                         ABC_GET_TX_ALL_TIMES,
                                         ABC_GET_TX_ALL_TIMES,
                                         &aTransactions,
                                         &tCount, &Error);
    if (ABC_CC_Ok == result)
    {
        NSMutableArray *arrayTransactions = [[NSMutableArray alloc] init];
        
        for (int j = tCount - 1; j >= 0; --j)
        {
            tABC_TxInfo *pTrans = aTransactions[j];
            transaction = [[ABCTransaction alloc] initWithWallet:self];
            [self setTransaction:transaction coreTx:pTrans];
            [arrayTransactions addObject:transaction];
        }
        SInt64 bal = self.balance;
        for (int j = 0; j < arrayTransactions.count; j++)
        {
            ABCTransaction *t = arrayTransactions[j];
            t.balance = bal;
            bal -= t.amountSatoshi;
        }
        self.arrayTransactions = arrayTransactions;
    }
    else
    {
        ABCLog(2,@("Error: ABCContext.loadTransactions:  %s\n"), Error.szDescription);
    }
    ABC_FreeTransactions(aTransactions, tCount);
}

- (void)setTransaction:(ABCTransaction *) transaction coreTx:(tABC_TxInfo *) pTrans
{
    transaction.txid = [NSString stringWithUTF8String: pTrans->szID];
    transaction.metaData.payeeName = [NSString stringWithUTF8String: pTrans->pDetails->szName];
    transaction.metaData.notes = [NSString stringWithUTF8String: pTrans->pDetails->szNotes];
    transaction.metaData.category = [NSString stringWithUTF8String: pTrans->pDetails->szCategory];
    transaction.date = [self.account.abc dateFromTimestamp: pTrans->timeCreation];
    transaction.amountSatoshi = pTrans->pDetails->amountSatoshi;
    transaction.metaData.amountFiat = pTrans->pDetails->amountCurrency;
    transaction.providerFee = pTrans->pDetails->amountFeesAirbitzSatoshi;
    transaction.minerFees = pTrans->pDetails->amountFeesMinersSatoshi;
    transaction.isDoubleSpend = pTrans->bDoubleSpent;
    transaction.isReplaceByFee = pTrans->bReplaceByFee;
    transaction.height = pTrans->height;
    
//    transaction.bConfirmed = transaction.confirmations >= ABCConfirmedConfirmationCount;
    NSMutableArray *outputs = [[NSMutableArray alloc] init];
    for (int i = 0; i < pTrans->countOutputs; ++i)
    {
        ABCTxInOut *output = [[ABCTxInOut alloc] init];
        output.address = [NSString stringWithUTF8String: pTrans->aOutputs[i]->szAddress];
        output.isInput = pTrans->aOutputs[i]->input;
        output.amountSatoshi = pTrans->aOutputs[i]->value;
        
        [outputs addObject:output];
    }
    transaction.inputOutputList = outputs;
    transaction.metaData.bizId = pTrans->pDetails->bizId;
}

- (int)blockHeight;
{
    if (_bBlockHeightChanged)
    {
        _bBlockHeightChanged = NO;
        tABC_Error error;
        int blockHeight = 0;
        ABC_BlockHeight([self.uuid UTF8String], &blockHeight, &error);
        _blockHeight = blockHeight;
        return _blockHeight;
    }
    return _blockHeight;
}

- (void)setBlockHeight:(int)blockHeight;
{
    _blockHeight = blockHeight;
}

- (int)getTxHeight:(NSString *)txid;
{
    tABC_Error Error;
    int txHeight = 0;
    if ([self.uuid length] == 0 || [txid length] == 0) {
        return 0;
    }
    if (ABC_TxHeight([self.uuid UTF8String], [txid UTF8String], &txHeight, &Error) != ABC_CC_Ok) {
        if (txHeight < 0)
        {
            ABCLog(0, @"calcTxConfirmations returning negative txHeight=%d", txHeight);
            return txHeight;
        }
        else
            return 0;
    }
    return txHeight;
}

- (ABCError *)searchTransactionsIn:(NSString *)term addTo:(NSMutableArray *) arrayTransactions;
{
    tABC_Error Error;
    ABCError *nserror = nil;
    unsigned int tCount = 0;
    ABCTransaction *transaction;
    tABC_TxInfo **aTransactions = NULL;
    tABC_CC result = ABC_SearchTransactions([self.account.name UTF8String],
                                            [self.account.password UTF8String],
                                            [self.uuid UTF8String], [term UTF8String],
                                            &aTransactions, &tCount, &Error);
    nserror = [ABCError makeNSError:Error];
    if (!nserror)
    {
        for (int j = tCount - 1; j >= 0; --j) {
            tABC_TxInfo *pTrans = aTransactions[j];
            transaction = [[ABCTransaction alloc] initWithWallet:self];
            [self setTransaction:transaction coreTx:pTrans];
            [arrayTransactions addObject:transaction];
        }
    }
    else
    {
        ABCLog(2,@("Error: ABCContext.searchTransactionsIn:  %s\n"), Error.szDescription);
    }
    ABC_FreeTransactions(aTransactions, tCount);
    return nserror;
}

- (void)loadWalletFromCore:(NSString *)uuid;
{
    tABC_Error error;
    self.uuid = uuid;
    self.name = abcStringLoadingText;
    self.currency = [ABCCurrency noCurrency];
    self.balance = 0;
    self.loaded = NO;
    
    if ([self.account watcherExists:uuid]) {
        char *szName = NULL;
        ABC_WalletName([self.account.name UTF8String], [uuid UTF8String], &szName, &error);
        
        if (error.code == ABC_CC_Ok) {
            self.name = [ABCUtil safeStringWithUTF8String:szName];
        }
        
        if (szName) {
            free(szName);
        }
        
        int currencyNum;
        ABC_WalletCurrency([self.account.name UTF8String], [uuid UTF8String], &currencyNum, &error);
        if (error.code == ABC_CC_Ok) {
            self.currency = [self.account.exchangeCache getCurrencyFromNum:currencyNum];
            self.loaded = YES;
        } else {
            self.loaded = NO;
            self.currency = [ABCCurrency noCurrency];
            self.name = abcStringLoadingText;
        }
        
        int64_t balance;
        ABC_WalletBalance([self.account.name UTF8String], [uuid UTF8String], &balance, &error);
        if (error.code == ABC_CC_Ok) {
            self.balance = balance;
        } else {
            self.balance = 0;
        }
    }
    
    bool archived = false;
    ABC_WalletArchived([self.account.name UTF8String], [uuid UTF8String], &archived, &error);
    self.archived = archived ? YES : NO;
}



//
// This triggers a switch of libbitcoin servers and possibly an update if new information comes in
//
- (void)refreshServer:(BOOL)bData notify:(void(^)(void))cb;
{
    [self.account connectWatcher:self.uuid];
    [self.account postToMiscQueue:^{
        // Reconnect the watcher for this wallet
        if (bData) {
            // Clear data sync queue and sync the current wallet immediately
            [self.account clearDataQueue];
            [self.account postToDataQueue:^{
                if (![self.account isLoggedIn]) {
                    return;
                }
                tABC_Error error;
                bool bDirty = false;
                ABC_DataSyncWallet([self.account.name UTF8String],
                                   [self.account.password UTF8String],
                                   [self.uuid UTF8String],
                                   &bDirty,
                                   &error);
                dispatch_async(dispatch_get_main_queue(),^{
                    if (cb) cb();
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(),^{
                if (cb) cb();
            });
        }
    }];
}


- (NSString *)conversionString
{
    return [self.account createExchangeRateString:self.currency includeCurrencyCode:YES];
}

// overriding the NSObject isEqual
// allows us to call things like removeObject in array's of these
- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[ABCWallet class]])
	{
		ABCWallet *walletOther = object;
		
        if ([self.uuid isEqualToString:walletOther.uuid])
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
    return([self.uuid hash]);
}

// overriding the description - used in debugging
- (NSString *)description
{
	return([NSString stringWithFormat:@"Wallet - UUID: %@, Name: %@, CurrencyCode: %@, Attributes: %d, Balance: %llu, Transactions: %@",
            self.uuid,
            self.name,
//            self.strUserName,
            self.currency.code,
            self.archived,
            self.balance,
            self.arrayTransactions
            ]);
}

#pragma mark - Private Key Sweep helper methods

- (ABCError *)sweepKey:(NSString *)privateKey intoWallet:(NSString *)walletUUID address:(NSString **)address
{
    tABC_Error error;
    ABCError *nserror = nil;
    char *pszAddress = NULL;
    ABC_SweepKey([self.account.name UTF8String],
                 [self.account.password UTF8String],
                 [walletUUID UTF8String],
                 [privateKey UTF8String],
                 &error);
    nserror = [ABCError makeNSError:error];
    if (!nserror && pszAddress)
    {
        *address = [NSString stringWithUTF8String:pszAddress];
        free(pszAddress);
    }
    return nserror;
}

- (void)handleSweepCallback:(ABCTransaction *)tx amount:(uint64_t)amount error:(ABCError *)error;
{
    [self cancelImportExpirationTimer];
    
    if (!error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.importCompletionHandler) self.importCompletionHandler(self.importDataModel, self.sweptAddress, tx, amount);
            self.importErrorHandler = nil;
            self.importCompletionHandler = nil;
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.importErrorHandler) self.importErrorHandler(error);
            self.importErrorHandler = nil;
            self.importCompletionHandler = nil;
        });
    }
    
}

- (void)expireImport
{
    self.importCallbackTimer = nil;
    tABC_Error error;
    error.code = ABC_CC_NoTransaction;
    ABCError *nserror = [ABCError makeNSError:error];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.importErrorHandler) self.importErrorHandler(nserror);
        self.importErrorHandler = nil;
        self.importCompletionHandler = nil;
    });
}

- (void)cancelImportExpirationTimer
{
    if (self.importCallbackTimer)
    {
        [self.importCallbackTimer invalidate];
        self.importCallbackTimer = nil;
    }
}

@end
