//
//  ABCWallet.m
//  Airbitz
//
//  Created by Paul Puey.
//  Copyright (c) 2016 AirBitz. All rights reserved.
//

#import "ABC.h"
#import "ABCWallet.h"
#import "ABCRequest.h"
#import "ABCError.h"
#import "ABCUtil.h"
#import "ABCTxOutput.h"
#import "ABCTransaction.h"
#import "ABCStrings.h"
#import "ABCUser+Internal.h"
#import "AirbitzCore+Internal.h"


#define HIDDEN_BITZ_URI_SCHEME                          @"hbits"
static const int importTimeout                  = 30;

@interface ABCWallet ()

@property (nonatomic, strong)   ABCError                    *abcError;
@property (nonatomic, strong)   void                        (^importCompletionHandler)(ABCImportDataModel dataModel, NSString *address, NSString *txid, uint64_t amount);
@property (nonatomic, strong)   void                        (^importErrorHandler)(ABCConditionCode ccode, NSString *errorString);
@property                       ABCImportDataModel          importDataModel;
@property (nonatomic, strong)   NSString                    *sweptAddress;
@property (nonatomic, strong)   NSTimer                     *importCallbackTimer;


@end

@implementation ABCWallet

#pragma mark - NSObject overrides

- (id)initWithUser:(ABCUser *) user;
{
    self = [super init];
    if (self) 
	{
        self.strUUID = @"";
        self.strName = @"";
        self.arrayTransactions = [[NSArray alloc] init];
        self.abcError = [[ABCError alloc] init];
        self.user = user;

    }
    return self;
}

- (void)dealloc 
{

}



- (ABCConditionCode)createReceiveRequestWithDetails:(ABCRequest *)request;
{
    tABC_Error error;
    tABC_TxDetails details;
    ABCConditionCode ccode;
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
    ABC_CreateReceiveRequest([self.user.name UTF8String],
                             [self.user.password UTF8String],
                             [request.wallet.strUUID UTF8String],
                             &details,
                             &pRequestID,
                             &error);
    ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk != ccode)
        goto exitnow;
    request.requestID = [NSString stringWithUTF8String:pRequestID];
    
    ABC_ModifyReceiveRequest([self.user.name UTF8String],
                             [self.user.password UTF8String],
                             [request.wallet.strUUID UTF8String],
                             pRequestID,
                             &details,
                             &error);
    ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk != ccode)
        goto exitnow;
    
    unsigned int width = 0;
    ABC_GenerateRequestQRCode([self.user.name UTF8String],
                              [self.user.password UTF8String],
                              [request.wallet.strUUID UTF8String],
                              pRequestID,
                              &pszURI,
                              &pData,
                              &width,
                              &error);
    ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk != ccode)
        goto exitnow;
    request.qrCode = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    request.uri    = [NSString stringWithUTF8String:pszURI];
    
    ABC_GetRequestAddress([self.user.name UTF8String],
                          [self.user.password UTF8String],
                          [request.wallet.strUUID UTF8String],
                          pRequestID,
                          &szRequestAddress,
                          &error);
    ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk != ccode)
        goto exitnow;
    
    request.address = [NSString stringWithUTF8String:szRequestAddress];
    
exitnow:
    
    if (pRequestID) free(pRequestID);
    if (szRequestAddress) free(szRequestAddress);
    if (pData) free(pData);
    if (pszURI) free(pszURI);
    
    return ccode;
}

- (void)createReceiveRequestWithDetails:(ABCRequest *)request
                               complete:(void (^)(void)) completionHandler
                                  error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler
{
    [self.user postToGenQRQueue:^(void)
     {
         ABCConditionCode ccode = [self createReceiveRequestWithDetails:request];
         NSString *errorString = [self.abcError getLastErrorString];
         dispatch_async(dispatch_get_main_queue(), ^(void)
                        {
                            if (ABCConditionCodeOk == ccode)
                            {
                                if (completionHandler) completionHandler();
                            }
                            else
                            {
                                if (errorHandler) errorHandler(ccode, errorString);
                            }
                        });
         
     }];
}

- (ABCSpend *)newSpendFromText:(NSString *)uri;
{
    tABC_Error error;
    if (!uri)
    {
        error.code = (tABC_CC)ABCConditionCodeNULLPtr;
        [self.abcError setLastErrors:error];
        return nil;
    }
    ABCSpend *abcSpend = [[ABCSpend alloc] init:self];
    tABC_SpendTarget *pSpend = NULL;
    
    ABC_SpendNewDecode([uri UTF8String], &pSpend, &error);
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        [abcSpend spendObjectSet:(void *)pSpend];
        return abcSpend;
    }
    return nil;
}

- (void)newSpendFromText:(NSString *)uri
                complete:(void(^)(ABCSpend *sp))completionHandler
                   error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    [self.user postToMiscQueue:^{
        ABCSpend *abcSpend;
        abcSpend = [self newSpendFromText:uri];
        NSString *errorString = [self getLastErrorString];
        ABCConditionCode ccode = [self getLastConditionCode];
        
        dispatch_async(dispatch_get_main_queue(),^{
            if (ABCConditionCodeOk == ccode) {
                if (completionHandler) completionHandler(abcSpend);
            } else {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    }];
}

- (ABCSpend *)newSpendTransfer:(ABCWallet *)destWallet;
{
    tABC_Error error;
    if (!destWallet)
    {
        error.code = (tABC_CC)ABCConditionCodeNULLPtr;
        [self.abcError setLastErrors:error];
        return nil;
    }
    ABCSpend *abcSpend = [[ABCSpend alloc] init:self];
    tABC_SpendTarget *pSpend = NULL;
    
    ABC_SpendNewTransfer([self.user.name UTF8String],
                         [destWallet.strUUID UTF8String], 0, &pSpend, &error);
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        abcSpend.destWallet = destWallet;
        [abcSpend spendObjectSet:(void *)pSpend];
        return abcSpend;
    }
    return nil;
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
                   error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    bool bSuccess = NO;
    tABC_Error error;
    ABCConditionCode ccode;
    
    // We will use the sweep callback to call these GUI handlers when done.
    self.importCompletionHandler = completionHandler;
    self.importErrorHandler = errorHandler;
    
    if (!privateKey || !self.strUUID)
    {
        error.code = ABC_CC_NULLPtr;
        ccode = [self.abcError setLastErrors:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errorHandler) errorHandler(ccode, [self getLastErrorString]);
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
        ccode = [self sweepKey:privateKey
                    intoWallet:self.strUUID
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
            ccode = [self.abcError setLastErrors:error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errorHandler) errorHandler(ccode, [self getLastErrorString]);
            });
            return;
        }
    }
    
    if (!bSuccess)
    {
        error.code = ABC_CC_ParseError;
        ccode = [self.abcError setLastErrors:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errorHandler) errorHandler(ccode, [self getLastErrorString]);
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
    ABC_CsvExport([self.user.name UTF8String],
                  [self.user.password UTF8String],
                  [self.strUUID UTF8String],
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
    ABC_ExportWalletSeed([self.user.name UTF8String],
                         [self.user.password UTF8String],
                         [self.strUUID UTF8String],
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
    ABC_FinalizeReceiveRequest([self.user.name UTF8String],
                               [self.user.password UTF8String],
                               [self.strUUID UTF8String],
                               [address UTF8String],
                               &error);
    return [self.abcError setLastErrors:error];
}

- (void)prioritizeAddress:(NSString *)address;
{
    if (!address)
        return;
    
    [self.user postToWatcherQueue:^{
        tABC_Error Error;
        ABC_PrioritizeAddress([self.user.name UTF8String],
                              [self.user.password UTF8String],
                              [self.strUUID UTF8String],
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
    
    tABC_CC result = ABC_GetTransaction([self.user.name UTF8String],
                                        [self.user.password UTF8String],
                                        [self.strUUID UTF8String], [txId UTF8String],
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
    tABC_CC result = ABC_GetTransactions([self.user.name UTF8String],
                                         [self.user.password UTF8String],
                                         [self.strUUID UTF8String],
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
    transaction.strID = [NSString stringWithUTF8String: pTrans->szID];
    transaction.strName = [NSString stringWithUTF8String: pTrans->pDetails->szName];
    transaction.strNotes = [NSString stringWithUTF8String: pTrans->pDetails->szNotes];
    transaction.strCategory = [NSString stringWithUTF8String: pTrans->pDetails->szCategory];
    transaction.date = [self.user.abc dateFromTimestamp: pTrans->timeCreation];
    transaction.amountSatoshi = pTrans->pDetails->amountSatoshi;
    transaction.amountFiat = pTrans->pDetails->amountCurrency;
    transaction.abFees = pTrans->pDetails->amountFeesAirbitzSatoshi;
    transaction.minerFees = pTrans->pDetails->amountFeesMinersSatoshi;
    transaction.strWalletName = self.strName;
    transaction.wallet = self;
    if (pTrans->szMalleableTxId) {
        transaction.strMalleableID = [NSString stringWithUTF8String: pTrans->szMalleableTxId];
    }
    bool bSyncing = NO;
    transaction.confirmations = [self calcTxConfirmations:transaction.strID
                                                isSyncing:&bSyncing];
    transaction.bConfirmed = transaction.confirmations >= ABC_CONFIRMED_CONFIRMATION_COUNT;
    transaction.bSyncing = bSyncing;
    if (transaction.strName) {
        transaction.strAddress = transaction.strName;
    } else {
        transaction.strAddress = @"";
    }
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
    if ([self.strUUID length] == 0 || [txId length] == 0) {
        return 0;
    }
    if (ABC_TxHeight([self.strUUID UTF8String], [txId UTF8String], &txHeight, &Error) != ABC_CC_Ok) {
        *syncing = YES;
        if (txHeight < 0)
        {
            ABCLog(0, @"calcTxConfirmations returning negative txHeight=%d", txHeight);
            return txHeight;
        }
        else
            return 0;
    }
    if (ABC_BlockHeight([self.strUUID UTF8String], &blockHeight, &Error) != ABC_CC_Ok) {
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
    tABC_CC result = ABC_SearchTransactions([self.user.name UTF8String],
                                            [self.user.password UTF8String],
                                            [self.strUUID UTF8String], [term UTF8String],
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
    self.strUUID = uuid;
    self.strName = loadingText;
    self.currencyNum = -1;
    self.balance = 0;
    self.loaded = NO;
    
    if ([self.user watcherExists:uuid]) {
        char *szName = NULL;
        ABC_WalletName([self.user.name UTF8String], [uuid UTF8String], &szName, &error);
        
        if (error.code == ABC_CC_Ok) {
            self.strName = [ABCUtil safeStringWithUTF8String:szName];
        }
        
        if (szName) {
            free(szName);
        }
        
        int currencyNum;
        ABC_WalletCurrency([self.user.name UTF8String], [uuid UTF8String], &currencyNum, &error);
        if (error.code == ABC_CC_Ok) {
            self.currencyNum = currencyNum;
            self.currencyAbbrev = [self.user.abc currencyAbbrevLookup:self.currencyNum];
            self.currencySymbol = [self.user.abc currencySymbolLookup:self.currencyNum];
            self.loaded = YES;
        } else {
            self.loaded = NO;
            self.currencyNum = -1;
            self.strName = loadingText;
        }
        
        int64_t balance;
        ABC_WalletBalance([self.user.name UTF8String], [uuid UTF8String], &balance, &error);
        if (error.code == ABC_CC_Ok) {
            self.balance = balance;
        } else {
            self.balance = 0;
        }
    }
    
    bool archived = false;
    ABC_WalletArchived([self.user.name UTF8String], [uuid UTF8String], &archived, &error);
    self.archived = archived ? YES : NO;
}



//
// This triggers a switch of libbitcoin servers and possibly an update if new information comes in
//
- (void)refreshServer:(BOOL)bData notify:(void(^)(void))cb;
{
    [self.user connectWatcher:self.strUUID];
    [self.user postToMiscQueue:^{
        // Reconnect the watcher for this wallet
        if (bData) {
            // Clear data sync queue and sync the current wallet immediately
            [self.user clearDataQueue];
            [self.user postToDataQueue:^{
                if (![self.user isLoggedIn]) {
                    return;
                }
                tABC_Error error;
                bool bDirty = false;
                ABC_DataSyncWallet([self.user.name UTF8String],
                                   [self.user.password UTF8String],
                                   [self.strUUID UTF8String],
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
    return [self.user conversionStringFromNum:self.currencyNum withAbbrev:YES];
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
		
        if ([self.strUUID isEqualToString:walletOther.strUUID])
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
    return([self.strUUID hash]);
}

// overriding the description - used in debugging
- (NSString *)description
{
	return([NSString stringWithFormat:@"Wallet - UUID: %@, Name: %@, CurrencyNum: %d, Attributes: %d, Balance: %lf, Transactions: %@",
            self.strUUID,
            self.strName,
//            self.strUserName,
            self.currencyNum,
            self.archived,
            self.balance,
            self.arrayTransactions
            ]);
}

#pragma mark - Private Key Sweep helper methods

- (ABCConditionCode)sweepKey:(NSString *)privateKey intoWallet:(NSString *)walletUUID address:(NSString **)address
{
    tABC_Error error;
    char *pszAddress = NULL;
    void *pData = (__bridge void *) self;
    ABC_SweepKey([self.user.name UTF8String],
                 [self.user.password UTF8String],
                 [walletUUID UTF8String],
                 [privateKey UTF8String],
                 &pszAddress,
                 ABC_Sweep_Complete_Callback,
                 pData,
                 &error);
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk == ccode && pszAddress)
    {
        *address = [NSString stringWithUTF8String:pszAddress];
        free(pszAddress);
    }
    return ccode;
}

void ABC_Sweep_Complete_Callback(void *pData, tABC_CC cc, const char *szID, uint64_t amount)
{
    ABCWallet *wallet = (__bridge ABCWallet *) pData;
    [wallet cancelImportExpirationTimer];
    
    tABC_Error error;
    ABCConditionCode ccode;
    error.code = cc;
    ccode = [wallet.abcError setLastErrors:error];
    
    NSString *txid = nil;
    if (szID)
    {
        txid = [NSString stringWithUTF8String:szID];
    }
    else
    {
        txid = @"";
    }
    
    if (ABCConditionCodeOk == ccode)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (wallet.importCompletionHandler) wallet.importCompletionHandler(wallet.importDataModel, wallet.sweptAddress, txid, amount);
            wallet.importErrorHandler = nil;
            wallet.importCompletionHandler = nil;
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (wallet.importErrorHandler) wallet.importErrorHandler(ccode, [wallet getLastErrorString]);
            wallet.importErrorHandler = nil;
            wallet.importCompletionHandler = nil;
        });
    }
    
}

- (void)expireImport
{
    self.importCallbackTimer = nil;
    tABC_Error error;
    error.code = ABC_CC_NoTransaction;
    ABCConditionCode ccode = [self.abcError setLastErrors:error];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.importErrorHandler) self.importErrorHandler(ccode, [self getLastErrorString]);
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
