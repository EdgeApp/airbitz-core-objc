
#import "AirbitzCore+Internal.h"
#import <pthread.h>

static const int   fileSyncFrequencySeconds   = 30;
static const float walletLoadingTimerInterval = 20.0;     // How long to wait between wallet updates on new device logins before we consider the account fully loaded
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
@property                       BOOL                bCoreSentAddressesLoaded;
@property                       BOOL                bNewDeviceLogin;

@end

@implementation ABCAccount

- (id)initWithCore:(AirbitzCore *)airbitzCore;
{
    
    if (NO == bInitialized)
    {
        if (!airbitzCore) return nil;
        
        self.abc = airbitzCore;
        self.exchangeCache = [self.abc exchangeCacheGet];
        
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
        self.bCoreSentAddressesLoaded = NO;
        
        [self cleanWallets];
        
        self.numCategories = 0;
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
    [strSeed appendString:[[UIDevice currentDevice] name]];
    
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
        self.arrayCategories = nil;
        self.numCategories = 0;
        [self cleanWallets];
        self.settings = nil;
    }
}

- (void)startQueues
{
    if ([self isLoggedIn])
    {
        // Initialize the exchange rates queue
        exchangeTimer = [NSTimer scheduledTimerWithTimeInterval:ABC_EXCHANGE_RATE_REFRESH_INTERVAL_SECONDS
                                                         target:self
                                                       selector:@selector(requestExchangeRateUpdate:)
                                                       userInfo:nil
                                                        repeats:YES];
        // Request one right now
        [self requestExchangeRateUpdate:nil];
        
        // Initialize data sync queue
        dataSyncTimer = [NSTimer scheduledTimerWithTimeInterval:fileSyncFrequencySeconds
                                                         target:self
                                                       selector:@selector(dataSyncAllWalletsAndAccount:)
                                                       userInfo:nil
                                                        repeats:YES];
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

- (void)loadWalletUUIDs:(NSMutableArray *)arrayUUIDs
{
    tABC_Error Error;
    char **aUUIDS = NULL;
    unsigned int nCount;
    
    tABC_CC result = ABC_GetWalletUUIDs([self.name UTF8String],
                                        [self.password UTF8String],
                                        &aUUIDS, &nCount, &Error);
    if (ABC_CC_Ok == result)
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
}

- (void)loadWallets:(NSMutableArray *)arrayWallets withTxs:(BOOL)bWithTx
{
    ABCLog(2,@"ENTER loadWallets: %@", [NSThread currentThread].name);
    
    NSMutableArray *arrayUuids = [[NSMutableArray alloc] init];
    [self loadWalletUUIDs:arrayUuids];
    ABCWallet *wallet;
    for (NSString *uuid in arrayUuids) {
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

- (void)makeCurrentWalletWithIndex:(NSIndexPath *)indexPath
{
    //
    // Set new wallet. Hide the dropdown. Then reload the TransactionsView table
    //
    if(indexPath.section == 0)
    {
        if ([self.arrayWallets count] > indexPath.row)
        {
            self.currentWallet = [self.arrayWallets objectAtIndex:indexPath.row];
            
        }
    }
    else
    {
        if ([self.arrayArchivedWallets count] > indexPath.row)
        {
            self.currentWallet = [self.arrayArchivedWallets objectAtIndex:indexPath.row];
        }
    }
    
    [self postNotificationWalletsChanged];
    
}

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

//
// Will send a notification if at least the primary wallet is loaded
// In the case of a new device login, this will post a notification ONLY if all wallets are loaded
// AND no updates have come in from the core in walletLoadingTimerInterval of time. (about 10 seconds).
// This is a guesstimate of how long to wait before assuming a new device is synced on initial login.
//
- (void)checkWalletsLoadingNotification
{
    if (self.bNewDeviceLogin)
    {
        if (self.bCoreSentAddressesLoaded)
        {
            [self postWalletsLoadedNotification];
        }
    }
    else
    {
        ABCLog(1, @"************ numWalletsLoaded=%d", self.numWalletsLoaded);
        if (!self.arrayWallets || self.numWalletsLoaded == 0)
            [self postWalletsLoadingNotification];
        else
            [self postWalletsLoadedNotification];
        
    }
}

- (void)postWalletsLoadingNotification
{
    ABCLog(1, @"postWalletsLoading numWalletsLoaded=%d", self.numWalletsLoaded);
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(abcAccountWalletsLoading)]) {
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate abcAccountWalletsLoading];
            });
        }
    }
}

- (void)postWalletsLoadedNotification
{
    self.bNewDeviceLogin = NO;
    if (self.delegate && !bHasSentWalletsLoaded) {
        bHasSentWalletsLoaded = YES;
        if ([self.delegate respondsToSelector:@selector(abcAccountWalletsLoaded)]) {
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate abcAccountWalletsLoaded];
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

#define ABC_PIN_REQUIRED_PERIOD_SECONDS     120

- (BOOL)recentlyLoggedIn
{
    long now = (long) [[NSDate date] timeIntervalSince1970];
    return now - iLoginTimeSeconds <= ABC_PIN_REQUIRED_PERIOD_SECONDS;
}

- (void)login
{
    dispatch_async(dispatch_get_main_queue(),^{
        [self postWalletsLoadingNotification];
    });
    [self.abc setLastAccessedAccount:self.name];
    [self loadCategories];
    [self.settings loadSettings];
    [self requestExchangeRateUpdate:nil];
    
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
         [self dataSyncAllWalletsAndAccount:nil];
         
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
         [self loadCategories];
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
    NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
    [self loadWalletUUIDs: arrayWallets];
    for (NSString *uuid in arrayWallets) {
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

- (void)restoreConnectivity
{
    [self connectWatchers];
    [self startQueues];
}

- (void)lostConnectivity
{
}

- (void)logout;
{
    [self stopAsyncTasks];
    
    self.password = nil;
    self.name = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       if (self.delegate) {
                           if ([self.delegate respondsToSelector:@selector(abcAccountLoggedOut:)]) {
                               [self.delegate abcAccountLoggedOut:self];
                           }
                       }
                   });
}

- (BOOL)passwordOk:(NSString *)password
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

- (BOOL)passwordExists { return [self passwordExists:nil]; }
- (BOOL)passwordExists:(NSError **)error;
{
    return [self.abc passwordExists:self.name error:error];
}

- (void)startWatchers
{
    NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
    [self loadWalletUUIDs: arrayWallets];
    for (NSString *uuid in arrayWallets) {
        [self startWatcher:uuid];
    }
    [self connectWatchers];
}

- (void)connectWatchers
{
    if ([self isLoggedIn]) {
        NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
        [self loadWalletUUIDs:arrayWallets];
        for (NSString *uuid in arrayWallets)
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
            
            [self watchAddresses:uuid];
        }
    }];
}

- (void)disconnectWatchers
{
    if ([self isLoggedIn])
    {
        NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
        [self loadWalletUUIDs: arrayWallets];
        for (NSString *uuid in arrayWallets) {
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
            
            [self watchAddresses:walletUUID];
        }
    }];
}

- (void)stopWatchers
{
    NSMutableArray *arrayWallets = [[NSMutableArray alloc] init];
    [self loadWalletUUIDs: arrayWallets];
    // stop watchers
    [self postToWatcherQueue: ^{
        for (NSString *uuid in arrayWallets) {
            tABC_Error Error;
            ABC_WatcherStop([uuid UTF8String], &Error);
        }
        // wait for threads to finish
        for (NSString *uuid in arrayWallets) {
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
        for (NSString *uuid in arrayWallets) {
            tABC_Error Error;
            ABC_WatcherDelete([uuid UTF8String], &Error);
        }
    }];
    
    while ([watcherQueue operationCount]);
}

- (void)watchAddresses: (NSString *) walletUUID
{
    tABC_Error Error;
    ABC_WatchAddresses([self.name UTF8String],
                       [self.password UTF8String],
                       [walletUUID UTF8String], &Error);
}

- (void)requestExchangeRateUpdate:(NSTimer *)object
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



- (void)dataSyncAllWalletsAndAccount:(NSTimer *)object
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
    [dataQueue addOperationWithBlock:^{
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
    
    // Fetch general info last
    [dataQueue addOperationWithBlock:^{
        tABC_Error error;
        ABC_GeneralInfoUpdate(&error);
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
    NSMutableArray *wallets = [[NSMutableArray alloc] init];
    [self loadWalletUUIDs:wallets];
    
    if ([wallets count] == 0)
    {
        // create first wallet if it doesn't already exist
        ABCLog(1, @"Creating first wallet in account");
        [self createWallet:nil currency:nil error:&error];
    }
    return error;
}




- (NSError *)addCategory:(NSString *)strCategory;
{
    NSError *nserror = nil;
    // check and see that it doesn't already exist
    if ([self.arrayCategories indexOfObject:strCategory] == NSNotFound)
    {
        // add the category to the core
        tABC_Error error;
        ABC_AddCategory([self.name UTF8String],
                        [self.password UTF8String],
                        (char *)[strCategory UTF8String], &error);
        nserror = [ABCError makeNSError:error];
    }
    [self loadCategories];
    return nserror;
}

- (void) loadCategories;
{
    //    if (nil == self.arrayCategories || !self.numCategories)
    {
        [dataQueue addOperationWithBlock:^{
            char            **aszCategories = NULL;
            unsigned int    countCategories = 0;
            NSMutableArray *mutableArrayCategories = [[NSMutableArray alloc] init];
            
            // get the categories from the core
            tABC_Error error;
            ABC_GetCategories([self.name UTF8String],
                              [self.password UTF8String],
                              &aszCategories,
                              &countCategories,
                              &error);
            
            // If we've never added any categories, add them now
            if (countCategories == 0)
            {
                NSMutableArray *arrayCategories = [[NSMutableArray alloc] init];
                //
                // Expense categories
                //
                [arrayCategories addObject:NSLocalizedString(@"Expense:Air Travel", @"default category Expense:Air Travel")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Alcohol & Bars", @"default category Expense:Alcohol & Bars")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Allowance", @"default category Expense:Allowance")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Amusement", @"default category Expense:Amusement")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Arts", @"default category Expense:Arts")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:ATM Fee", @"default category Expense:ATM Fee")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Auto & Transport", @"default category Expense:Auto & Transport")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Auto Insurance", @"default category Expense:Auto Insurance")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Auto Payment", @"default category Expense:Auto Payment")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Baby Supplies", @"default category Expense:Baby Supplies")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Babysitter & Daycare", @"default category Expense:Babysitter & Daycare")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Bank Fee", @"default category Expense:Bank Fee")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Bills & Utilities", @"default category Expense:Bills & Utilities")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Books", @"default category Expense:Books")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Books & Supplies", @"default category Expense:Books & Supplies")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Car Wash", @"default category Expense:Car Wash")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Cash & ATM", @"default category Expense:Cash & ATM")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Charity", @"default category Expense:Charity")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Clothing", @"default category Expense:Clothing")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Coffee Shops", @"default category Expense:Coffee Shops")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Credit Card Payment", @"default category Expense:Credit Card Payment")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Dentist", @"default category Expense:Dentist")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Deposit to Savings", @"default category Expense:Deposit to Savings")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Doctor", @"default category Expense:Doctor")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Education", @"default category Expense:Education")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Electronics & Software", @"default category Expense:Electronics & Software")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Entertainment", @"default category Expense:Entertainment")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Eyecare", @"default category Expense:Eyecare")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Fast Food", @"default category Expense:Fast Food")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Fees & Charges", @"default category Expense:Fees & Charges")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Financial", @"default category Expense:Financial")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Financial Advisor", @"default category Expense:Financial Advisor")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Food & Dining", @"default category Expense:Food & Dining")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Furnishings", @"default category Expense:Furnishings")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Gas & Fuel", @"default category Expense:Gas & Fuel")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Gift", @"default category Expense:Gift")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Gifts & Donations", @"default category Expense:Gifts & Donations")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Groceries", @"default category Expense:Groceries")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Gym", @"default category Expense:Gym")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Hair", @"default category Expense:Hair")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Health & Fitness", @"default category Expense:Health & Fitness")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:HOA Dues", @"default category Expense:HOA Dues")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Hobbies", @"default category Expense:Hobbies")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Home", @"default category Expense:Home")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Home Improvement", @"default category Expense:Home Improvement")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Home Insurance", @"default category Expense:Home Insurance")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Home Phone", @"default category Expense:Home Phone")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Home Services", @"default category Expense:Home Services")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Home Supplies", @"default category Expense:Home Supplies")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Hotel", @"default category Expense:Hotel")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Interest Exp", @"default category Expense:Interest Exp")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Internet", @"default category Expense:Internet")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:IRA Contribution", @"default category Expense:IRA Contribution")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Kids", @"default category Expense:Kids")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Kids Activities", @"default category Expense:Kids Activities")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Late Fee", @"default category Expense:Late Fee")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Laundry", @"default category Expense:Laundry")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Lawn & Garden", @"default category Expense:Lawn & Garden")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Life Insurance", @"default category Expense:Life Insurance")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Misc.", @"default category Expense:Misc.")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Mobile Phone", @"default category Expense:Mobile Phone")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Mortgage & Rent", @"default category Expense:Mortgage & Rent")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Mortgage Interest", @"default category Expense:Mortgage Interest")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Movies & DVDs", @"default category Expense:Movies & DVDs")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Music", @"default category Expense:Music")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Newspaper & Magazines", @"default category Expense:Newspaper & Magazines")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Not Sure", @"default category Expense:Not Sure")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Parking", @"default category Expense:Parking")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Personal Care", @"default category Expense:Personal Care")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Pet Food & Supplies", @"default category Expense:Pet Food & Supplies")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Pet Grooming", @"default category Expense:Pet Grooming")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Pets", @"default category Expense:Pets")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Pharmacy", @"default category Expense:Pharmacy")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Property", @"default category Expense:Property")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Public Transportation", @"default category Expense:Public Transportation")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Registration", @"default category Expense:Registration")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Rental Car & Taxi", @"default category Expense:Rental Car & Taxi")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Restaurants", @"default category Expense:Restaurants")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Service & Parts", @"default category Expense:Service & Parts")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Service Fee", @"default category Expense:Service Fee")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Shopping", @"default category Expense:Shopping")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Spa & Massage", @"default category Expense:Spa & Massage")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Sporting Goods", @"default category Expense:Sporting Goods")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Sports", @"default category Expense:Sports")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Student Loan", @"default category Expense:Student Loan")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Tax", @"default category Expense:Tax")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Television", @"default category Expense:Television")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Tolls", @"default category Expense:Tolls")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Toys", @"default category Expense:Toys")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Trade Commissions", @"default category Expense:Trade Commissions")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Travel", @"default category Expense:Travel")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Tuition", @"default category Expense:Tuition")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Utilities", @"default category Expense:Utilities")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Vacation", @"default category Expense:Vacation")];
                [arrayCategories addObject:NSLocalizedString(@"Expense:Vet", @"default category Expense:Vet")];
                
                //
                // Income categories
                //
                [arrayCategories addObject:NSLocalizedString(@"Income:Consulting Income", @"default category Income:Consulting Income")];
                [arrayCategories addObject:NSLocalizedString(@"Income:Div Income", @"default category Income:Div Income")];
                [arrayCategories addObject:NSLocalizedString(@"Income:Net Salary", @"default category Income:Net Salary")];
                [arrayCategories addObject:NSLocalizedString(@"Income:Other Income", @"default category Income:Other Income")];
                [arrayCategories addObject:NSLocalizedString(@"Income:Rent", @"default category Income:Rent")];
                [arrayCategories addObject:NSLocalizedString(@"Income:Sales", @"default category Income:Sales")];
                
                //
                // Exchange Categories
                //
                [arrayCategories addObject:NSLocalizedString(@"Exchange:Buy Bitcoin", @"default category Exchange:Buy Bitcoin")];
                [arrayCategories addObject:NSLocalizedString(@"Exchange:Sell Bitcoin", @"default category Exchange:Sell Bitcoin")];
                
                //
                // Transfer Categories
                //
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Bitcoin.de", @"default category Transfer:Bitcoin.de")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Bitfinex", @"default category Transfer:Bitfinex")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Bitstamp", @"default category Transfer:Bitstamp")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:BTC-e", @"default category Transfer:BTC-e")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:BTCChina", @"default category Transfer:BTCChina")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Bter", @"default category Transfer:Bter")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:CAVirtex", @"default category Transfer:CAVirtex")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Coinbase", @"default category Transfer:Coinbase")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:CoinMKT", @"default category Transfer:CoinMKT")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Huobi", @"default category Transfer:Huobi")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Kraken", @"default category Transfer:Kraken")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:MintPal", @"default category Transfer:MintPal")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:OKCoin", @"default category Transfer:OKCoin")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Vault of Satoshi", @"default category Transfer:Vault of Satoshi")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Airbitz", @"default category Transfer:Wallet:Airbitz")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Armory", @"default category Transfer:Wallet:Armory")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Bitcoin Core", @"default category Transfer:Wallet:Bitcoin Core")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Blockchain", @"default category Transfer:Wallet:Blockchain")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Electrum", @"default category Transfer:Wallet:Electrum")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Multibit", @"default category Transfer:Wallet:Multibit")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Mycelium", @"default category Transfer:Wallet:Mycelium")];
                [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Dark Wallet", @"default category Transfer:Wallet:Dark Wallet")];
                
                // add default categories to core
                for (int i = 0; i < [arrayCategories count]; i++)
                {
                    NSString *strCategory = [arrayCategories objectAtIndex:i];
                    [mutableArrayCategories addObject:strCategory];
                    
                    ABC_AddCategory([self.name UTF8String],
                                    [self.password UTF8String],
                                    (char *)[strCategory UTF8String], &error);
                }
            }
            else
            {
                // store them in our own array
                
                if (aszCategories && countCategories > 0)
                {
                    for (int i = 0; i < countCategories; i++)
                    {
                        [mutableArrayCategories addObject:[NSString stringWithUTF8String:aszCategories[i]]];
                    }
                }
                
            }
            
            // free the core categories
            if (aszCategories != NULL)
            {
                [ABCUtil freeStringArray:aszCategories count:countCategories];
            }
            
            NSArray *tempArray = [mutableArrayCategories sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // store the final as storted
                self.arrayCategories = tempArray;
                self.numCategories = countCategories;
            });
        }];
    }
}

// saves the categories to the core
- (NSError *)saveCategories:(NSMutableArray *)saveArrayCategories;
{
    tABC_Error error;
    NSError *nserror = nil;
    NSError *nserrorRet = nil;
    
    // got through the existing categories
    for (NSString *strCategory in self.arrayCategories)
    {
        // if this category is in our new list
        if ([saveArrayCategories containsObject:strCategory])
        {
            // remove it from our new list since it is already there
            [saveArrayCategories removeObject:strCategory];
        }
        else
        {
            // it doesn't exist in our new list so delete it from the core
            ABC_RemoveCategory([self.name UTF8String], [self.password UTF8String], (char *)[strCategory UTF8String], &error);
            nserror = [ABCError makeNSError:error];
        }
    }
    
    // add any categories from our new list that didn't exist in the core list
    for (NSString *strCategory in saveArrayCategories)
    {
        ABC_AddCategory([self.name UTF8String], [self.password UTF8String], (char *)[strCategory UTF8String], &error);
        nserror = [ABCError makeNSError:error];
    }
    [self loadCategories];
    return nserror;
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
    [self loadCategories];
    
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

- (BOOL) bitidLogin:(NSString *)uri;
{
    tABC_Error error;
    
    ABC_BitidLogin([self.name UTF8String], nil, [uri UTF8String], &error);
    
    if (error.code == ABC_CC_Ok)
        return YES;
    return NO;
}

- (BitidSignature *)bitidSign:(NSString *)uri msg:(NSString *)message
{
    tABC_Error error;
    char *szAddress = NULL;
    char *szSignature = NULL;
    BitidSignature *bitid = [[BitidSignature alloc] init];
    
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
    ABCWallet *wallet = nil;
    NSString *txid = nil;
    NSError *error = [ABCError makeNSError:pInfo->status];
    uint64_t amount = (uint64_t) pInfo->sweepSatoshi;

    if (pInfo)
    {
        if (pInfo->szWalletUUID)
            wallet = [user getWallet:[NSString stringWithUTF8String:pInfo->szWalletUUID]];
        if (pInfo->szTxID)
            txid = [NSString stringWithUTF8String:pInfo->szTxID];
    }
    
    if (ABC_AsyncEventType_IncomingBitCoin == pInfo->eventType) {
        if (!wallet || !txid) {
            ABCLog(1, @"EventCallback: NULL pointer from ABC");
        }
        [user refreshWallets:^
         {
             if (user.delegate) {
                 if ([user.delegate respondsToSelector:@selector(abcAccountIncomingBitcoin:txid:)]) {
                     [user.delegate abcAccountIncomingBitcoin:wallet txid:txid];
                 }
             }
         }];
    } else if (ABC_AsyncEventType_BlockHeightChange == pInfo->eventType) {
        [user refreshWallets:^
         {
             if (user.delegate) {
                 if ([user.delegate respondsToSelector:@selector(abcAccountBlockHeightChanged)]) {
                     [user.delegate abcAccountBlockHeightChanged];
                 }
             }
         }];
        
    } else if (ABC_AsyncEventType_BalanceUpdate == pInfo->eventType) {
        if (!wallet || !txid) {
            ABCLog(1, @"EventCallback: NULL pointer from ABC");
        }
        [user refreshWallets:^
         {
             if (user.delegate) {
                 if ([user.delegate respondsToSelector:@selector(abcAccountBalanceUpdate:txid:)]) {
                     [user.delegate abcAccountBalanceUpdate:wallet txid:txid];
                 }
             }
         }];
    } else if (ABC_AsyncEventType_IncomingSweep == pInfo->eventType) {
        if (!wallet || !txid) {
            ABCLog(1, @"EventCallback: NULL pointer from ABC");
        }
        [wallet handleSweepCallback:txid amount:amount error:error];
    } else if (ABC_AsyncEventType_AddressCheckDone == pInfo->eventType) {
        if (!wallet) {
            ABCLog(1, @"EventCallback: NULL pointer from ABC");
        }
        if (wallet == user.arrayWallets[0])
        {
            user.bCoreSentAddressesLoaded = YES;
            [user refreshWallets];
        }
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

/* === OTP authentication: === */


- (BOOL) hasOTPResetPending:(NSError **)nserror;
{
    char *szUsernames = NULL;
    NSString *usernames = nil;
    BOOL needsReset = NO;
    tABC_Error error;
    NSError *nserror2 = nil;
    
    ABC_OtpResetGet(&szUsernames, &error);
    nserror2 = [ABCError makeNSError:error];
    
    NSMutableArray *usernameArray = [[NSMutableArray alloc] init];
    if (!nserror2 && szUsernames)
    {
        usernames = [NSString stringWithUTF8String:szUsernames];
        usernames = [self formatUsername:usernames];
        usernameArray = [[NSMutableArray alloc] initWithArray:[usernames componentsSeparatedByString:@"\n"]];
        if ([usernameArray containsObject:[self formatUsername:self.name]])
            needsReset = YES;
    }
    if (szUsernames)
        free(szUsernames);
    
    if (nserror) *nserror = nserror2;
    return needsReset;
}

- (NSString *)getOTPLocalKey:(NSError **)nserror;
{
    tABC_Error error;
    char *szSecret = NULL;
    NSString *key = nil;
    NSError *nserror2 = nil;

    ABC_OtpKeyGet([self.name UTF8String], &szSecret, &error);
    nserror2 = [ABCError makeNSError:error];
    if (nserror2 && szSecret) {
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

- (NSError *)setOTPAuth:(long)timeout;
{
    tABC_Error error;
    ABC_OtpAuthSet([self.name UTF8String], [self.password UTF8String], timeout, &error);
    return [ABCError makeNSError:error];
}

- (NSError *)removeOTPAuth;
{
    tABC_Error error;
    ABC_OtpAuthRemove([self.name UTF8String], [self.password UTF8String], &error);
    NSError *nserror = [ABCError makeNSError:error];
    NSError *nserror2 = [self removeOTPKey];
    
    if (nserror)
        return nserror;
    return nserror2;
}

- (NSError *)removeOTPResetRequest;
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

- (NSError *)setRecoveryQuestions:(NSString *)password
                        questions:(NSString *)questions
                          answers:(NSString *)answers;
{
    tABC_Error error;
    ABC_SetAccountRecoveryQuestions([self.name UTF8String],
                                    [password UTF8String],
                                    [questions UTF8String],
                                    [answers UTF8String],
                                    &error);
    return [ABCError makeNSError:error];
}

- (void)setRecoveryQuestions:(NSString *)password
                               questions:(NSString *)questions
                                 answers:(NSString *)answers
                                complete:(void (^)(void)) completionHandler
                                   error:(void (^)(NSError *error)) errorHandler;
{
    [self postToMiscQueue:^
     {
         NSError *error = [self setRecoveryQuestions:password questions:questions answers:answers];
         
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

#pragma Data Methods

- (NSError *)accountDataGet:(NSString *)folder withKey:(NSString *)key data:(NSMutableString *)data;
{
    [data setString:@""];
    tABC_Error error;
    char *szData = NULL;
    ABC_PluginDataGet([self.name UTF8String],
                      [self.password UTF8String],
                      [folder UTF8String], [key UTF8String],
                      &szData, &error);
    NSError *nserror = [ABCError makeNSError:error];
    if (!nserror) {
        [data setString:[NSString stringWithUTF8String:szData]];
    }
    if (szData != NULL) {
        free(szData);
    }
    return nserror;
}

- (NSError *)accountDataSet:(NSString *)folder withKey:(NSString *)key withValue:(NSString *)value;
{
    tABC_Error error;
    ABC_PluginDataSet([self.name UTF8String],
                      [self.password UTF8String],
                      [folder UTF8String],
                      [key UTF8String],
                      [value UTF8String],
                      &error);
    return [ABCError makeNSError:error];
}

- (NSError *)accountDataRemove:(NSString *)folder withKey:(NSString *)key;
{
    tABC_Error error;
    ABC_PluginDataRemove([self.name UTF8String],
                         [self.password UTF8String],
                         [folder UTF8String], [key UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (NSError *)accountDataClear:(NSString *)folder;
{
    tABC_Error error;
    ABC_PluginDataClear([self.name UTF8String],
                        [self.password UTF8String],
                        [folder UTF8String], &error);
    return [ABCError makeNSError:error];
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
    if ([self.abc hasDeviceCapability:ABCDeviceCapsTouchID] && [self.abc passwordExists:self.name error:nil])
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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
            tABC_Error error;
            ABC_PinSetup([self.name UTF8String],
                         [self.password length] > 0 ? [self.password UTF8String] : nil,
                         [self.settings.strPIN UTF8String],
                         &error);
        });
    }
}

@end

