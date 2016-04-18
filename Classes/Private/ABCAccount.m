
#import "AirbitzCore+Internal.h"
#import "ABCAccount.h"
#import <pthread.h>

static const int   fileSyncFrequencySeconds   = 30;
static const int64_t recoveryReminderAmount   = 10000000;
static const int recoveryReminderCount        = 2;
static const int notifySyncDelay          = 1;

@interface ABCAccount ()
{
    ABCError                                        *abcError;
    long long                                       logoutTimeStamp;
    
    BOOL                                            bInitialized;
    BOOL                                            bHasSentWalletsLoaded;
    long                                            iLoginTimeSeconds;
    NSOperationQueue                                *exchangeQueue;
    NSOperationQueue                                *dataQueue;
    NSOperationQueue                                *walletsQueue;
    NSOperationQueue                                *genQRQueue;
    NSOperationQueue                                *miscQueue;
    NSOperationQueue                                *watcherQueue;
    NSLock                                          *watcherLock;
    NSMutableDictionary                             *watchers;
    
    NSTimer                                         *exchangeTimer;
    NSTimer                                         *dataSyncTimer;
    NSTimer                                         *notificationTimer;
    
}

@property (atomic, strong)      AirbitzCore         *abc;
@property (nonatomic, strong)   NSTimer             *walletLoadingTimer;
@property                       BOOL                bNewDeviceLogin;
@property (atomic, copy)        NSString            *password;

@end

@implementation ABCAccount

- (id)initWithCore:(AirbitzCore *)airbitzCore;
{
    
    if (NO == bInitialized)
    {
        if (!airbitzCore) return nil;
        
        self.abc                    = airbitzCore;
        self.exchangeCache          = self.abc.exchangeCache;
        self.dataStore              = [ABCDataStore alloc];
        self.dataStore.account      = self;
        self.categories             = [[ABCCategories alloc] initWithAccount:self];
        
        abcError = [[ABCError alloc] init];
        
        exchangeQueue = [[NSOperationQueue alloc] init];
        [exchangeQueue setMaxConcurrentOperationCount:1];
        dataQueue = [[NSOperationQueue alloc] init];
        [dataQueue setMaxConcurrentOperationCount:1];
        walletsQueue = [[NSOperationQueue alloc] init];
        [walletsQueue setMaxConcurrentOperationCount:1];
        genQRQueue = [[NSOperationQueue alloc] init];
        [genQRQueue setMaxConcurrentOperationCount:1];
        miscQueue = [[NSOperationQueue alloc] init];
        [miscQueue setMaxConcurrentOperationCount:8];
        watcherQueue = [[NSOperationQueue alloc] init];
        [watcherQueue setMaxConcurrentOperationCount:1];
        
        watchers = [[NSMutableDictionary alloc] init];
        watcherLock = [[NSLock alloc] init];
        
        bInitialized = YES;
        bHasSentWalletsLoaded = NO;
        
        [self cleanWallets];
        
        self.settings = [[ABCSettings alloc] init:self localSettings:self.abc.localSettings keyChain:self.abc.keyChain];
        
    }
    return self;
}

- (void)fillSeedData:(NSMutableData *)data
{
    NSMutableString *strSeed = [[NSMutableString alloc] init];
    
    // add the UUID
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    [strSeed appendString:[[NSString alloc] initWithString:(__bridge NSString *)string]];
    CFRelease(string);
    
    // add the device name
#if TARGET_OS_IPHONE
    [strSeed appendString:[[UIDevice currentDevice] name]];
#endif
    
    // add the string to the data
    [data appendData:[strSeed dataUsingEncoding:NSUTF8StringEncoding]];
    
    double time = CACurrentMediaTime();
    
    [data appendBytes:&time length:sizeof(double)];
    
    UInt32 randomBytes = 0;
    if (0 == SecRandomCopyBytes(kSecRandomDefault, sizeof(int), (uint8_t*)&randomBytes)) {
        [data appendBytes:&randomBytes length:sizeof(UInt32)];
    }
    
    u_int32_t rand = arc4random();
    [data appendBytes:&rand length:sizeof(u_int32_t)];
}

- (void)free
{
    if (YES == bInitialized)
    {
        [self stopQueues];
        int wait = 0;
        int maxWait = 200; // ~10 seconds
        while ([self dataOperationCount] > 0 && wait < maxWait) {
            [NSThread sleepForTimeInterval:.2];
            wait++;
        }
        
        exchangeQueue = nil;
        dataQueue = nil;
        walletsQueue = nil;
        genQRQueue = nil;
        miscQueue = nil;
        watcherQueue = nil;
        bInitialized = NO;
        [self cleanWallets];
        self.settings = nil;
    }
}

- (void)startQueues
{
    if ([self isLoggedIn])
    {
        // Request one right now
        [self requestExchangeRateUpdate];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Initialize the exchange rates queue
            exchangeTimer = [NSTimer scheduledTimerWithTimeInterval:ABC_EXCHANGE_RATE_REFRESH_INTERVAL_SECONDS
                                                             target:self
                                                           selector:@selector(requestExchangeRateUpdate)
                                                           userInfo:nil
                                                            repeats:YES];
            
        });
    }
}

- (void)enterBackground
{
    if ([self isLoggedIn])
    {
        [self saveLogoutDate];
        [self stopQueues];
        [self disconnectWatchers];
    }
}

- (void)enterForeground
{
    if ([self isLoggedIn])
    {
        [self connectWatchers];
        [self startQueues];
    }
}

- (void)stopQueues
{
    if (exchangeTimer) {
        [exchangeTimer invalidate];
        exchangeTimer = nil;
    }
    if (dataSyncTimer) {
        [dataSyncTimer invalidate];
        dataSyncTimer = nil;
    }
    if (dataQueue)
        [dataQueue cancelAllOperations];
    if (walletsQueue)
        [walletsQueue cancelAllOperations];
    if (genQRQueue)
        [genQRQueue cancelAllOperations];
    if (exchangeQueue)
        [exchangeQueue cancelAllOperations];
    if (miscQueue)
        [miscQueue cancelAllOperations];
    
}

- (void)postToDataQueue:(void(^)(void))cb;
{
    [dataQueue addOperationWithBlock:cb];
}

- (void)postToWalletsQueue:(void(^)(void))cb;
{
    [walletsQueue addOperationWithBlock:cb];
}

- (void)postToGenQRQueue:(void(^)(void))cb;
{
    [genQRQueue addOperationWithBlock:cb];
}

- (void)postToMiscQueue:(void(^)(void))cb;
{
    [miscQueue addOperationWithBlock:cb];
}

- (void)postToWatcherQueue:(void(^)(void))cb;
{
    [watcherQueue addOperationWithBlock:cb];
}

- (int)dataOperationCount
{
    int total = 0;
    total += dataQueue == nil     ? 0 : [dataQueue operationCount];
    total += exchangeQueue == nil ? 0 : [exchangeQueue operationCount];
    total += walletsQueue == nil  ? 0 : [walletsQueue operationCount];
    total += genQRQueue == nil  ? 0 : [genQRQueue operationCount];
    total += watcherQueue == nil  ? 0 : [watcherQueue operationCount];
    return total;
}

- (void)clearDataQueue
{
    [dataQueue cancelAllOperations];
}

- (void)clearMiscQueue;
{
    [miscQueue cancelAllOperations];
}

// select the wallet with the given UUID
- (ABCWallet *)selectWalletWithUUID:(NSString *)strUUID
{
    ABCWallet *wallet = nil;
    
    if (strUUID)
    {
        if ([strUUID length])
        {
            // If the transaction view is open, close it
            
            // look for the wallet in our arrays
            if (self.arrayWallets)
            {
                for (ABCWallet *curWallet in self.arrayWallets)
                {
                    if ([strUUID isEqualToString:curWallet.uuid])
                    {
                        wallet = curWallet;
                        break;
                    }
                }
            }
            
            // if we haven't found it yet, try the archived wallets
            if (nil == wallet)
            {
                for (ABCWallet *curWallet in self.arrayArchivedWallets)
                {
                    if ([strUUID isEqualToString:curWallet.uuid])
                    {
                        wallet = curWallet;
                        break;
                    }
                }
            }
        }
    }
    
    return wallet;
}

- (NSArray *)listWalletIDs;
{
    return [self listWalletIDs:nil];
}

- (NSArray *)listWalletIDs:(NSError **)nserror;
{
    NSError *lnserror = nil;
    tABC_Error error;
    char **aUUIDS = NULL;
    unsigned int nCount;
    NSMutableArray *arrayUUIDs = [[NSMutableArray alloc] init];
    
    ABC_GetWalletUUIDs([self.name UTF8String],
                       [self.password UTF8String],
                       &aUUIDS, &nCount, &error);
    
    lnserror = [ABCError makeNSError:error];
    if (!lnserror)
    {
        if (aUUIDS)
        {
            unsigned int i;
            for (i = 0; i < nCount; ++i)
            {
                char *szUUID = aUUIDS[i];
                // If entry is NULL skip it
                if (!szUUID) {
                    continue;
                }
                [arrayUUIDs addObject:[NSString stringWithUTF8String:szUUID]];
                free(szUUID);
            }
            free(aUUIDS);
        }
    }
    if (nserror) *nserror = lnserror;
    
    return [NSArray arrayWithArray:arrayUUIDs];
}

- (void)loadWallets:(NSMutableArray *)arrayWallets withTxs:(BOOL)bWithTx
{
    ABCLog(2,@"ENTER loadWallets: %@", [NSThread currentThread].name);
    
    NSArray *arrayIDs = [self listWalletIDs];
    ABCWallet *wallet;
    for (NSString *uuid in arrayIDs) {
        wallet = [self getWallet:uuid];
        if (!wallet){
            wallet = [[ABCWallet alloc] initWithUser:self];
        }
        [wallet loadWalletFromCore:uuid];
        if (bWithTx && wallet.loaded) {
            [wallet loadTransactions];
        }
        [arrayWallets addObject:wallet];
    }
    ABCLog(2,@"EXIT loadWallets: %@", [NSThread currentThread].name);
    
}

- (void)makeCurrentWallet:(ABCWallet *)wallet
{
    if ([self.arrayWallets containsObject:wallet])
    {
        self.currentWallet = wallet;
        self.currentWalletIndex = (int) [self.arrayWallets indexOfObject:self.currentWallet];
    }
    else if ([self.arrayArchivedWallets containsObject:wallet])
    {
        self.currentWallet = wallet;
        self.currentWalletIndex = (int) [self.arrayArchivedWallets indexOfObject:self.currentWallet];
    }
    
    [self postNotificationWalletsChanged];
}

- (void)makeCurrentWalletWithUUID:(NSString *)strUUID
{
    if ([self.arrayWallets containsObject:self.currentWallet])
    {
        ABCWallet *wallet = [self selectWalletWithUUID:strUUID];
        [self makeCurrentWallet:wallet];
    }
}

#if TARGET_OS_IPHONE
- (void)makeCurrentWalletWithIndex:(NSIndexPath *)indexPath
{
    //
    // Set new wallet. Hide the dropdown. Then reload the TransactionsView table
    //
    ABCWallet *wallet = nil;
    if(indexPath.section == 0)
    {
        if ([self.arrayWallets count] > indexPath.row)
        {
            wallet = [self.arrayWallets objectAtIndex:indexPath.row];
            
        }
    }
    else
    {
        if ([self.arrayArchivedWallets count] > indexPath.row)
        {
            wallet = [self.arrayArchivedWallets objectAtIndex:indexPath.row];
        }
    }

    if (wallet)
    {
        [self makeCurrentWallet:wallet];
        [self postNotificationWalletsChanged];
    }
    
}
#endif

- (void)cleanWallets
{
    self.arrayWallets = nil;
    self.arrayArchivedWallets = nil;
    self.arrayWalletNames = nil;
    self.currentWallet = nil;
    self.currentWalletIndex = 0;
    self.numWalletsLoaded = 0;
    self.numTotalWallets = 0;
    self.bAllWalletsLoaded = NO;
}

- (void)refreshWallets;
{
    [self refreshWallets:nil];
}

- (void)refreshWallets:(void(^)(void))cb
{
    [self postToWatcherQueue:^(void) {
        [self postToWalletsQueue:^(void) {
            ABCLog(2,@"ENTER refreshWallets WalletQueue: %@", [NSThread currentThread].name);
            NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
            NSMutableArray *arrayArchivedWallets = [[NSMutableArray alloc] init];
            NSMutableArray *arrayWalletNames = [[NSMutableArray alloc] init];
            
            [self loadWallets:arrayWallets archived:arrayArchivedWallets withTxs:true];
            
            //
            // Update wallet names for various dropdowns
            //
            int loadingCount = 0;
            for (int i = 0; i < [arrayWallets count]; i++)
            {
                ABCWallet *wallet = [arrayWallets objectAtIndex:i];
//                [arrayWalletNames addObject:[NSString stringWithFormat:@"%@ (%@)", wallet.name, [self formatSatoshi:wallet.balance]]];
                [arrayWalletNames addObject:[NSString stringWithFormat:@"%@ (%@)", wallet.name,
                                             [self.settings.denomination satoshiToBTCString:wallet.balance]]];
                if (!wallet.loaded) {
                    loadingCount++;
                }
            }
            
            for (int i = 0; i < [arrayArchivedWallets count]; i++)
            {
                ABCWallet *wallet = [arrayArchivedWallets objectAtIndex:i];
                if (!wallet.loaded) {
                    loadingCount++;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(),^{
                ABCLog(2,@"ENTER refreshWallets MainQueue: %@", [NSThread currentThread].name);
                self.arrayWallets = arrayWallets;
                self.arrayArchivedWallets = arrayArchivedWallets;
                self.arrayWalletNames = arrayWalletNames;
                self.numTotalWallets = (int) ([arrayWallets count] + [arrayArchivedWallets count]);
                self.numWalletsLoaded = self.numTotalWallets  - loadingCount;
                
                if (loadingCount == 0)
                {
                    self.bAllWalletsLoaded = YES;
                }
                else
                {
                    self.bAllWalletsLoaded = NO;
                }
                
                if (nil == self.currentWallet)
                {
                    if ([self.arrayWallets count] > 0)
                    {
                        self.currentWallet = [arrayWallets objectAtIndex:0];
                    }
                    self.currentWalletIndex = 0;
                }
                else
                {
                    NSString *lastCurrentWalletUUID = self.currentWallet.uuid;
                    self.currentWallet = [self selectWalletWithUUID:lastCurrentWalletUUID];
                    self.currentWalletIndex = (int) [self.arrayWallets indexOfObject:self.currentWallet];
                }
                [self checkWalletsLoadingNotification];
                [self postNotificationWalletsChanged];
                
                ABCLog(2,@"EXIT refreshWallets MainQueue: %@", [NSThread currentThread].name);
                
                if (cb) cb();
                
            });
            ABCLog(2,@"EXIT refreshWallets WalletQueue: %@", [NSThread currentThread].name);
        }];
    }];
}

- (void)checkWalletsLoadingNotification
{
    if (!self.bNewDeviceLogin)
    {
        ABCLog(1, @"************ numWalletsLoaded=%d", self.numWalletsLoaded);
        if (self.arrayWallets && self.numWalletsLoaded > 0)
        {
            // Loop over all wallets and post them as loaded if they are
            for (ABCWallet *w in self.arrayWallets)
            {
                // This loaded flag only means the wallet info has been loaded from disk,
                // not that all addresses have been checked on the blockchain. This is fine
                // for logins on a previous device. For new device logins, we will wait for
                // ABC_AsyncEventType_AddressCheckDone
                if (w.loaded)
                    [self postWalletsLoadedNotification:w];
            }
        }
    }
}

- (void)postWalletsLoadedNotification:(ABCWallet *)wallet
{
    self.bNewDeviceLogin = NO;
    if (self.delegate && !wallet.bAddressesLoaded) {
        wallet.bAddressesLoaded = YES;
        if ([self.delegate respondsToSelector:@selector(abcAccountWalletLoaded:)]) {
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate abcAccountWalletLoaded:wallet];
            });
        }
    }
}

- (void) postNotificationWalletsChanged
{
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(abcAccountWalletsChanged)]) {
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate abcAccountWalletsChanged];
            });
        }
    }
}


- (void)loadWallets:(NSMutableArray *)arrayWallets archived:(NSMutableArray *)arrayArchivedWallets withTxs:(BOOL)bWithTx
{
    [self loadWallets:arrayWallets withTxs:bWithTx];
    
    // go through all the wallets and seperate out the archived ones
    for (int i = (int) [arrayWallets count] - 1; i >= 0; i--)
    {
        ABCWallet *wallet = [arrayWallets objectAtIndex:i];
        
        // if this is an archived wallet
        if (wallet.archived)
        {
            // add it to the archive wallet
            if (arrayArchivedWallets != nil)
            {
                [arrayArchivedWallets insertObject:wallet atIndex:0];
            }
            
            // remove it from the standard wallets
            [arrayWallets removeObjectAtIndex:i];
        }
    }
}

- (ABCWallet *)getWallet: (NSString *)walletUUID
{
    for (ABCWallet *wallet in self.arrayWallets)
    {
        if ([wallet.uuid isEqualToString:walletUUID])
            return wallet;
    }
    for (ABCWallet *wallet in self.arrayArchivedWallets)
    {
        if ([wallet.uuid isEqualToString:walletUUID])
            return wallet;
    }
    return nil;
}

#if TARGET_OS_IPHONE
- (NSError *)reorderWallets:(NSIndexPath *)sourceIndexPath
                toIndexPath:(NSIndexPath *)destinationIndexPath;
{
    tABC_Error error;
    NSError *nserror = nil;
    ABCWallet *wallet;
    if(sourceIndexPath.section == 0)
    {
        wallet = [self.arrayWallets objectAtIndex:sourceIndexPath.row];
        [self.arrayWallets removeObjectAtIndex:sourceIndexPath.row];
    }
    else
    {
        wallet = [self.arrayArchivedWallets objectAtIndex:sourceIndexPath.row];
        [self.arrayArchivedWallets removeObjectAtIndex:sourceIndexPath.row];
    }
    
    if(destinationIndexPath.section == 0)
    {
        wallet.archived = NO;
        [self.arrayWallets insertObject:wallet atIndex:destinationIndexPath.row];
    }
    else
    {
        wallet.archived = YES;
        [self.arrayArchivedWallets insertObject:wallet atIndex:destinationIndexPath.row];
    }
    
    if (sourceIndexPath.section != destinationIndexPath.section)
    {
        // Wallet moved to/from archive. Reset attributes to Core
        [self setWalletAttributes:wallet];
    }
    
    NSMutableString *uuids = [[NSMutableString alloc] init];
    for (ABCWallet *wallet in self.arrayWallets)
    {
        [uuids appendString:wallet.uuid];
        [uuids appendString:@"\n"];
    }
    for (ABCWallet *wallet in self.arrayArchivedWallets)
    {
        [uuids appendString:wallet.uuid];
        [uuids appendString:@"\n"];
    }
    
    NSString *ids = [uuids stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    ABC_SetWalletOrder([self.name UTF8String],
                       [self.password UTF8String],
                       (char *)[ids UTF8String],
                       &error);
    nserror = [ABCError makeNSError:error];
    if (nserror)
    {
        ABCLog(2,@("Error: AirbitzCore.reorderWallets:  %@\n"), nserror.userInfo[NSLocalizedDescriptionKey]);
    }
    
    [self refreshWallets];
    
    return nserror;
}
#endif

- (bool)setWalletAttributes: (ABCWallet *) wallet
{
    tABC_Error Error;
    tABC_CC result = ABC_SetWalletArchived([self.name UTF8String],
                                           [self.password UTF8String],
                                           [wallet.uuid UTF8String],
                                           wallet.archived, &Error);
    if (ABC_CC_Ok == result)
    {
        return true;
    }
    else
    {
        ABCLog(2,@("Error: AirbitzCore.setWalletAttributes:  %s\n"), Error.szDescription);
        return false;
    }
}

- (NSDate *)dateFromTimestamp:(int64_t) intDate
{
    return [NSDate dateWithTimeIntervalSince1970: intDate];
}

- (NSString *)createExchangeRateString:(ABCCurrency *)currency
                   includeCurrencyCode:(bool)includeCurrencyCode;
{
    NSError *error = nil;
    double fCurrency;
    ABCDenomination *denomination = self.settings.denomination;
    
    fCurrency = [self.exchangeCache satoshiToCurrency:denomination.multiplier
                                         currencyCode:currency.code
                                                error:&error];
    
    if (!error)
    {
        if (denomination.multiplier == ABCDenominationMultiplierUBTC)
        {
            if(includeCurrencyCode) {
                return [NSString stringWithFormat:@"1000 %@ = %@ %.3f %@",
                        denomination.symbol, currency.symbol, fCurrency*1000, currency.code];
            }
            else
            {
                return [NSString stringWithFormat:@"1000 %@ = %@ %.3f",
                        denomination.symbol, currency.symbol, fCurrency*1000];
            }
        }
        else
        {
            if(includeCurrencyCode) {
                return [NSString stringWithFormat:@"1 %@ = %@ %.3f %@",
                        denomination.symbol, currency.symbol, fCurrency, currency.code];
            }
            else
            {
                return [NSString stringWithFormat:@"1 %@ = %@ %.3f",
                        denomination.symbol, currency.symbol, fCurrency];
            }
        }
    }
    else
    {
        return @"";
    }
}

- (void)incRecoveryReminder
{
    [self incRecoveryReminder:1];
}

- (void)clearRecoveryReminder
{
    [self incRecoveryReminder:recoveryReminderCount];
}

- (void)incRecoveryReminder:(int)val
{
    tABC_Error error;
    tABC_AccountSettings *pSettings = NULL;
    tABC_CC cc = ABC_LoadAccountSettings([self.name UTF8String],
                                         [self.password UTF8String], &pSettings, &error);
    if (cc == ABC_CC_Ok) {
        pSettings->recoveryReminderCount += val;
        ABC_UpdateAccountSettings([self.name UTF8String],
                                  [self.password UTF8String], pSettings, &error);
    }
    ABC_FreeAccountSettings(pSettings);
}

- (int)getReminderCount
{
    int count = 0;
    tABC_Error error;
    tABC_AccountSettings *pSettings = NULL;
    tABC_CC cc = ABC_LoadAccountSettings([self.name UTF8String],
                                         [self.password UTF8String], &pSettings, &error);
    if (cc == ABC_CC_Ok) {
        count = pSettings->recoveryReminderCount;
    }
    ABC_FreeAccountSettings(pSettings);
    return count;
}

- (BOOL)needsRecoveryQuestionsReminder
{
    BOOL bResult = NO;
    int reminderCount = [self getReminderCount];
    if (self.currentWallet.balance >= recoveryReminderAmount && reminderCount < recoveryReminderCount) {
        NSError *error = nil;
        NSArray *arrayQuestions = [self.abc getRecoveryQuestionsForUserName:self.name
                                                                      error:&error];
        if (!arrayQuestions) {
            [self incRecoveryReminder];
            bResult = YES;
        } else {
            [self clearRecoveryReminder];
        }
    }
    return bResult;
}

- (BOOL) checkPIN:(NSString *)pin
{
    return [self checkPIN:pin error:nil];
}
- (BOOL) checkPIN:(NSString *)pin error:(NSError **)nserror;
{
    tABC_Error error;
    bool result = false;
    
    ABC_PinCheck([self.name UTF8String],
                 [self.password UTF8String],
                 [pin UTF8String],
                 &result,
                 &error);
    NSError *lnserror = [ABCError makeNSError:error];
    
    if (nserror) *nserror = lnserror;
    
    return result;
}


#define ABC_PIN_REQUIRED_PERIOD_SECONDS     120

- (BOOL)recentlyLoggedIn
{
    long now = (long) [[NSDate date] timeIntervalSince1970];
    return now - iLoginTimeSeconds <= ABC_PIN_REQUIRED_PERIOD_SECONDS;
}

- (void)login
{
//    dispatch_async(dispatch_get_main_queue(),^{
//        [self postWalletsLoadingNotification];
//    });
    [self.abc setLastAccessedAccount:self.name];
    [self.settings loadSettings];
    [self requestExchangeRateUpdate];
    
    //
    // Do the following for first wallet then all others
    //
    // ABC_WalletLoad
    // ABC_WatcherLoop
    // ABC_WatchAddresses
    //
    // This gets the app up and running and all prior transactions viewable with no new updates
    // From the network
    //
    [self startAllWallets];   // Goes to watcherQueue
    
    //
    // Next issue one dataSync for each wallet and account
    // This makes sure we have updated git sync data from other devices
    //
    [self postToWatcherQueue: ^
     {
         // Goes to dataQueue after watcherQueue is complete from above
         [self dataSyncAllWalletsAndAccount];
         
         //
         // Start the watchers to grab new blockchain transaction data. Do this AFTER git sync
         // So that new transactions will have proper meta data if other devices already tagged them
         //
         [self postToDataQueue:^
          {
              // Goes to watcherQueue after dataQueue is complete from above
              [self connectWatchers];
          }];
     }];
    
    //
    // Last, start the timers so we get repeated exchange rate updates and data syncs
    //
    [self postToWatcherQueue: ^
     {
         // Starts only after connectWatchers finishes from watcherQueue
         [self startQueues];
         
         iLoginTimeSeconds = [self saveLogoutDate];
         [self refreshWallets];
     }];
}

- (BOOL)didLoginExpire;
{
    //
    // If app was killed then the static var logoutTimeStamp will be zero so we'll pull the cached value
    // from the iOS ABCKeychain. Also, on non A7 processors, we won't save anything in the keychain so we need
    // the static var to take care of cases where app is not killed.
    //
    if (0 == logoutTimeStamp)
    {
        logoutTimeStamp = [self.abc.keyChain getKeychainInt:[self.abc.keyChain createKeyWithUsername:self.name key:LOGOUT_TIME_KEY] error:nil];
    }
    
    if (!logoutTimeStamp) return YES;
    
    long long currentTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    if (currentTimeStamp > logoutTimeStamp)
    {
        return YES;
    }
    
    return NO;
}

//
// Saves the UNIX timestamp when user should be auto logged out
// Returns the current time
//

- (long) saveLogoutDate;
{
    long currentTimeStamp = (long) [[NSDate date] timeIntervalSince1970];
    logoutTimeStamp = currentTimeStamp + (self.settings.secondsAutoLogout);
    
    // Save in iOS ABCKeychain
    [self.abc.keyChain setKeychainInt:logoutTimeStamp
                              key:[self.abc.keyChain createKeyWithUsername:self.name key:LOGOUT_TIME_KEY]
                    authenticated:YES];
    
    return currentTimeStamp;
}

- (void)startAllWallets
{
    NSArray *arrayIDs = [self listWalletIDs];
    for (NSString *uuid in arrayIDs) {
        [self postToWatcherQueue:^{
            tABC_Error error;
            ABC_WalletLoad([self.name UTF8String], [uuid UTF8String], &error);
        }];
        [self startWatcher:uuid];
        [self refreshWallets]; // Also goes to watcher queue.
    }
}

- (void)stopAsyncTasks
{
    [self stopQueues];
    
    unsigned long wq, gq, dq, eq, mq;
    
//    // XXX: prevents crashing on logout
    while (YES)
    {
        wq = (unsigned long)[walletsQueue operationCount];
        dq = (unsigned long)[dataQueue operationCount];
        gq = (unsigned long)[genQRQueue operationCount];
        eq = (unsigned long)[exchangeQueue operationCount];
        mq = (unsigned long)[miscQueue operationCount];
        
        //        if (0 == (wq + dq + gq + txq + eq + mq + lq))
        if (0 == (wq + gq  + eq + mq))
            break;
        
        ABCLog(0,
               @"Waiting for queues to complete wq=%lu dq=%lu gq=%lu eq=%lu mq=%lu",
               wq, dq, gq, eq, mq);
        [NSThread sleepForTimeInterval:.2];
    }
    
    [self stopWatchers];
    [self cleanWallets];
}

- (void)setConnectivity:(BOOL)hasConnectivity;
{
    if (hasConnectivity)
    {
        [self connectWatchers];
        [self startQueues];
    }
    else
    {
        [self disconnectWatchers];
        [self stopQueues];
    }
}

- (void)logout;
{
    [self.abc.keyChain disableRelogin:self.name];
    [self.abc.loggedInUsers removeObject:self];

    [self stopAsyncTasks];
    
    self.password = nil;
    self.name = nil;

    //
    // XXX Hack. Right now ABC only holds one logged in user using a key cache.
    // This should change and allow us to have multiple concurrent logged in
    // users.
    //
    tABC_Error Error;
    ABC_ClearKeyCache(&Error);

    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       if (self.delegate) {
                           if ([self.delegate respondsToSelector:@selector(abcAccountLoggedOut:)]) {
                               [self.delegate abcAccountLoggedOut:self];
                           }
                       }
                   });
}

- (BOOL)checkPassword:(NSString *)password
{
    NSString *name = self.name;
    bool ok = false;
    if (name && 0 < name.length)
    {
        const char *username = [name UTF8String];
        
        tABC_Error Error;
        ABC_PasswordOk(username, [password UTF8String], &ok, &Error);
    }
    return ok == true ? YES : NO;
}

- (BOOL)accountHasPassword { return [self accountHasPassword:nil]; }
- (BOOL)accountHasPassword:(NSError **)error;
{
    return [self.abc accountHasPassword:self.name error:error];
}

- (void)startWatchers
{
    NSArray *arrayIDs = [self listWalletIDs];
    for (NSString *uuid in arrayIDs) {
        [self startWatcher:uuid];
    }
    [self connectWatchers];
}

- (void)connectWatchers
{
    if ([self isLoggedIn]) {
        NSArray *arrayIDs = [self listWalletIDs];
        for (NSString *uuid in arrayIDs)
        {
            [self connectWatcher:uuid];
        }
    }
}

- (void)connectWatcher:(NSString *)uuid;
{
    [self postToWatcherQueue: ^{
        if ([self isLoggedIn]) {
            tABC_Error Error;
            ABC_WatcherConnect([uuid UTF8String], &Error);
        }
    }];
}

- (void)disconnectWatchers
{
    if ([self isLoggedIn])
    {
        NSArray *arrayIDs = [self listWalletIDs];
        for (NSString *uuid in arrayIDs) {
            [self postToWatcherQueue: ^{
                const char *szUUID = [uuid UTF8String];
                tABC_Error Error;
                ABC_WatcherDisconnect(szUUID, &Error);
            }];
        }
    }
}

- (BOOL)watcherExists:(NSString *)uuid;
{
    [watcherLock lock];
    BOOL exists = [watchers objectForKey:uuid] == nil ? NO : YES;
    [watcherLock unlock];
    return exists;
}

- (NSOperationQueue *)watcherGet:(NSString *)uuid
{
    [watcherLock lock];
    NSOperationQueue *queue = [watchers objectForKey:uuid];
    [watcherLock unlock];
    return queue;
}

- (void)watcherSet:(NSString *)uuid queue:(NSOperationQueue *)queue
{
    [watcherLock lock];
    [watchers setObject:queue forKey:uuid];
    [watcherLock unlock];
}

- (void)watcherRemove:(NSString *)uuid
{
    [watcherLock lock];
    [watchers removeObjectForKey:uuid];
    [watcherLock unlock];
}

- (void)startWatcher:(NSString *) walletUUID
{
    [self postToWatcherQueue: ^{
        if (![self watcherExists:walletUUID]) {
            tABC_Error Error;
            const char *szUUID = [walletUUID UTF8String];
            ABC_WatcherStart([self.name UTF8String],
                             [self.password UTF8String],
                             szUUID, &Error);
            
            NSOperationQueue *queue = [[NSOperationQueue alloc] init];
            [self watcherSet:walletUUID queue:queue];
            [queue addOperationWithBlock:^{
                [queue setName:walletUUID];
                tABC_Error Error;
                ABC_WatcherLoop([walletUUID UTF8String],
                                ABC_BitCoin_Event_Callback,
                                (__bridge void *) self,
                                &Error);
            }];
        }
    }];
}

- (void)stopWatchers
{
    NSArray *arrayIDs = [self listWalletIDs];
    // stop watchers
    [self postToWatcherQueue: ^{
        for (NSString *uuid in arrayIDs) {
            tABC_Error Error;
            ABC_WatcherStop([uuid UTF8String], &Error);
        }
        // wait for threads to finish
        for (NSString *uuid in arrayIDs) {
            NSOperationQueue *queue = [self watcherGet:uuid];
            if (queue == nil) {
                continue;
            }
            // Wait until operations complete
            [queue waitUntilAllOperationsAreFinished];
            // Remove the watcher from the dictionary
            [self watcherRemove:uuid];
        }
        // Destroy watchers
        for (NSString *uuid in arrayIDs) {
            tABC_Error Error;
            ABC_WatcherDelete([uuid UTF8String], &Error);
        }
    }];
    
    while ([watcherQueue operationCount]);
}

- (void)requestExchangeRateUpdate
{
    dispatch_async(dispatch_get_main_queue(),^
                   {
                       NSMutableArray *arrayCurrency = [[NSMutableArray alloc] init];
                       
                       for (ABCWallet *w in self.arrayWallets)
                       {
                           if (w.loaded) {
                               [arrayCurrency addObject:w.currency];
                           }
                       }
                       for (ABCWallet *w in self.arrayArchivedWallets)
                       {
                           if (w.loaded) {
                               [arrayCurrency addObject:w.currency];
                           }
                       }
                       [arrayCurrency addObject:self.settings.defaultCurrency];
                       
                       [exchangeQueue addOperationWithBlock:^{
                           [[NSThread currentThread] setName:@"Exchange Rate Update"];
                           NSMutableArray *exchanges = [NSMutableArray arrayWithObject:self.settings.exchangeRateSource];
                           [exchanges addObjectsFromArray:ABCArrayExchanges];
                           NSArray *arrayExchanges = [exchanges copy];
                           [self.exchangeCache requestExchangeUpdateBlocking:arrayExchanges
                                                               arrayCurrency:arrayCurrency];
                       }];
                   });
}

- (void)requestWalletDataSync:(ABCWallet *)wallet;
{
    [dataQueue addOperationWithBlock:^{
        tABC_Error error;
        bool bDirty = false;
        ABC_DataSyncWallet([self.name UTF8String],
                           [self.password UTF8String],
                           [wallet.uuid UTF8String],
                           &bDirty,
                           &error);
        dispatch_async(dispatch_get_main_queue(), ^ {
            if (bDirty) {
                [self notifyWalletSyncDelayed:wallet];
            }
        });
    }];
}

- (void)notifyWalletSync:(NSTimer *)timer;
{
    ABCWallet *wallet = [timer userInfo];
    if (self.delegate)
    {
        if ([self.delegate respondsToSelector:@selector(abcAccountWalletChanged:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wallet loadTransactions];
                [self.delegate abcAccountWalletChanged:wallet];
            });
        }
    }
}

- (void)notifyWalletSyncDelayed:(ABCWallet *)wallet;
{
    if (notificationTimer) {
        [notificationTimer invalidate];
    }
    
    notificationTimer = [NSTimer scheduledTimerWithTimeInterval:notifySyncDelay
                                                              target:self
                                                            selector:@selector(notifyWalletSync:)
                                                            userInfo:wallet
                                                             repeats:NO];
}

- (void)dataSyncAccount;
{
    [self postToDataQueue:^{
        [[NSThread currentThread] setName:@"Data Sync"];
        tABC_Error error;
        bool bDirty = false;
        bool bPasswordChanged = false;
        ABC_DataSyncAccount([self.name UTF8String],
                            [self.password UTF8String],
                            &bDirty,
                            &bPasswordChanged,
                            &error);
        NSError *nserror = [ABCError makeNSError:error];
        if (ABCConditionCodeInvalidOTP == nserror.code)
        {
            NSString *key = nil;
            NSError *error = nil;
            key = [self getOTPLocalKey:&error];
            if (key != nil && !error)
            {
                [self performSelectorOnMainThread:@selector(notifyOtpSkew:)
                                       withObject:nil
                                    waitUntilDone:NO];
            }
            else
            {
                [self performSelectorOnMainThread:@selector(notifyOtpRequired:)
                                       withObject:nil
                                    waitUntilDone:NO];
            }
        }
        else if (!nserror)
        {
            dispatch_async(dispatch_get_main_queue(), ^ {
                if (bDirty) {
                    [self notifyAccountSyncDelayed];
                }
                if (bPasswordChanged) {
                    if (self.delegate)
                    {
                        if ([self.delegate respondsToSelector:@selector(abcAccountRemotePasswordChange)])
                        {
                            [self.delegate abcAccountRemotePasswordChange];
                        }
                    }
                }
            });
        }
    }];

}


- (void)dataSyncAllWalletsAndAccount
{
    // Do not request a sync one is currently in progress
    if ([dataQueue operationCount] > 0) {
        return;
    }

    NSArray *arrayWallets;
    
    // Sync Wallets First
    arrayWallets = [NSArray arrayWithArray:self.arrayWallets];
    for (ABCWallet *wallet in arrayWallets)
    {
        [self requestWalletDataSync:wallet];
    }
    
    // Sync Account second
    [self dataSyncAccount];
    
    // Fetch general info last
    [dataQueue addOperationWithBlock:^{
        tABC_Error error;
        ABC_GeneralInfoUpdate(&error);
    }];
    
    [self postToDataQueue:^{
        dispatch_async(dispatch_get_main_queue(),^{
            
            // First off another data sync in a few seconds after this one completes
            if (dataSyncTimer)
                [dataSyncTimer invalidate];
            
            dataSyncTimer = [NSTimer scheduledTimerWithTimeInterval:fileSyncFrequencySeconds
                                                             target:self
                                                           selector:@selector(dataSyncAllWalletsAndAccount)
                                                           userInfo:nil
                                                            repeats:YES];
        });
    }];
}

- (NSError *)setDefaultCurrency:(NSString *)currencyCode;
{
    NSError *error = [self.settings loadSettings];
    if (!error)
    {
        self.settings.defaultCurrency = [self.exchangeCache getCurrencyFromCode:currencyCode];
        error = [self.settings saveSettings];
    }
    return error;
}

- (NSError *)createFirstWalletIfNeeded;
{
    NSError *error = nil;
    NSArray *arrayIDs = [self listWalletIDs];
    
    if ([arrayIDs count] == 0)
    {
        // create first wallet if it doesn't already exist
        ABCLog(1, @"Creating first wallet in account");
        [self createWallet:nil currency:nil error:&error];
    }
    return error;
}




#pragma mark - ABC Callbacks

- (void)notifyOtpRequired:(NSArray *)params
{
    if (self.delegate)
    {
        if ([self.delegate respondsToSelector:@selector(abcAccountOTPRequired)])
        {
            [self.delegate abcAccountOTPRequired];
        }
    }
}

- (void)notifyOtpSkew:(NSArray *)params
{
    if (self.delegate)
    {
        if ([self.delegate respondsToSelector:@selector(abcAccountOTPSkew)])
        {
            [self.delegate abcAccountOTPSkew];
        }
    }
}

- (void)notifyAccountSync
{
    int numWallets = self.numTotalWallets;
    
    [self refreshWallets:^ {
         
         if (self.delegate)
         {
             if ([self.delegate respondsToSelector:@selector(abcAccountAccountChanged)])
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [self.delegate abcAccountAccountChanged];
                 });
             }
         }
         // if there are new wallets, we need to start their watchers
         if (self.numTotalWallets > numWallets)
         {
             [self startWatchers];
         }
     }];
}

- (void)notifyAccountSyncDelayed;
{
    if (notificationTimer) {
        [notificationTimer invalidate];
    }
    
    if (! [self isLoggedIn])
        return;
    
    notificationTimer = [NSTimer scheduledTimerWithTimeInterval:notifySyncDelay
                                                         target:self
                                                       selector:@selector(notifyAccountSync)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (NSString *) bitidParseURI:(NSString *)uri;
{
    tABC_Error error;
    char *szURLDomain = NULL;
    NSString *urlDomain;
    
    ABC_BitidParseUri([self.name UTF8String], nil, [uri UTF8String], &szURLDomain, &error);
    
    if (error.code == ABC_CC_Ok && szURLDomain) {
        urlDomain = [NSString stringWithUTF8String:szURLDomain];
    }
    if (szURLDomain) {
        free(szURLDomain);
    }
    ABCLog(2,@("bitidParseURI domain: %@"), urlDomain);
    return urlDomain;
    
}

- (NSError *) bitidLogin:(NSString *)uri;
{
    tABC_Error error;
    
    ABC_BitidLogin([self.name UTF8String], nil, [uri UTF8String], &error);
    return [ABCError makeNSError:error];    
}

- (ABCBitIDSignature *)bitidSign:(NSString *)uri message:(NSString *)message
{
    tABC_Error error;
    char *szAddress = NULL;
    char *szSignature = NULL;
    ABCBitIDSignature *bitid = [[ABCBitIDSignature alloc] init];
    
    tABC_CC result = ABC_BitidSign(
                                   [self.name UTF8String], [self.password UTF8String],
                                   [uri UTF8String], [message UTF8String], &szAddress, &szSignature, &error);
    if (result == ABC_CC_Ok) {
        bitid.address = [NSString stringWithUTF8String:szAddress];
        bitid.signature = [NSString stringWithUTF8String:szSignature];
    }
    if (szAddress) {
        free(szAddress);
    }
    if (szSignature) {
        free(szSignature);
    }
    return bitid;
}

- (BOOL)accountExistsLocal:(NSString *)username;
{
    if (username == nil) {
        return NO;
    }
    tABC_Error error;
    bool result;
    ABC_AccountSyncExists([username UTF8String],
                          &result,
                          &error);
    return (BOOL)result;
}



void ABC_BitCoin_Event_Callback(const tABC_AsyncBitCoinInfo *pInfo)
{
    ABCAccount *user = (__bridge id) pInfo->pData;
    NSError *error = [ABCError makeNSError:pInfo->status];
    uint64_t amount = (uint64_t) pInfo->sweepSatoshi;
    
    NSString *walletUUID;
    NSString *txid;
    

    if (pInfo)
    {
        if (pInfo->szWalletUUID)
        {
            walletUUID = [NSString stringWithUTF8String:pInfo->szWalletUUID];
            
            if (pInfo->szTxID)
            {
                txid = [NSString stringWithUTF8String:pInfo->szTxID];
            }
        }
    }
    
    if (ABC_AsyncEventType_IncomingBitCoin == pInfo->eventType) {
        [user refreshWallets:^ {
             if (user.delegate) {
                 if ([user.delegate respondsToSelector:@selector(abcAccountIncomingBitcoin:transaction:)]) {
                     ABCWallet *wallet = nil;
                     ABCTransaction *tx = nil;
                     if (walletUUID)
                         wallet = [user getWallet:walletUUID];
                     if (txid)
                         tx = [wallet getTransaction:txid];
                     [user.delegate abcAccountIncomingBitcoin:wallet transaction:tx];
                 }
             }
         }];
    } else if (ABC_AsyncEventType_BlockHeightChange == pInfo->eventType) {
        ABCWallet *wallet = nil;
        if (walletUUID)
        {
            wallet = [user getWallet:walletUUID];
            if (wallet)
            {
                wallet.bBlockHeightChanged = YES;
                if (user.delegate) {
                    if ([user.delegate respondsToSelector:@selector(abcAccountBlockHeightChanged:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^(void) {
                            [user.delegate abcAccountBlockHeightChanged:wallet];
                        });
                    }
                }
            }
        }
        
    } else if (ABC_AsyncEventType_BalanceUpdate == pInfo->eventType) {
        [user refreshWallets:^
         {
             if (user.delegate) {
                 if ([user.delegate respondsToSelector:@selector(abcAccountBalanceUpdate:transaction:)]) {
                     ABCWallet *wallet = nil;
                     ABCTransaction *tx = nil;
                     if (walletUUID)
                         wallet = [user getWallet:walletUUID];
                     if (txid)
                         tx = [wallet getTransaction:txid];
                     [user.delegate abcAccountBalanceUpdate:wallet transaction:tx];
                 }
             }
         }];
    } else if (ABC_AsyncEventType_IncomingSweep == pInfo->eventType) {
        ABCWallet *wallet = nil;
        ABCTransaction *tx = nil;
        if (walletUUID)
            wallet = [user getWallet:walletUUID];
        if (txid)
            tx = [wallet getTransaction:txid];
        [wallet handleSweepCallback:tx amount:amount error:error];
        
    } else if (ABC_AsyncEventType_AddressCheckDone == pInfo->eventType) {
        [user refreshWallets:^{
            ABCWallet *wallet = nil;
            if (walletUUID)
                wallet = [user getWallet:walletUUID];
            [user postWalletsLoadedNotification:wallet];
        }];
        
    }
}



/////////////////////////////////////////////////////////////////
//////////////////// New ABCAccount methods ////////////////////
/////////////////////////////////////////////////////////////////

- (NSError *)changePIN:(NSString *)pin;
{
    tABC_Error error;
    if (!pin)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        return [ABCError makeNSError:error];
    }
    const char * passwd = [self.password length] > 0 ? [self.password UTF8String] : nil;
    
    ABC_PinSetup([self.name UTF8String],
                 passwd,
                 [pin UTF8String],
                 &error);
    return [ABCError makeNSError:error];
}

- (void)changePIN:(NSString *)pin
         complete:(void (^)(void)) completionHandler
            error:(void (^)(NSError *error)) errorHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = [self changePIN:pin];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!error)
            {
                if (completionHandler) completionHandler();
            }
            else
            {
                if (errorHandler) errorHandler(error);
            }
        });
    });
}

- (ABCWallet *) createWallet:(NSString *)walletName currency:(NSString *)currency;
{
    return [self createWallet:walletName currency:currency error:nil];
}

- (ABCWallet *) createWallet:(NSString *)walletName currency:(NSString *)currencyCode error:(NSError **)nserror;
{
    NSError *lnserror;
    [self clearDataQueue];
    ABCCurrency *currency;
    ABCWallet *wallet = nil;
    
    if (nil == currencyCode)
    {
        if (self.settings)
        {
            currency = self.settings.defaultCurrency;
        }
        if (!currency)
        {
            currency = [ABCCurrency defaultCurrency];
        }
    }
    else
    {
        currency = [self.exchangeCache getCurrencyFromCode:currencyCode];
    }
    
    NSString *defaultWallet = [NSString stringWithString:defaultWalletName];
    if (nil == walletName || [walletName length] == 0)
    {
        walletName = defaultWallet;
    }
    
    tABC_Error error;
    char *szUUID = NULL;
    ABC_CreateWallet([self.name UTF8String],
                     [self.password UTF8String],
                     [walletName UTF8String],
                     currency.currencyNum,
                     &szUUID,
                     &error);
    lnserror = [ABCError makeNSError:error];
    
    if (!lnserror)
    {
        [self startAllWallets];
        [self connectWatchers];
        [self refreshWallets];
        
        wallet = [self getWallet:[NSString stringWithUTF8String:szUUID]];
    }
    
    if (nserror)
        *nserror = lnserror;
    return wallet;
}

- (void) createWallet:(NSString *)walletName currency:(NSString *)currency
             complete:(void (^)(ABCWallet *)) completionHandler
                error:(void (^)(NSError *)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        ABCWallet *wallet = [self createWallet:walletName currency:currency error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!error)
            {
                if (completionHandler) completionHandler(wallet);
            }
            else
            {
                if (errorHandler) errorHandler(error);
            }
        });
    });
}

- (NSError *)changePassword:(NSString *)password;
{
    NSError *nserror = nil;
    tABC_Error error;
    
    if (!password)
    {
        error.code = ABC_CC_BadPassword;
        return [ABCError makeNSError:error];
    }
    
    ABC_ChangePassword([self.name UTF8String], [@"ignore" UTF8String], [password UTF8String], &error);
    nserror = [ABCError makeNSError:error];
    
    if (!nserror)
    {
        self.password = password;
        [self setupLoginPIN];
        
        if ([self.abc.localSettings.touchIDUsersEnabled containsObject:self.name] ||
            !self.settings.bDisablePINLogin)
        {
            [self.abc.localSettings.touchIDUsersDisabled removeObject:self.name];
            [self.abc.localSettings saveAll];
            [self.abc.keyChain updateLoginKeychainInfo:self.name
                                          password:self.password
                                        useTouchID:YES];
        }
    }
    
    return nserror;
}

- (void)changePassword:(NSString *)password
                   complete:(void (^)(void)) completionHandler
                      error:(void (^)(NSError *)) errorHandler;
{
    [self postToDataQueue:^(void)
     {
         NSError *error = [self changePassword:password];
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

- (BOOL) hasPINLogin;
{
    return !self.settings.bDisablePINLogin;
}

- (NSError *) pinLoginSetup:(BOOL)enable;
{
    self.settings.bDisablePINLogin = !enable;
    return [self.settings saveSettings];
}

#pragma mark - OTP Authentication

- (NSError *)setOTPKey:(NSString *)key;
{
    return [self.abc setOTPKey:self.name key:key];
}

- (NSString *)getOTPLocalKey:(NSError **)nserror;
{
    tABC_Error error;
    char *szSecret = NULL;
    NSString *key = nil;
    NSError *nserror2 = nil;

    ABC_OtpKeyGet([self.name UTF8String], &szSecret, &error);
    nserror2 = [ABCError makeNSError:error];
    if (!nserror2 && szSecret) {
        key = [NSString stringWithUTF8String:szSecret];
    }
    if (szSecret) {
        free(szSecret);
    }
    if (nserror) *nserror = nserror2;
    ABCLog(2,@("SECRET: %@"), key);
    return key;
}

- (NSError *)removeOTPKey;
{
    tABC_Error error;
    ABC_OtpKeyRemove([self.name UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (NSError *)getOTPDetails:(bool *)enabled
                   timeout:(long *)timeout;
{
    tABC_Error error;
    ABC_OtpAuthGet([self.name UTF8String], [self.password UTF8String], enabled, timeout, &error);
    return [ABCError makeNSError:error];
}

- (NSError *)enableOTP:(long)timeout;
{
    tABC_Error error;
    ABC_OtpAuthSet([self.name UTF8String], [self.password UTF8String], timeout, &error);
    return [ABCError makeNSError:error];
}

- (NSError *)disableOTP;
{
    tABC_Error error;
    ABC_OtpAuthRemove([self.name UTF8String], [self.password UTF8String], &error);
    NSError *nserror = [ABCError makeNSError:error];
    NSError *nserror2 = [self removeOTPKey];
    
    if (nserror)
        return nserror;
    return nserror2;
}

- (NSError *)cancelOTPResetRequest;
{
    tABC_Error error;
    ABC_OtpResetRemove([self.name UTF8String], [self.password UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (int) getNumWalletsInAccount:(NSError **)nserror;
{
    tABC_Error error;
    char **aUUIDS = NULL;
    NSError *nserror2 = nil;
    unsigned int nCount = 0;
    
    ABC_GetWalletUUIDs([self.name UTF8String],
                       [self.password UTF8String],
                       &aUUIDS, &nCount, &error);
    nserror2 = [ABCError makeNSError:error];
    
    if (!nserror2)
    {
        if (aUUIDS)
        {
            unsigned int i;
            for (i = 0; i < nCount; ++i)
            {
                char *szUUID = aUUIDS[i];
                // If entry is NULL skip it
                if (!szUUID) {
                    continue;
                }
                free(szUUID);
            }
            free(aUUIDS);
        }
    }
    
    if (nserror)
        *nserror = nserror2;
    
    return nCount;
}

- (NSError *)setupRecoveryQuestions:(NSString *)questions
                            answers:(NSString *)answers;
{
    tABC_Error error;
    ABC_SetAccountRecoveryQuestions([self.name UTF8String],
                                    [self.password UTF8String],
                                    [questions UTF8String],
                                    [answers UTF8String],
                                    &error);
    return [ABCError makeNSError:error];
}

- (void)setupRecoveryQuestions:(NSString *)questions
                       answers:(NSString *)answers
                      complete:(void (^)(void)) completionHandler
                         error:(void (^)(NSError *error)) errorHandler;
{
    [self postToMiscQueue:^
     {
         NSError *error = [self setupRecoveryQuestions:questions answers:answers];
         
         dispatch_async(dispatch_get_main_queue(), ^(void) {
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

- (NSError *)clearBlockchainCache;
{
    [self stopWatchers];
    // stop watchers
    NSError *nserror = nil;
    NSError *retError = nil;
    for (ABCWallet *wallet in self.arrayWallets) {
        tABC_Error error;
        ABC_WatcherDeleteCache([wallet.uuid UTF8String], &error);
        nserror = [ABCError makeNSError:error];
        if (nserror) retError = nserror;
    }
    [self startWatchers];
    return retError;
}

- (void)clearBlockchainCache:(void (^)(void)) completionHandler
                                   error:(void (^)(NSError *error)) errorHandler
{
    [self postToWalletsQueue:^{
        NSError *error = [self clearBlockchainCache];
        dispatch_async(dispatch_get_main_queue(),^{
            if (!error) {
                if (completionHandler) completionHandler();
            } else {
                if (errorHandler) errorHandler(error);
            }
        });
    }];
}

- (BOOL) shouldAskUserToEnableTouchID;
{
    if ([self.abc hasDeviceCapability:ABCDeviceCapsTouchID] && [self.abc accountHasPassword:self.name error:nil])
    {
        //
        // Check if user has not yet been asked to enable touchID on this device
        //
        
        BOOL onEnabled = ([self.abc.localSettings.touchIDUsersEnabled indexOfObject:self.name] != NSNotFound);
        BOOL onDisabled = ([self.abc.localSettings.touchIDUsersDisabled indexOfObject:self.name] != NSNotFound);
        
        if (!onEnabled && !onDisabled)
        {
            return YES;
        }
        else
        {
            [self.abc.keyChain updateLoginKeychainInfo:self.name
                                          password:self.password
                                        useTouchID:!onDisabled];
        }
    }
    return NO;
}

- (BOOL) isLoggedIn
{
    return !(nil == self.name);
}

////////////////////////////////////////////////////////
#pragma mark - internal routines
////////////////////////////////////////////////////////

- (NSString *)formatUsername:(NSString *)username;
{
    username = [username stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    username = [username lowercaseString];
    
    return username;
}

- (void)setupLoginPIN;
{
    if (!self.settings.bDisablePINLogin)
    {
        if (self.settings.strPIN)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
                tABC_Error error;
                ABC_PinSetup([self.name UTF8String],
                             [self.password length] > 0 ? [self.password UTF8String] : nil,
                             [self.settings.strPIN UTF8String],
                             &error);
            });
        }
    }
}

@end

