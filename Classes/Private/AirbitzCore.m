
#import "AirbitzCore+Internal.h"
#import <pthread.h>

#define DEFAULT_CURRENCY @"USD"

@class ABCUtil;

@implementation BitidSignature
- (id)init
{
   self = [super init];
   return self;
}
@end

@interface AirbitzCore ()
{
    BOOL                                            bInitialized;
    ABCError                                        *abcError;
}

@property (atomic, strong) ABCLocalSettings         *localSettings;
@property (atomic, strong) ABCKeychain              *keyChain;
@property (atomic, strong) NSMutableArray           *loggedInUsers;
@property (atomic, strong) ABCExchangeCache         *exchangeCache;

@end

@implementation AirbitzCore

- (id)init:(NSString *)abcAPIKey;
{
    return [self init:abcAPIKey hbits:@""];
}

- (id)init:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey
{
    
    if (NO == bInitialized)
    {
        abcError = [[ABCError alloc] init];

        
        self.loggedInUsers = [[NSMutableArray alloc] init];

        bInitialized = YES;

        tABC_Error Error;

        Error.code = ABC_CC_Ok;

        NSMutableData *seedData = [[NSMutableData alloc] init];
        [self fillSeedData:seedData];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docs_dir = [paths objectAtIndex:0];
        NSString *ca_path = [[NSBundle mainBundle] pathForResource:@"ca-certificates" ofType:@"crt"];

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
        
        self.localSettings = [[ABCLocalSettings alloc] init:self];
        self.keyChain = [[ABCKeychain alloc] init:self];

        self.keyChain.localSettings = self.localSettings;
    }
    return self;
}

- (void)free
{
    if (YES == bInitialized)
    {
        ABC_Terminate();
        bInitialized = NO;
    }
}

- (ABCExchangeCache *) exchangeCacheGet;
{
//    if (!self.exchangeCache)
    {
        self.exchangeCache = [[ABCExchangeCache alloc] init:self];
    }
    return self.exchangeCache;
}


- (NSDate *)dateFromTimestamp:(int64_t) intDate;
{
    return [NSDate dateWithTimeIntervalSince1970: intDate];
}

// gets the recover questions for a given account
// nil is returned if there were no questions for this account
- (NSArray *)getRecoveryQuestionsForUserName:(NSString *)username
                                       error:(NSError **)nserror
{
    NSMutableArray *arrayQuestions = nil;
    char *szQuestions = NULL;

    tABC_Error error;
    ABC_GetRecoveryQuestions([username UTF8String],
                                              &szQuestions,
                                              &error);
    NSError *nserror2 = [ABCError makeNSError:error];
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

- (BOOL)autoReloginOrTouchIDIfPossibleMain:(NSString *)username
                                  password:(NSString **)password
                               usedTouchID:(BOOL *)usedTouchID
{
    ABCLog(1, @"ENTER autoReloginOrTouchIDIfPossibleMain");
    *usedTouchID = NO;
    
//    if (HARD_CODED_LOGIN) {
//        self.usernameSelector.textField.text = HARD_CODED_LOGIN_NAME;
//        self.passwordTextField.text = HARD_CODED_LOGIN_PASSWORD;
//        [self showSpinner:YES];
//        [self SignIn];
//        return;
//    }
//    
    if (! [self.keyChain bHasSecureEnclave] )
    {
        ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain: No secure enclave");
        return NO;
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
        return NO;
    }
    
    if ([kcPassword length] >= 10)
    {
        bReloginState = YES;
    }
    
    if (bReloginState)
    {
        if (bUseTouchID && !bReloginKey)
        {
            NSString *prompt = [NSString stringWithFormat:@"%@ [%@]",touchIDPromptText, username];
            
            ABCLog(1, @"Launching TouchID prompt");
            if ([self.keyChain authenticateTouchID:prompt fallbackString:usePasswordText]) {
                bReloginKey = YES;
                *usedTouchID = YES;
            }
            else
            {
                ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain TouchID authentication failed");
                return NO;
            }
        }
        else
        {
            ABCLog(1, @"autoReloginOrTouchIDIfPossibleMain Failed to enter TouchID");
        }
        
        if (bReloginKey)
        {
            if (bReloginState)
            {
                *password = kcPassword;
                return YES;
            }
        }
    }
    else
    {
        ABCLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain reloginState DISABLED");
    }
    return NO;
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

- (void)restoreConnectivity;
{
    for (ABCAccount *user in self.loggedInUsers)
    {
        [user restoreConnectivity];
    }
}

- (void)lostConnectivity;
{
    for (ABCAccount *user in self.loggedInUsers)
    {
        [user lostConnectivity];
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

- (NSString *)coreVersion
{
    NSString *version;
    char *szVersion = NULL;
    ABC_Version(&szVersion, NULL);
    version = [NSString stringWithUTF8String:szVersion];
    free(szVersion);
    return version;
}

+ (NSString *)fixUsername:(NSString *)username
                    error:(NSError **)nserror
{
    NSString *fixedUsername = nil;
    char *szFixedUsername = NULL;
    
    tABC_Error error;
    ABC_FixUsername(&szFixedUsername,
                    [username UTF8String],
                    &error);
    NSError *nserror2 = [ABCError makeNSError:error];
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


- (NSError *) getLocalAccounts:(NSMutableArray *) accounts;
{
    char * pszUserNames;
    NSArray *arrayAccounts = nil;
    NSError *nserror = nil;
    tABC_Error error;
    ABC_ListAccounts(&pszUserNames, &error);
    nserror = [ABCError makeNSError:error];
    
    if (!nserror)
    {
        [accounts removeAllObjects];
        NSString *str = [NSString stringWithCString:pszUserNames encoding:NSUTF8StringEncoding];
        arrayAccounts = [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for(NSString *str in arrayAccounts)
        {
            if(str && str.length!=0)
            {
                [accounts addObject:str];
            }
        }
    }
    return nserror;
}

- (BOOL)PINLoginExists:(NSString *)username; { return [self PINLoginExists:username error:nil]; }
- (BOOL)PINLoginExists:(NSString *)username error:(NSError **)nserror;
{
    NSError *lnserror;
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
    NSString *fixedUsername = [AirbitzCore fixUsername:username error:nil];
    tABC_Error error;
    bool result;
    ABC_AccountSyncExists([fixedUsername UTF8String],
                          &result,
                          &error);
    return (BOOL)result;
}


- (NSError *)uploadLogs:(NSString *)userText;
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
             error:(void (^)(NSError *error)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {

        NSError *error = [self uploadLogs:userText];
        
        dispatch_async(dispatch_get_main_queue(),^{
            if (!error) {
                if (completionHandler) completionHandler();
            } else {
                if (errorHandler) errorHandler(error);
            }
        });
    });
}

- (NSError *)removeLocalAccount:(NSString *)account;
{
    tABC_Error error;
    NSError *nserror = nil;
    ABC_AccountDelete((const char*)[account UTF8String], &error);
    nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        if ([account isEqualToString:[self getLastAccessedAccount]])
        {
            // If we deleted the account we most recently logged into,
            // set the lastLoggedInAccount to the top most account in the list.
            NSMutableArray *accounts = [[NSMutableArray alloc] init];
            nserror = [self getLocalAccounts:accounts];
            [self setLastAccessedAccount:accounts[0]];
        }
    }

    return nserror;
}

/////////////////////////////////////////////////////////////////
//////////////////// New AirbitzCore methods ////////////////////
/////////////////////////////////////////////////////////////////

#pragma mark - Account Management

- (ABCAccount *)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate error:(NSError **)nserror;
{
    tABC_Error error;
    NSError *lnserror = nil;
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
            NSString *currencyCode = [self getCurrencyCodeOfLocale];
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
                  complete:(void (^)(ABCAccount *)) completionHandler
                     error:(void (^)(NSError *)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        ABCAccount *account = [self createAccount:username password:password pin:pin delegate:delegate error:&error];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (nil == error)
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

- (ABCAccount *)signIn:(NSString *)username
              password:(NSString *)password
              delegate:(id)delegate
                   otp:(NSString *)otp
             resetDate:(NSDate **)resetDate
                 error:(NSError **)nserror;
{
    
    NSError *lnserror = nil;
    ABCAccount *account = nil;

    tABC_Error error;
    BOOL bNewDeviceLogin = NO;
    
    if (resetDate) *resetDate = nil;
    
    if (!username || !password)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        lnserror = [ABCError makeNSError:error];
    }
    else
    {
        if (![self accountExistsLocal:username])
            bNewDeviceLogin = YES;
        
        if (otp)
        {
            lnserror = [self setOTPKey:username key:otp];
        }
        
        if (!lnserror)
        {
            ABC_SignIn([username UTF8String],
                       [password UTF8String], &error);
            lnserror = [ABCError makeNSError:error];
            
            if (!lnserror)
            {
                account = [[ABCAccount alloc] initWithCore:self];
                account.bNewDeviceLogin = bNewDeviceLogin;
                account.delegate = delegate;
                [self.loggedInUsers addObject:account];
                account.name = username;
                account.password = password;
                [account login];
                [account setupLoginPIN];
            }
            else if (resetDate &&
                     (ABCConditionCodeInvalidOTP == lnserror.code))
            {
                char *szDate = NULL;
                ABC_OtpResetDate(&szDate, &error);
                NSError *nserror2 = [ABCError makeNSError:error];
                if (!nserror2)
                {
                    if (szDate == NULL || strlen(szDate) == 0)
                    {
                        resetDate = nil;
                    }
                    else
                    {
                        NSString *dateStr = [NSString stringWithUTF8String:szDate];
                        
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
                        
                        NSDate *dateTemp = [dateFormatter dateFromString:dateStr];
                        *resetDate = dateTemp;
                    }
                }
                
                if (szDate) free(szDate);
            }
        }
    }
    
    if (nserror)
        *nserror = lnserror;
    return account;
}


- (void)signIn:(NSString *)username password:(NSString *)password delegate:(id)delegate otp:(NSString *)otp
      complete:(void (^)(ABCAccount *account)) completionHandler
         error:(void (^)(NSError *, NSDate *resetDate)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        NSDate *date;
        ABCAccount *account = [self signIn:username password:password delegate:delegate otp:otp resetDate:&date error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (account)
            {
                if (completionHandler) completionHandler(account);
            }
            else
            {
                if (errorHandler) errorHandler(error, date);
            }
        });
    });
}

- (ABCAccount *)signInWithPIN:(NSString *)username
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(NSError **)nserror;
{
    tABC_Error error;
    NSError *lnserror;
    ABCAccount *account = nil;
    
    if (!username || !pin)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        lnserror = [ABCError makeNSError:error];
    }
    else
    {
        if ([self PINLoginExists:username error:nil])
        {
            ABC_PinLogin([username UTF8String],
                         [pin UTF8String],
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

- (void)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate
             complete:(void (^)(ABCAccount *user)) completionHandler
                error:(void (^)(NSError *)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error;
        ABCAccount *account = [self signInWithPIN:username pin:pin delegate:delegate error:&error];
        
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

- (void)signInWithRecoveryAnswers:(NSString *)username
                          answers:(NSString *)answers
                         delegate:(id)delegate
                              otp:(NSString *)otp
                         complete:(void (^)(ABCAccount *account)) completionHandler
                            error:(void (^)(NSError *, NSDate *resetDate)) errorHandler;
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        tABC_Error error;
        NSError *nserror;
        NSDate *resetDate;
        ABCAccount *account = nil;
        BOOL bNewDeviceLogin = NO;
        
        if (!username || !answers)
        {
            error.code = (tABC_CC) ABCConditionCodeNULLPtr;
            nserror = [ABCError makeNSError:error];
        }
        else
        {
            if (![self accountExistsLocal:username])
                bNewDeviceLogin = YES;
            
            if (otp)
            {
                nserror = [self setOTPKey:username key:otp];
            }
            
            if (![self accountExistsLocal:username])
                bNewDeviceLogin = YES;
            
            // This actually logs in the user
            ABC_RecoveryLogin([username UTF8String],
                              [answers UTF8String],
                              &error);
            nserror = [ABCError makeNSError:error];
            
            if (!nserror)
            {
                account = [[ABCAccount alloc] initWithCore:self];
                account.bNewDeviceLogin = bNewDeviceLogin;
                account.delegate = delegate;
                [self.loggedInUsers addObject:account];
                account.name = username;
                account.password = nil;
                [account login];
                [account setupLoginPIN];
            }
            else if ((ABCConditionCodeInvalidOTP == nserror.code))
            {
                char *szDate = NULL;
                ABC_OtpResetDate(&szDate, &error);
                NSError *nserror2 = [ABCError makeNSError:error];
                if (!nserror2)
                {
                    if (szDate == NULL || strlen(szDate) == 0)
                    {
                        resetDate = nil;
                    }
                    else
                    {
                        NSString *dateStr = [NSString stringWithUTF8String:szDate];
                        
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
                        
                        NSDate *dateTemp = [dateFormatter dateFromString:dateStr];
                        resetDate = dateTemp;
                    }
                }
                
                if (szDate) free(szDate);
                
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (!nserror)
            {
                if (completionHandler) completionHandler(account);
            }
            else
            {
                if (errorHandler) errorHandler(nserror, resetDate);
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

+ (BOOL)checkPasswordRules:(NSString *)password
            secondsToCrack:(double *)secondsToCrack
                     count:(unsigned int *)count
           ruleDescription:(NSMutableArray *)ruleDescription
                rulePassed:(NSMutableArray *)rulePassed
       checkResultsMessage:(NSMutableString *)checkResultsMessage;
{
    BOOL valid = YES;
    tABC_Error error;
    tABC_PasswordRule **aRules = NULL;
    ABC_CheckPassword([password UTF8String],
                      secondsToCrack,
                      &aRules,
                      count,
                      &error);
    NSError *nserror = [ABCError makeNSError:error];
    
    if (!nserror)
    {
        [checkResultsMessage appendString:@"Your password...\n"];
        for (int i = 0; i < *count; i++)
        {
            tABC_PasswordRule *pRule = aRules[i];
            [ruleDescription addObject:[NSString stringWithUTF8String:pRule->szDescription]];
            if (!pRule->bPassed)
            {
                valid = NO;
                [checkResultsMessage appendFormat:@"%s.\n", pRule->szDescription];
                [rulePassed addObject:[NSNumber numberWithBool:NO]];
            }
            else
            {
                [rulePassed addObject:[NSNumber numberWithBool:YES]];
            }
        }
    }
    else
    {
        return NO;
    }
    
    ABC_FreePasswordRuleArray(aRules, *count);
    return valid;
}

- (NSError *)isAccountUsernameAvailable:(NSString *)username;
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
                                 error:(void (^)(NSError *error)) errorHandler;
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSString *password;
        BOOL      usedTouchID;
        
        BOOL doRelogin = [self autoReloginOrTouchIDIfPossibleMain:username password:&password usedTouchID:&usedTouchID];
        
        if (doRelogin)
        {
            if (doBeforeLogin) doBeforeLogin();
            [self signIn:username password:password delegate:delegate otp:nil complete:^(ABCAccount *account){
                if (completionWithLogin) completionWithLogin(account, usedTouchID);
            } error:^(NSError *error, NSDate *resetDate) {
                if (errorHandler) errorHandler(error);
            }];
        }
        else
        {
            if (completionNoLogin) completionNoLogin();
        }
    });
}

- (NSString *)getCurrencyCodeOfLocale
{
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    NSString *code = [locale objectForKey:NSLocaleCurrencyCode];
    
    if (code)
        return code;
    else
        return DEFAULT_CURRENCY;
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


- (NSArray *)getOTPResetUsernames:(NSError **)nserror;
{
    char *szUsernames = NULL;
    NSString *usernames = nil;
    NSArray *usernameArray = nil;
    tABC_Error error;
    NSError *nserror2 = nil;
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

- (NSError *)setOTPKey:(NSString *)username
                   key:(NSString *)key;
{
    tABC_Error error;
    ABC_OtpKeySet([username UTF8String], (char *)[key UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (NSError *)requestOTPReset:(NSString *)username;
{
    tABC_Error error;
    ABC_OtpResetSet([username UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (void)requestOTPReset:(NSString *)username
                           complete:(void (^)(void)) completionHandler
                              error:(void (^)(NSError *error)) errorHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error = [self requestOTPReset:username];
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

+ (UIImage *)encodeStringToQRImage:(NSString *)string error:(NSError **)nserror;
{
    unsigned char *pData = NULL;
    unsigned int width;
    tABC_Error error;
    UIImage *image = nil;
    NSError *nserror2 = nil;
    
    ABC_QrEncode([string UTF8String], &pData, &width, &error);
    nserror2 = [ABCError makeNSError:error];
    if (!nserror2)
    {
        image = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    }
    
    if (pData) {
        free(pData);
    }
    if (nserror) *nserror = nserror2;
    return image;;
}


- (void)getRecoveryQuestionsChoices: (void (^)(
                                               NSMutableArray *arrayCategoryString,
                                               NSMutableArray *arrayCategoryNumeric,
                                               NSMutableArray *arrayCategoryMust)) completionHandler
                              error:(void (^)(NSError *error)) errorHandler;
{

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        tABC_Error error;
        NSError *nserror = nil;
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

- (BOOL)passwordExists:(NSString *)username error:(NSError **)nserror;
{
    tABC_Error error;
    NSError *nserror2 = nil;
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

- (void)categorizeQuestionChoices:(tABC_QuestionChoices *)pChoices
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

@end

