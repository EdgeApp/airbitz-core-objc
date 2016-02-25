//
//  ABCWallet.m
//  Airbitz
//
//  Created by Paul Puey.
//  Copyright (c) 2016 AirBitz. All rights reserved.
//

#import "AirbitzCore+Internal.h"


#define HIDDEN_BITZ_URI_SCHEME                          @"hbits"
static const int importTimeout                  = 30;

@interface ABCWallet ()

@property (nonatomic, strong)   ABCError                    *abcError;
@property (nonatomic, strong)   void                        (^importCompletionHandler)(ABCImportDataModel dataModel, NSString *address, NSString *txid, uint64_t amount);
@property (nonatomic, strong)   void                        (^importErrorHandler)(NSError *error);
@property                       ABCImportDataModel          importDataModel;
@property (nonatomic, strong)   NSString                    *sweptAddress;
@property (nonatomic, strong)   NSTimer                     *importCallbackTimer;


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

    }
    return self;
}

- (void)dealloc 
{

}

- (NSError *) renameWallet:(NSString *)newName;
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

- (NSError *)removeWallet
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
                error:(void (^)(NSError *error)) errorHandler;
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
         NSError *nserror = [ABCError makeNSError:error];
         
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


- (NSError *)createReceiveRequestWithDetails:(ABCRequest *)request;
{
    tABC_Error error;
    tABC_TxDetails details;
    NSError *nserror = nil;
    unsigned char *pData = NULL;
    char *szRequestAddress = NULL;
    char *pszURI = NULL;
    
    //first need to create a transaction details struct
    memset(&details, 0, sizeof(tABC_TxDetails));
    
    details.amountSatoshi = request.amountSatoshi;
    details.szName = (char *) [request.payeeName UTF8String];
    details.szCategory = (char *) [request.category UTF8String];
    details.szNotes = (char *) [request.notes UTF8String];
    details.bizId = request.bizId;
    details.attributes = 0x0; //for our own use (not used by the core)
    
    //the true fee values will be set by the core
    details.amountFeesAirbitzSatoshi = 0;
    details.amountFeesMinersSatoshi = 0;
    details.amountCurrency = 0;
    
    char *pRequestID = nil;
    request.wallet = self;
    
    // create the request
    ABC_CreateReceiveRequest([self.account.name UTF8String],
                             [self.account.password UTF8String],
                             [request.wallet.uuid UTF8String],
                             &details,
                             &pRequestID,
                             &error);
    nserror = [ABCError makeNSError:error];
    if (nserror) goto exitnow;

    request.address = [NSString stringWithUTF8String:pRequestID];
    
    ABC_ModifyReceiveRequest([self.account.name UTF8String],
                             [self.account.password UTF8String],
                             [request.wallet.uuid UTF8String],
                             pRequestID,
                             &details,
                             &error);
    nserror = [ABCError makeNSError:error];
    if (nserror) goto exitnow;
    
    unsigned int width = 0;
    ABC_GenerateRequestQRCode([self.account.name UTF8String],
                              [self.account.password UTF8String],
                              [request.wallet.uuid UTF8String],
                              pRequestID,
                              &pszURI,
                              &pData,
                              &width,
                              &error);
    nserror = [ABCError makeNSError:error];
    if (nserror) goto exitnow;

    request.qrCode = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    request.uri    = [NSString stringWithUTF8String:pszURI];
    
exitnow:
    
    if (pRequestID) free(pRequestID);
    if (szRequestAddress) free(szRequestAddress);
    if (pData) free(pData);
    if (pszURI) free(pszURI);
    
    return nserror;
}

- (void)createReceiveRequestWithDetails:(ABCRequest *)request
                               complete:(void (^)(void)) completionHandler
                                  error:(void (^)(NSError *error)) errorHandler
{
    [self.account postToGenQRQueue:^(void)
     {
         NSError *error = [self createReceiveRequestWithDetails:request];
         dispatch_async(dispatch_get_main_queue(), ^(void)
                        {
                            if (!error)
                            {
                                if (completionHandler) completionHandler();
                            }
                            else
                            {
                                if (errorHandler) errorHandler(error);
                            }
                        });
         
     }];
}

- (ABCSpend *)newSpendFromText:(NSString *)uri error:(NSError *__autoreleasing *)nserror;
{
    tABC_Error error;
    NSError *nserror2 = nil;
    ABCSpend *abcSpend = nil;
    
    if (!uri)
    {
        error.code = (tABC_CC)ABCConditionCodeNULLPtr;
        nserror2 = [ABCError makeNSError:error];
    }
    else
    {
        tABC_SpendTarget *pSpend = NULL;
        
        ABC_SpendNewDecode([uri UTF8String], &pSpend, &error);
        nserror2 = [ABCError makeNSError:error];
        
        if (!nserror2)
        {
            abcSpend = [[ABCSpend alloc] init:self];
            [abcSpend spendObjectSet:(void *)pSpend];
        }
    }
    if (nserror) *nserror = nserror2;
    return abcSpend;
}

- (void)newSpendFromText:(NSString *)uri
                complete:(void(^)(ABCSpend *sp))completionHandler
                   error:(void (^)(NSError *error)) errorHandler;
{
    [self.account postToMiscQueue:^{
        ABCSpend *abcSpend;
        NSError *error;
        abcSpend = [self newSpendFromText:uri error:&error];
        
        dispatch_async(dispatch_get_main_queue(),^{
            if (!error) {
                if (completionHandler) completionHandler(abcSpend);
            } else {
                if (errorHandler) errorHandler(error);
            }
        });
    }];
}

- (ABCSpend *)newSpendTransfer:(ABCWallet *)destWallet error:(NSError **)nserror;
{
    tABC_Error error;
    NSError *nserror2 = nil;
    ABCSpend *abcSpend = nil;
    
    if (!destWallet)
    {
        error.code = (tABC_CC)ABCConditionCodeNULLPtr;
        [self.abcError setLastErrors:error];
        return nil;
    }
    else
    {
        tABC_SpendTarget *pSpend = NULL;
        ABC_SpendNewTransfer([self.account.name UTF8String],
                             [destWallet.uuid UTF8String], 0, &pSpend, &error);
        nserror2 = [ABCError makeNSError:error];
        if (!nserror2)
        {
            abcSpend = [[ABCSpend alloc] init:self];
            abcSpend.destWallet = destWallet;
            [abcSpend spendObjectSet:(void *)pSpend];
        }
    }
    if (nserror) *nserror = nserror2;
    return abcSpend;
}

- (ABCSpend *)newSpendInternal:(NSString *)address
                         label:(NSString *)label
                      category:(NSString *)category
                         notes:(NSString *)notes
                 amountSatoshi:(uint64_t)amountSatoshi;
{
    tABC_Error error;
    ABCSpend *abcSpend = [[ABCSpend alloc] init:self];
    tABC_SpendTarget *pSpend = NULL;
    
    ABC_SpendNewInternal([address UTF8String], [label UTF8String],
                         [category UTF8String], [notes UTF8String],
                         amountSatoshi, &pSpend, &error);
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        [abcSpend spendObjectSet:(void *)pSpend];
        return abcSpend;
    }
    return nil;
}

- (void)importPrivateKey:(NSString *)privateKey
               importing:(void (^)(NSString *address)) importingHandler
                complete:(void (^)(ABCImportDataModel dataModel, NSString *address, NSString *txid, uint64_t amount)) completionHandler
                   error:(void (^)(NSError *error)) errorHandler;
{
    bool bSuccess = NO;
    tABC_Error error;
    NSError *nserror = nil;
    
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
        // private key is a valid format
        // attempt to sweep it
        NSString *address;
        nserror = [self sweepKey:privateKey
                      intoWallet:self.uuid
                         address:&address];
        self.sweptAddress = address;
        
        if (nil != self.sweptAddress && self.sweptAddress.length)
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

- (NSString *)exportTransactionsToCSV
{
    NSString *csv;
    
    char *szCsvData = nil;
    tABC_Error error;
    int64_t startTime = 0; // Need to pull this from GUI
    int64_t endTime = 0x0FFFFFFFFFFFFFFF; // Need to pull this from GUI
    
    ABCConditionCode ccode;
    ABC_CsvExport([self.account.name UTF8String],
                  [self.account.password UTF8String],
                  [self.uuid UTF8String],
                  startTime, endTime, &szCsvData, &error);
    ccode = [self.abcError setLastErrors:error];
    
    if (ccode == ABCConditionCodeOk)
    {
        csv = [NSString stringWithCString:szCsvData encoding:NSASCIIStringEncoding];
    }
    if (szCsvData) free(szCsvData);
    return csv;
}

- (NSString *)exportWalletPrivateSeed
{
    NSString *seed;
    tABC_Error error;
    char *szSeed = NULL;
    ABCConditionCode ccode;
    ABC_ExportWalletSeed([self.account.name UTF8String],
                         [self.account.password UTF8String],
                         [self.uuid UTF8String],
                         &szSeed, &error);
    ccode = [self.abcError setLastErrors:error];
    if (ccode == ABCConditionCodeOk)
    {
        seed = [NSString stringWithUTF8String:szSeed];
    }
    if (szSeed) free(szSeed);
    return seed;
}

- (ABCConditionCode)finalizeRequestWithAddress:(NSString *)address;
{
    tABC_Error error;
    ABC_FinalizeReceiveRequest([self.account.name UTF8String],
                               [self.account.password UTF8String],
                               [self.uuid UTF8String],
                               [address UTF8String],
                               &error);
    return [self.abcError setLastErrors:error];
}

- (void)prioritizeAddress:(NSString *)address;
{
    if (!address)
        return;
    
    [self.account postToWatcherQueue:^{
        tABC_Error Error;
        ABC_PrioritizeAddress([self.account.name UTF8String],
                              [self.account.password UTF8String],
                              [self.uuid UTF8String],
                              [address UTF8String],
                              &Error);
        [self.abcError setLastErrors:Error];
        
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
        transaction = [[ABCTransaction alloc] init];
        [self setTransaction:transaction coreTx:pTrans];
    }
    else
    {
        ABCLog(2,@("Error: AirbitzCore.loadTransactions:  %s\n"), Error.szDescription);
        [self.abcError setLastErrors:Error];
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
            transaction = [[ABCTransaction alloc] init];
            [self setTransaction:transaction coreTx:pTrans];
            [arrayTransactions addObject:transaction];
        }
        SInt64 bal = 0;
        for (int j = (int) arrayTransactions.count - 1; j >= 0; --j)
        {
            ABCTransaction *t = arrayTransactions[j];
            bal += t.amountSatoshi;
            t.balance = bal;
        }
        self.arrayTransactions = arrayTransactions;
        self.balance = bal;
    }
    else
    {
        ABCLog(2,@("Error: AirbitzCore.loadTransactions:  %s\n"), Error.szDescription);
        [self.abcError setLastErrors:Error];
    }
    ABC_FreeTransactions(aTransactions, tCount);
}

- (void)setTransaction:(ABCTransaction *) transaction coreTx:(tABC_TxInfo *) pTrans
{
    transaction.txid = [NSString stringWithUTF8String: pTrans->szID];
    transaction.payeeName = [NSString stringWithUTF8String: pTrans->pDetails->szName];
    transaction.notes = [NSString stringWithUTF8String: pTrans->pDetails->szNotes];
    transaction.category = [NSString stringWithUTF8String: pTrans->pDetails->szCategory];
    transaction.date = [self.account.abc dateFromTimestamp: pTrans->timeCreation];
    transaction.amountSatoshi = pTrans->pDetails->amountSatoshi;
    transaction.amountFiat = pTrans->pDetails->amountCurrency;
    transaction.abFees = pTrans->pDetails->amountFeesAirbitzSatoshi;
    transaction.minerFees = pTrans->pDetails->amountFeesMinersSatoshi;
    transaction.wallet = self;
    if (pTrans->szMalleableTxId) {
        transaction.malleableTxid = [NSString stringWithUTF8String: pTrans->szMalleableTxId];
    }
    bool bSyncing = NO;
    transaction.confirmations = [self calcTxConfirmations:transaction.txid
                                                isSyncing:&bSyncing];
    transaction.bConfirmed = transaction.confirmations >= ABCConfirmedConfirmationCount;
    transaction.bSyncing = bSyncing;
    NSMutableArray *outputs = [[NSMutableArray alloc] init];
    for (int i = 0; i < pTrans->countOutputs; ++i)
    {
        ABCTxOutput *output = [[ABCTxOutput alloc] init];
        output.strAddress = [NSString stringWithUTF8String: pTrans->aOutputs[i]->szAddress];
        output.bInput = pTrans->aOutputs[i]->input;
        output.value = pTrans->aOutputs[i]->value;
        
        [outputs addObject:output];
    }
    transaction.outputs = outputs;
    transaction.bizId = pTrans->pDetails->bizId;
}

- (int)calcTxConfirmations:(NSString *)txId isSyncing:(bool *)syncing
{
    tABC_Error Error;
    int txHeight = 0;
    int blockHeight = 0;
    *syncing = NO;
    if ([self.uuid length] == 0 || [txId length] == 0) {
        return 0;
    }
    if (ABC_TxHeight([self.uuid UTF8String], [txId UTF8String], &txHeight, &Error) != ABC_CC_Ok) {
        *syncing = YES;
        if (txHeight < 0)
        {
            ABCLog(0, @"calcTxConfirmations returning negative txHeight=%d", txHeight);
            return txHeight;
        }
        else
            return 0;
    }
    if (ABC_BlockHeight([self.uuid UTF8String], &blockHeight, &Error) != ABC_CC_Ok) {
        *syncing = YES;
        return 0;
    }
    if (txHeight == 0 || blockHeight == 0) {
        return 0;
    }
    
    int retHeight = (blockHeight - txHeight) + 1;
    
    if (retHeight < 0)
    {
        retHeight = 0;
    }
    return retHeight;
}

- (NSMutableArray *)searchTransactionsIn:(NSString *)term addTo:(NSMutableArray *) arrayTransactions;
{
    tABC_Error Error;
    unsigned int tCount = 0;
    ABCTransaction *transaction;
    tABC_TxInfo **aTransactions = NULL;
    tABC_CC result = ABC_SearchTransactions([self.account.name UTF8String],
                                            [self.account.password UTF8String],
                                            [self.uuid UTF8String], [term UTF8String],
                                            &aTransactions, &tCount, &Error);
    if (ABC_CC_Ok == result)
    {
        for (int j = tCount - 1; j >= 0; --j) {
            tABC_TxInfo *pTrans = aTransactions[j];
            transaction = [[ABCTransaction alloc] init];
            [self setTransaction:transaction coreTx:pTrans];
            [arrayTransactions addObject:transaction];
        }
    }
    else
    {
        ABCLog(2,@("Error: AirbitzCore.searchTransactionsIn:  %s\n"), Error.szDescription);
        [self.abcError setLastErrors:Error];
    }
    ABC_FreeTransactions(aTransactions, tCount);
    return arrayTransactions;
}

- (void)loadWalletFromCore:(NSString *)uuid;
{
    tABC_Error error;
    self.uuid = uuid;
    self.name = loadingText;
    self.currencyNum = -1;
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
            self.currencyNum = currencyNum;
            self.currencyAbbrev = [self.account.abc currencyAbbrevLookup:self.currencyNum];
            self.currencySymbol = [self.account.abc currencySymbolLookup:self.currencyNum];
            self.loaded = YES;
        } else {
            self.loaded = NO;
            self.currencyNum = -1;
            self.name = loadingText;
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
                [self.abcError setLastErrors:error];
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
    return [self.account conversionStringFromNum:self.currencyNum withAbbrev:YES];
}



- (ABCConditionCode) getLastConditionCode;
{
    return [self.abcError getLastConditionCode];
}

- (NSString *) getLastErrorString;
{
    return [self.abcError getLastErrorString];
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
	return([NSString stringWithFormat:@"Wallet - UUID: %@, Name: %@, CurrencyNum: %d, Attributes: %d, Balance: %lf, Transactions: %@",
            self.uuid,
            self.name,
//            self.strUserName,
            self.currencyNum,
            self.archived,
            self.balance,
            self.arrayTransactions
            ]);
}

#pragma mark - Private Key Sweep helper methods

- (NSError *)sweepKey:(NSString *)privateKey intoWallet:(NSString *)walletUUID address:(NSString **)address
{
    tABC_Error error;
    NSError *nserror = nil;
    char *pszAddress = NULL;
    ABC_SweepKey([self.account.name UTF8String],
                 [self.account.password UTF8String],
                 [walletUUID UTF8String],
                 [privateKey UTF8String],
                 &pszAddress,
                 &error);
    nserror = [ABCError makeNSError:error];
    if (!nserror && pszAddress)
    {
        *address = [NSString stringWithUTF8String:pszAddress];
        free(pszAddress);
    }
    return nserror;
}

- (void)handleSweepCallback:(NSString *)txid amount:(uint64_t)amount error:(NSError *)error;
{
    [self cancelImportExpirationTimer];
//    
//    tABC_Error error;
//    ABCConditionCode ccode;
//    error.code = cc;
//    ccode = [wallet.abcError setLastErrors:error];
//    
//    NSString *txid = nil;
//    if (szID)
//    {
//        txid = [NSString stringWithUTF8String:szID];
//    }
//    else
//    {
//        txid = @"";
//    }
//    
    if (!error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.importCompletionHandler) self.importCompletionHandler(self.importDataModel, self.sweptAddress, txid, amount);
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
    NSError *nserror = [ABCError makeNSError:error];
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
