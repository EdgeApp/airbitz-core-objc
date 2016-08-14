
#import "ABCContext+Internal.h"
#import <pthread.h>

#define ABC_VERSION_STRING @"0.9.1"

@class ABCUtil;

@implementation ABCBitIDSignature
- (id)init
{
   self = [super init];
   return self;
}
@end

@implementation ABCPasswordRuleResult
- (id)init
{
    self = [super init];
    self.noUpperCase = YES;
    self.noLowerCase = YES;
    self.noNumber = YES;
    self.tooShort = YES;
    return self;
}
@end

@interface ABCContext ()
{
    ABCExchangeCache                                *_exchangeCache;
}


@property (atomic, strong) ABCError                 *abcError;
@property (atomic, strong) ABCLocalSettings         *localSettings;
@property (atomic, strong) ABCKeychain              *keyChain;
@property (atomic, strong) NSMutableArray           *loggedInUsers;
@property (atomic, strong) NSOperationQueue         *exchangeQueue;

@end

@implementation ABCContext

+ (ABCContext *)makeABCContext:(NSString *)abcAPIKey;
{
    return [ABCContext makeABCContext:abcAPIKey hbits:@""];
}

+ (ABCContext *)makeABCContext:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey;
{
    ABCContext *abcContext  = [ABCContext alloc];

    {
        abcContext.abcError = [[ABCError alloc] init];

        abcContext.exchangeQueue = [[NSOperationQueue alloc] init];
        [abcContext.exchangeQueue setMaxConcurrentOperationCount:1];

        abcContext.loggedInUsers = [[NSMutableArray alloc] init];

        tABC_Error Error;

        Error.code = ABC_CC_Ok;

        NSMutableData *seedData = [[NSMutableData alloc] init];
        [abcContext fillSeedData:seedData];

        NSString *ca_path = [[NSBundle mainBundle] pathForResource:@"ca-certificates" ofType:@"crt"];

#if TARGET_OS_IPHONE
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docs_dir = [paths objectAtIndex:0];
#else
        NSString *path = NSHomeDirectory();
        NSString *dir = [NSString stringWithString:@".airbitz"];
        NSString *docs_dir = [NSString stringWithFormat:@"%@/%@/", path, dir];
        BOOL isDir = FALSE;
        
        NSFileManager *fileManager= [NSFileManager defaultManager];
        if(![fileManager fileExistsAtPath:docs_dir isDirectory:&isDir])
            if(![fileManager createDirectoryAtPath:docs_dir withIntermediateDirectories:YES attributes:nil error:NULL])
                ABCLog(@"Error: Create folder failed %@", docs_dir);
#endif
        Error.code = ABC_CC_Ok;
        ABC_Initialize([docs_dir UTF8String],
                [ca_path UTF8String],
                [abcAPIKey UTF8String],
                [hbitsKey UTF8String],
                (unsigned char *)[seedData bytes],
                (unsigned int)[seedData length],
                &Error);
        if ([ABCError makeNSError:Error]) return nil;

        // Fetch general info as soon as possible
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            tABC_Error error;
            ABC_GeneralInfoUpdate(&error);
        });

        Error.code = ABC_CC_Ok;

        abcContext.localSettings = [[ABCLocalSettings alloc] init:self];
        abcContext.keyChain = [[ABCKeychain alloc] init:self];

        abcContext.keyChain.localSettings = abcContext.localSettings;
    }
    return abcContext;
}

- (void)free
{
    {
        if (self.exchangeQueue)
            [self.exchangeQueue cancelAllOperations];
        int wait = 0;
        int maxWait = 200; // ~10 seconds
        while ([self.exchangeQueue operationCount] > 0 && wait < maxWait) {
            [NSThread sleepForTimeInterval:.2];
            wait++;
        }
        self.exchangeQueue = nil;

        for (ABCAccount *user in self.loggedInUsers)
        {
            [user logoutAllowRelogin];
        }

        ABC_Terminate();
    }
}

- (void)setExchangeCache:(ABCExchangeCache *)exchangeCache;
{
    _exchangeCache = exchangeCache;
}

- (ABCExchangeCache *) exchangeCache;
{
    if (!_exchangeCache)
    {
        _exchangeCache = [[ABCExchangeCache alloc] init:self];
    }
    return _exchangeCache;
}


- (NSDate *)dateFromTimestamp:(int64_t) intDate;
{
    return [NSDate dateWithTimeIntervalSince1970: intDate];
}

// gets the recover questions for a given account
// nil is returned if there were no questions for this account
- (NSArray *)getRecoveryQuestionsForUserName:(NSString *)username
                                       error:(ABCError **)nserror
{
    NSMutableArray *arrayQuestions = nil;
    char *szQuestions = NULL;

    tABC_Error error;
    ABC_GetRecoveryQuestions([username UTF8String],
                                              &szQuestions,
                                              &error);
    ABCError *nserror2 = [ABCError makeNSError:error];
    if (!nserror2)
    {
        if (szQuestions && strlen(szQuestions))
        {
            // create an array of strings by pulling each question that is seperated by a newline
            arrayQuestions = [[NSMutableArray alloc] initWithArray:[[NSString stringWithUTF8String:szQuestions] componentsSeparatedByString: @"\n"]];
            // remove empties
            [arrayQuestions removeObject:@""];
        }
    }

    if (szQuestions)
    {
        free(szQuestions);
    }
    
    if (nserror)
        *nserror = nserror2;

    if (arrayQuestions)
    {
        return [NSArray arrayWithArray:arrayQuestions];
    }
    return nil;
}

- (void)autoReloginOrTouchIDIfPossibleMain:(NSString *)username
                                  complete:(void (^)(BOOL doRelogin, NSString *password, BOOL usedTouchID)) completionHandler;

{
    ABCLog(1, @"ENTER autoReloginOrTouchIDIfPossibleMain");
    BOOL usedTouchID = NO;
    NSString *password = nil;
    
    if (! [self.keyChain bHasSecureEnclave] )
    {
        ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain: No secure enclave");
        completionHandler(NO, password, usedTouchID);
        return;
    }
    
    ABCLog(1, @"Checking username=%@", username);
    
    
    //
    // If login expired, then disable relogin but continue validation of TouchID
    //
    if ([self didLoginExpire:username])
    {
        ABCLog(1, @"Login expired. Continuing with TouchID validation");
        [self.keyChain disableRelogin:username];
    }
    
    //
    // Look for cached username & password or PIN in the keychain. Use it if present
    //
    BOOL bReloginState = NO;
    
    
    NSString *strReloginKey  = [self.keyChain createKeyWithUsername:username key:RELOGIN_KEY];
    NSString *strUseTouchID  = [self.keyChain createKeyWithUsername:username key:USE_TOUCHID_KEY];
    NSString *strPasswordKey = [self.keyChain createKeyWithUsername:username key:PASSWORD_KEY];
    
    int64_t bReloginKey = [self.keyChain getKeychainInt:strReloginKey error:nil];
    int64_t bUseTouchID = [self.keyChain getKeychainInt:strUseTouchID error:nil];
    NSString *kcPassword = [self.keyChain getKeychainString:strPasswordKey error:nil];
    
    if (!bReloginKey && !bUseTouchID)
    {
        ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain No relogin or touchid settings in keychain");
        completionHandler(NO, password, usedTouchID);
        return;
    }
    
    if ([kcPassword length] >= 10)
    {
        bReloginState = YES;
    }
    
    if (bReloginState)
    {
        if (bUseTouchID && !bReloginKey)
        {
            NSString *prompt = [NSString stringWithFormat:@"%@ [%@]",abcStringTouchIDPromptText, username];
            
            ABCLog(1, @"Launching TouchID prompt");
            [self.keyChain authenticateTouchID:prompt fallbackString:abcStringUsePasswordText complete:^(BOOL didAuthenticate) {
                if (didAuthenticate) {
                    ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain TouchID authentication passed");
                    completionHandler(YES, kcPassword, YES);
                    return;
                }
                else
                {
                    ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain TouchID authentication failed");
                    completionHandler(NO, password, usedTouchID);
                    return;
                }
            }];
        }
        else
        {
            ABCLog(1, @"autoReloginOrTouchIDIfPossibleMain Failed to enter TouchID");
        }
        
        if (bReloginKey)
        {
            password = kcPassword;
            completionHandler(YES, password, usedTouchID);
            return;
        }
    }
    else
    {
        ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain reloginState DISABLED");
    }
    completionHandler(NO, password, usedTouchID);
}

- (ABCAccount *) getLoggedInUser:(NSString *)username;
{
    // Grab all logged in users
    for (ABCAccount *user in self.loggedInUsers)
    {
        if ([username isEqualToString:user.name])
            return user;
    }
    return nil;
}

- (BOOL)didLoginExpire:(NSString *)username;
{
    //
    // If app was killed then the static var logoutTimeStamp will be zero so we'll pull the cached value
    // from the iOS ABCKeychain. Also, on non A7 processors, we won't save anything in the keychain so we need
    // the static var to take care of cases where app is not killed.
    //
    long long logoutTimeStamp = [self.keyChain getKeychainInt:[self.keyChain createKeyWithUsername:username key:LOGOUT_TIME_KEY] error:nil];
    
    if (!logoutTimeStamp) return YES;
    
    long long currentTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    if (currentTimeStamp > logoutTimeStamp)
    {
        return YES;
    }
    
    return NO;
}



// This is a fallback for auto logout. It is better to have the background task
// or network fetch log the user out
- (void)checkLoginExpired
{
    BOOL bLoginExpired;
    
    NSString *username;

    // Grab all logged in users
    for (ABCAccount *user in self.loggedInUsers)
    {
        bLoginExpired = [user didLoginExpire];
        if (bLoginExpired)
            [self logout:user];
    }

    // Check the most recently logged in user.
    username = [self getLastAccessedAccount];
    
    bLoginExpired = [self didLoginExpire:username];
    
    if (bLoginExpired)
    {
        // App will not auto login but we will retain login credentials
        // inside iOS ABCKeychain so we can use TouchID
        [self.keyChain disableRelogin:username];
    }
}

- (void)setConnectivity:(BOOL)hasConnectivity
{
    for (ABCAccount *user in self.loggedInUsers)
    {
        [user setConnectivity:hasConnectivity];
    }
}

- (void)enterBackground
{
    for (ABCAccount *user in self.loggedInUsers)
    {
        [user enterBackground];
    }
}

- (void)enterForeground
{
    [self checkLoginExpired];
    
    for (ABCAccount *user in self.loggedInUsers)
    {
        [user enterForeground];
    }
}

- (bool)isTestNet
{
    bool result = false;
    tABC_Error Error;

    ABC_IsTestNet(&result, &Error);
    
    return result;
}

- (NSString *)getVersion;
{
//    NSString *version;
//    char *szVersion = NULL;
//    ABC_Version(&szVersion, NULL);
//    version = [NSString stringWithUTF8String:szVersion];
//    free(szVersion);
//    return version;
    return ABC_VERSION_STRING;
}

+ (NSString *)fixUsername:(NSString *)username
                    error:(ABCError **)nserror
{
    NSString *fixedUsername = nil;
    char *szFixedUsername = NULL;
    
    tABC_Error error;
    ABC_FixUsername(&szFixedUsername,
                    [username UTF8String],
                    &error);
    ABCError *nserror2 = [ABCError makeNSError:error];
    if (!nserror2)
    {
        fixedUsername = [NSString stringWithUTF8String:szFixedUsername];
    }
    
    if (szFixedUsername)
    {
        free(szFixedUsername);
    }
    
    if (nserror)
        *nserror = nserror2;
    
    return fixedUsername;
}


- (NSArray *) listUsernames:(ABCError **) abcerror;
{
    char * pszUserNames;
    NSArray *arrayAccounts = nil;
    ABCError *nserror = nil;
    tABC_Error error;
    ABC_ListAccounts(&pszUserNames, &error);
    nserror = [ABCError makeNSError:error];
    NSMutableArray *usernames = [[NSMutableArray alloc] init];

    if (!nserror)
    {
        [usernames removeAllObjects];
        NSString *str = [NSString stringWithCString:pszUserNames encoding:NSUTF8StringEncoding];
        arrayAccounts = [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for(NSString *str in arrayAccounts)
        {
            if(str && str.length!=0)
            {
                [usernames addObject:str];
            }
        }
    }
    if (abcerror)
        *abcerror = nserror;
    return [usernames copy];
}

- (BOOL)pinLoginEnabled:(NSString *)username; { return [self pinLoginEnabled:username error:nil]; }
- (BOOL)pinLoginEnabled:(NSString *)username error:(ABCError **)nserror;
{
    ABCError *lnserror;
    tABC_Error error;
    
    bool exists = NO;
    if (username && 0 < username.length)
    {
        ABC_PinLoginExists([username UTF8String], &exists, &error);
        lnserror = [ABCError makeNSError:error];
    }
    else
    {
        error.code = ABC_CC_NULLPtr;
        lnserror = [ABCError makeNSError:error];
    }
    
    if (nserror)
        *nserror = lnserror;
    return exists;
}

- (BOOL)accountExistsLocal:(NSString *)username;
{
    if (username == nil) {
        return NO;
    }
    NSString *fixedUsername = [ABCContext fixUsername:username error:nil];
    tABC_Error error;
    bool result;
    ABC_AccountSyncExists([fixedUsername UTF8String],
                          &result,
                          &error);
    return (BOOL)result;
}


- (ABCError *)uploadLogs:(NSString *)userText;
{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *versionbuild = [NSString stringWithFormat:@"%@ %@", version, build];

    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    ABC_Log([[NSString stringWithFormat:@"User Comment:%@", userText] UTF8String]);
    ABC_Log([[NSString stringWithFormat:@"Platform:%@", [ABCUtil platform]] UTF8String]);
    ABC_Log([[NSString stringWithFormat:@"Platform String:%@", [ABCUtil platformString]] UTF8String]);
    ABC_Log([[NSString stringWithFormat:@"OS Version:%d.%d.%d", (int)osVersion.majorVersion, (int)osVersion.minorVersion, (int)osVersion.patchVersion] UTF8String]);
    ABC_Log([[NSString stringWithFormat:@"Airbitz Version:%@", versionbuild] UTF8String]);

    tABC_Error error;
    ABC_UploadLogs(NULL, NULL, &error);

    return [ABCError makeNSError:error];
}

- (void)uploadLogs:(NSString *)userText
          complete:(void(^)(void))completionHandler
             error:(void (^)(ABCError *error)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {

        ABCError *error = [self uploadLogs:userText];
        
        dispatch_async(dispatch_get_main_queue(),^{
            if (!error) {
                if (completionHandler) completionHandler();
            } else {
                if (errorHandler) errorHandler(error);
            }
        });
    });
}

- (ABCError *)deleteLocalAccount:(NSString *)account;
{
    tABC_Error error;
    ABCError *nserror = nil;
    ABC_AccountDelete((const char*)[account UTF8String], &error);
    nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        if ([account isEqualToString:[self getLastAccessedAccount]])
        {
            // If we deleted the account we most recently logged into,
            // set the lastLoggedInAccount to the top most account in the list.
            NSArray *usernames = [self listUsernames:&nserror];
            if (!nserror && usernames && ([usernames count] > 0))
            {
                [self setLastAccessedAccount:usernames[0]];
            }
            else
            {
                [self setLastAccessedAccount:nil];
            }
        }
    }

    return nserror;
}

/////////////////////////////////////////////////////////////////
//////////////////// New ABCContext methods ////////////////////
/////////////////////////////////////////////////////////////////

#pragma mark - Account Management

- (ABCAccount *)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate error:(ABCError **)nserror;
{
    tABC_Error error;
    ABCError *lnserror = nil;
    ABCAccount *account = nil;
    
    const char *szPassword = [password length] == 0 ? NULL : [password UTF8String];
    ABC_CreateAccount([username UTF8String], szPassword, &error);
    lnserror = [ABCError makeNSError:error];
    if (! lnserror)
    {
        account = [[ABCAccount alloc] initWithCore:self];
        account.delegate = delegate;
        account.name = username;
        account.password = password;
        lnserror = [account changePIN:pin];

        if (!lnserror)
        {
            [self.loggedInUsers addObject:account];

            [self setLastAccessedAccount:username];
            // update user's default currency num to match their locale
            NSString *currencyCode = [ABCCurrency getCurrencyCodeOfLocale];
            [account.settings enableTouchID];
            [account setDefaultCurrency:currencyCode];
            [account login];
        }
    }
    
    if (nserror)
        *nserror = lnserror;
    return account;
}

- (void)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate
             callback:(void (^)(ABCError *, ABCAccount *account)) callback;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ABCError *error = nil;
        ABCAccount *account = [self createAccount:username password:password pin:pin delegate:delegate error:&error];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (callback) callback(error, account);
        });
    });
}

- (ABCAccount *)loginWithPassword:(NSString *)username
              password:(NSString *)password
              delegate:(id)delegate
                 error:(ABCError **)nserror;
{
    return [self loginWithPassword:username
               password:password
               delegate:delegate
                    otp:nil
                  error:nil];
}

- (ABCAccount *)loginWithPassword:(NSString *)username
              password:(NSString *)password
              delegate:(id)delegate
                   otp:(NSString *)otp
                 error:(ABCError **)nserror;
{
    
    ABCError *lnserror = nil;
    ABCAccount *account = nil;

    tABC_Error error;
    
    char *szResetToken = NULL;
    char *szResetDate = NULL;
    
    if (!username || !password)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        lnserror = [ABCError makeNSError:error];
    }
    else
    {
        if (otp)
        {
            lnserror = [self setupOTPKey:username key:otp];
        }
        
        if (!lnserror)
        {
            ABC_PasswordLogin([username UTF8String], [password UTF8String], &szResetToken, &szResetDate, &error);
            
            lnserror = [ABCError makeNSError:error];
            
            if (szResetToken)
            {
                lnserror.otpResetToken = [NSString stringWithUTF8String:szResetToken];
            }
            if (szResetDate)
            {
                NSString *dateStr = [NSString stringWithUTF8String:szResetDate];
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
                
                NSDate *dateTemp = [dateFormatter dateFromString:dateStr];
                lnserror.otpResetDate = dateTemp;
            }
            
            if (!lnserror)
            {
                account = [[ABCAccount alloc] initWithCore:self];
                account.delegate = delegate;
                [self.loggedInUsers addObject:account];
                account.name = username;
                account.password = password;
                [account login];
                [account setupLoginPIN];
            }
        }
    }
    
    if (szResetDate) free(szResetDate);
    if (szResetToken) free(szResetToken);
    if (nserror)
        *nserror = lnserror;
    return account;
}

- (void)loginWithPassword:(NSString *)username password:(NSString *)password
      delegate:(id)delegate otp:(NSString *)otp
      callback:(void (^)(ABCError *, ABCAccount *account))callback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ABCError *nserror = nil;
        ABCAccount *account = [self loginWithPassword:username
                                  password:password
                                  delegate:delegate
                                       otp:otp
                                     error:&nserror];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (callback) callback(nserror, account);
        });
    });
}

- (ABCAccount *)pinLogin:(NSString *)username
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(ABCError **)nserror;
{
    tABC_Error error;
    ABCError *lnserror;
    ABCAccount *account = nil;
    int pinLoginWaitSeconds = 0;
    
    if (!username || !pin)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        lnserror = [ABCError makeNSError:error];
    }
    else
    {
        if ([self pinLoginEnabled:username error:nil])
        {
            ABC_PinLogin([username UTF8String],
                         [pin UTF8String],
                         &pinLoginWaitSeconds,
                         &error);
            lnserror = [ABCError makeNSError:error];
            
            if (!lnserror)
            {
                account = [[ABCAccount alloc] initWithCore:self];
                account.delegate = delegate;
                [self.loggedInUsers addObject:account];
                account.name = username;
                [account login];
            }
        }
        else
        {
            error.code = (tABC_CC) ABCConditionCodeError;
            lnserror = [ABCError makeNSError:error];
        }
        
    }
    
    if (nserror)
        *nserror = lnserror;
    return account;
    
}

- (void)pinLogin:(NSString *)username pin:(NSString *)pin delegate:(id)delegate
             complete:(void (^)(ABCAccount *user)) completionHandler
                error:(void (^)(ABCError *)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ABCError *error;
        ABCAccount *account = [self pinLogin:username pin:pin delegate:delegate error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (account)
            {
                if (completionHandler) completionHandler(account);
            }
            else
            {
                if (errorHandler) errorHandler(error);
            }
        });
    });
}

- (void)recoveryLogin:(NSString *)username
                          answers:(NSString *)answers
                         delegate:(id)delegate
                              otp:(NSString *)otp
                         complete:(void (^)(ABCAccount *account)) completionHandler
                            error:(void (^)(ABCError *, NSDate *resetDate, NSString *resetToken)) errorHandler;
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        tABC_Error error;
        ABCError *nserror;
        NSDate *resetDate;
        NSString *resetToken;
        ABCAccount *account = nil;
        char *szResetToken = NULL;
        char *szResetDate = NULL;
        
        if (!username || !answers)
        {
            error.code = (tABC_CC) ABCConditionCodeNULLPtr;
            nserror = [ABCError makeNSError:error];
        }
        else
        {
            if (otp)
            {
                nserror = [self setupOTPKey:username key:otp];
            }
            
            // This actually logs in the user
            ABC_RecoveryLogin([username UTF8String], [answers UTF8String], &szResetToken, &szResetDate, &error);
            
            nserror = [ABCError makeNSError:error];
            
            if (!nserror)
            {
                account = [[ABCAccount alloc] initWithCore:self];
                account.delegate = delegate;
                [self.loggedInUsers addObject:account];
                account.name = username;
                account.password = nil;
                [account login];
                [account setupLoginPIN];
            }
            if (szResetToken)
            {
                resetToken = [NSString stringWithUTF8String:szResetToken];
            }
            if (szResetDate)
            {
                NSString *dateStr = [NSString stringWithUTF8String:szResetDate];
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
                
                NSDate *dateTemp = [dateFormatter dateFromString:dateStr];
                resetDate = dateTemp;
            }
        }
        
        if (szResetDate) free(szResetDate);
        if (szResetToken) free(szResetToken);

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!nserror)
            {
                if (completionHandler) completionHandler(account);
            }
            else
            {
                if (errorHandler) errorHandler(nserror, resetDate, resetToken);
            }
        });
    });
}



- (void)logout:(ABCAccount *)user;
{
    [self.keyChain disableRelogin:user.name];
    [user logout];
    [self.loggedInUsers removeObject:user];
    
    //
    // XXX Hack. Right now ABC only holds one logged in user using a key cache.
    // This should change and allow us to have multiple concurrent logged in
    // users.
    //
    tABC_Error Error;
    ABC_ClearKeyCache(&Error);
}

+ (ABCPasswordRuleResult *)checkPasswordRules:(NSString *)password;
{
    ABCPasswordRuleResult *result;
    tABC_Error error;
    tABC_PasswordRule **aRules = NULL;
    unsigned int count;
    double secondsToCrack;
    
    ABC_CheckPassword([password UTF8String],
                      &secondsToCrack,
                      &aRules,
                      &count,
                      &error);
    ABCError *nserror = [ABCError makeNSError:error];

    if (!nserror)
    {
        result = [[ABCPasswordRuleResult alloc] init];
        result.secondsToCrack = secondsToCrack;
        
        for (int i = 0; i < count; i++)
        {
            tABC_PasswordRule *pRule = aRules[i];
            NSString *desc = [NSString stringWithUTF8String:pRule->szDescription];
            
            if ([desc containsString:@"upper case"])
            {
                if (pRule->bPassed) result.noUpperCase = NO;
            }
            else if ([desc containsString:@"lower case"])
            {
                if (pRule->bPassed) result.noLowerCase = NO;
            }
            else if ([desc containsString:@"one number"])
            {
                if (pRule->bPassed) result.noNumber = NO;
            }
            else if ([desc containsString:@"characters"])
            {
                if (pRule->bPassed) result.tooShort = NO;
            }
            
        }
    }
    
    ABC_FreePasswordRuleArray(aRules, count);

    if (result.noUpperCase || result.noNumber || result.noLowerCase || result.tooShort)
    {
        result.passed = NO;
    }
    else
    {
        result.passed = YES;
    }
    return result;
}

- (ABCError *)usernameAvailable:(NSString *)username;
{
    tABC_Error error;
    ABC_AccountAvailable([username UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (void)autoReloginOrTouchIDIfPossible:(NSString *)username
                              delegate:(id)delegate
                         doBeforeLogin:(void (^)(void)) doBeforeLogin
                   completionWithLogin:(void (^)(ABCAccount *account, BOOL usedTouchID)) completionWithLogin
                     completionNoLogin:(void (^)(void)) completionNoLogin
                                 error:(void (^)(ABCError *error)) errorHandler;
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [self autoReloginOrTouchIDIfPossibleMain:username complete:^(BOOL doRelogin, NSString *password, BOOL usedTouchID) {
            if (doRelogin)
            {
                if (doBeforeLogin) doBeforeLogin();
                [self loginWithPassword:username password:password delegate:delegate otp:nil callback:^(ABCError *error, ABCAccount *account) {
                    if (error)
                    {
                        if (errorHandler) errorHandler(error);
                    }
                    else
                    {
                        if (completionWithLogin) completionWithLogin(account, usedTouchID);
                    }
                }];
            }
            else
            {
                if (completionNoLogin) completionNoLogin();
            }
        }];
    });
}

///////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Cleaned up methods above /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////

- (NSString *) getLastAccessedAccount;
{
    return self.localSettings.lastLoggedInAccount;
}

- (void) setLastAccessedAccount:(NSString *) account;
{
    self.localSettings.lastLoggedInAccount = account;
    [self.localSettings saveAll];
}

/* === OTP authentication: === */

- (BOOL) hasOTPResetPending:(NSString *)username error:(ABCError **)nserror;
{
    char *szUsernames = NULL;
    NSString *usernames = nil;
    BOOL needsReset = NO;
    tABC_Error error;
    ABCError *nserror2 = nil;

    ABC_OtpResetGet(&szUsernames, &error);
    nserror2 = [ABCError makeNSError:error];

    NSMutableArray *usernameArray = [[NSMutableArray alloc] init];
    if (!nserror2 && szUsernames)
    {
        usernames = [NSString stringWithUTF8String:szUsernames];
        usernames = [self formatUsername:usernames];
        usernameArray = [[NSMutableArray alloc] initWithArray:[usernames componentsSeparatedByString:@"\n"]];
        if ([usernameArray containsObject:[self formatUsername:username]])
            needsReset = YES;
    }
    if (szUsernames)
        free(szUsernames);

    if (nserror) *nserror = nserror2;
    return needsReset;
}



- (NSArray *)listPendingOTPResetUsernames:(ABCError **)nserror;
{
    char *szUsernames = NULL;
    NSString *usernames = nil;
    NSArray *usernameArray = nil;
    tABC_Error error;
    ABCError *nserror2 = nil;
    ABC_OtpResetGet(&szUsernames, &error);
    nserror2 = [ABCError makeNSError:error];
    if (!nserror2)
    {
        usernames = [NSString stringWithUTF8String:szUsernames];
        usernames = [usernames stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        usernames = [self formatUsername:usernames];
        usernameArray = [[NSArray alloc] initWithArray:[usernames componentsSeparatedByString:@"\n"]];
    }
    if (szUsernames)
        free(szUsernames);
    if (nserror)
        *nserror = nserror2;
    return usernameArray;
}

- (ABCError *)setupOTPKey:(NSString *)username
                      key:(NSString *)key;
{
    tABC_Error error;
    ABC_OtpKeySet([username UTF8String], (char *)[key UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (ABCError *)requestOTPReset:(NSString *)username token:(NSString *)token;
{
    tABC_Error error;
    ABC_OtpResetSet([username UTF8String], [token UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (void)requestOTPReset:(NSString *)username
                  token:(NSString *)token
               callback:(void (^)(ABCError *error)) callback;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        ABCError *error = [self requestOTPReset:username token:token];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (callback) callback(error);
        });
    });
}

+ (void)listRecoveryQuestionChoices: (void (^)(
                                               NSMutableArray *arrayCategoryString,
                                               NSMutableArray *arrayCategoryNumeric,
                                               NSMutableArray *arrayCategoryMust)) completionHandler
                              error:(void (^)(ABCError *error)) errorHandler;
{

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        tABC_Error error;
        ABCError *nserror = nil;
        tABC_QuestionChoices *pQuestionChoices = NULL;
        ABC_GetQuestionChoices(&pQuestionChoices, &error);

        nserror = [ABCError makeNSError:error];
        
        if (!nserror)
        {
            NSMutableArray        *arrayCategoryString  = [[NSMutableArray alloc] init];
            NSMutableArray        *arrayCategoryNumeric = [[NSMutableArray alloc] init];
            NSMutableArray        *arrayCategoryMust    = [[NSMutableArray alloc] init];

            [self categorizeQuestionChoices:pQuestionChoices
                             categoryString:&arrayCategoryString
                            categoryNumeric:&arrayCategoryNumeric
                               categoryMust:&arrayCategoryMust];


            dispatch_async(dispatch_get_main_queue(), ^(void) {
                completionHandler(arrayCategoryString, arrayCategoryNumeric, arrayCategoryMust);
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                errorHandler(nserror);
            });
        }
        ABC_FreeQuestionChoices(pQuestionChoices);
    });
}

- (BOOL)accountHasPassword:(NSString *)username error:(ABCError **)nserror;
{
    tABC_Error error;
    ABCError *nserror2 = nil;
    bool exists = false;
    ABC_PasswordExists([username UTF8String], &exists, &error);
    nserror2 = [ABCError makeNSError:error];
    if (nserror) *nserror = nserror2;
    
    return exists == true ? YES : NO;
}

- (BOOL) hasDeviceCapability:(ABCDeviceCaps) caps
{
    switch (caps) {
        case ABCDeviceCapsTouchID:
            return [self.keyChain bHasSecureEnclave];
            break;
    }
    return NO;
}

+ (int) getMinimumUsernamedLength { return ABC_MIN_USERNAME_LENGTH; };
+ (int) getMinimumPasswordLength { return ABC_MIN_PASS_LENGTH; };
+ (int) getMinimumPINLength { return ABC_MIN_PIN_LENGTH; };

static int debugLevel = 1;

void abcSetDebugLevel(int level)
{
    debugLevel = level;
}

void abcDebugLog(int level, NSString *statement)
{
    if (level <= debugLevel)
    {
        static NSDateFormatter *timeStampFormat;
        if (!timeStampFormat) {
            timeStampFormat = [[NSDateFormatter alloc] init];
            [timeStampFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            [timeStampFormat setTimeZone:[NSTimeZone systemTimeZone]];
        }
        
        NSString *tempStr = [NSString stringWithFormat:@"<%@> %@",
                             [timeStampFormat stringFromDate:[NSDate date]],statement];
        
        ABC_Log([tempStr UTF8String]);
    }
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

+ (void)categorizeQuestionChoices:(tABC_QuestionChoices *)pChoices
                   categoryString:(NSMutableArray **)arrayCategoryString
                  categoryNumeric:(NSMutableArray **)arrayCategoryNumeric
                     categoryMust:(NSMutableArray **)arrayCategoryMust
{
    //splits wad of questions into three categories:  string, numeric and must
    if (pChoices)
    {
        if (pChoices->aChoices)
        {
            for (int i = 0; i < pChoices->numChoices; i++)
            {
                tABC_QuestionChoice *pChoice = pChoices->aChoices[i];
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

                [dict setObject: [NSString stringWithFormat:@"%s", pChoice->szQuestion] forKey:@"question"];
                [dict setObject: [NSNumber numberWithInt:pChoice->minAnswerLength] forKey:@"minLength"];

                //printf("question: %s, category: %s, min: %d\n", pChoice->szQuestion, pChoice->szCategory, pChoice->minAnswerLength);

                NSString *category = [NSString stringWithFormat:@"%s", pChoice->szCategory];
                if([category isEqualToString:@"string"])
                {
                    [*arrayCategoryString addObject:dict];
                }
                else if([category isEqualToString:@"numeric"])
                {
                    [*arrayCategoryNumeric addObject:dict];
                }
                else if([category isEqualToString:@"must"])
                {
                    [*arrayCategoryMust addObject:dict];
                }
            }
        }
    }
}

- (void)printABC_Error:(const tABC_Error *)pError
{
    if (pError)
    {
        if (pError->code != ABC_CC_Ok)
        {
            NSString *log;

            log = [NSString stringWithFormat:@"Code: %d, Desc: %s, Func: %s, File: %s, Line: %d\n",
                                             pError->code,
                                             pError->szDescription,
                                             pError->szSourceFunc,
                                             pError->szSourceFile,
                                             pError->nSourceLine];
            ABC_Log([log UTF8String]);
        }
    }
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

@end

