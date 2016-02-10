
#import "AirbitzCore+Internal.h"
#import <pthread.h>

#define CURRENCY_NUM_AUD                 36
#define CURRENCY_NUM_CAD                124
#define CURRENCY_NUM_CNY                156
#define CURRENCY_NUM_CUP                192
#define CURRENCY_NUM_HKD                344
#define CURRENCY_NUM_MXN                484
#define CURRENCY_NUM_NZD                554
#define CURRENCY_NUM_PHP                608
#define CURRENCY_NUM_GBP                826
#define CURRENCY_NUM_USD                840
#define CURRENCY_NUM_EUR                978

#define DEFAULT_CURRENCY_NUM CURRENCY_NUM_USD // USD

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
    NSDictionary                                    *localeAsCurrencyNum;
    BOOL                                            bInitialized;
    BOOL                                            bNewDeviceLogin;
    NSMutableDictionary                             *currencyCodesCache;
    NSMutableDictionary                             *currencySymbolCache;
    ABCError                                        *abcError;
}

@property (atomic, strong) ABCLocalSettings         *localSettings;
@property (atomic, strong) ABCKeychain              *keyChain;
@property (atomic, strong) NSMutableArray           *loggedInUsers;

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

        currencySymbolCache = [[NSMutableDictionary alloc] init];
        currencyCodesCache = [[NSMutableDictionary alloc] init];
        
        self.loggedInUsers = [[NSMutableArray alloc] init];

        localeAsCurrencyNum = @{
            @"AUD" : @CURRENCY_NUM_AUD,
            @"CAD" : @CURRENCY_NUM_CAD,
            @"CNY" : @CURRENCY_NUM_CNY,
            @"CUP" : @CURRENCY_NUM_CUP,
            @"HKD" : @CURRENCY_NUM_HKD,
            @"MXN" : @CURRENCY_NUM_MXN,
            @"NZD" : @CURRENCY_NUM_NZD,
            @"PHP" : @CURRENCY_NUM_PHP,
            @"GBP" : @CURRENCY_NUM_GBP,
            @"USD" : @CURRENCY_NUM_USD,
            @"EUR" : @CURRENCY_NUM_EUR,
        };

        bInitialized = YES;

        tABC_Error Error;
        tABC_Currency       *aCurrencies;
        int                 currencyCount;

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
        [self setLastErrors:Error];

        // Fetch general info as soon as possible
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            tABC_Error error;
            ABC_GeneralInfoUpdate(&error);
            [self setLastErrors:Error];
        });

        Error.code = ABC_CC_Ok;

        // get the currencies
        aCurrencies = NULL;
        ABC_GetCurrencies(&aCurrencies, &currencyCount, &Error);
        [self setLastErrors:Error];

        // set up our internal currency arrays
        NSMutableArray *arrayCurrencyCodes = [[NSMutableArray alloc] initWithCapacity:currencyCount];
        NSMutableArray *arrayCurrencyNums = [[NSMutableArray alloc] initWithCapacity:currencyCount];
        NSMutableArray *arrayCurrencyStrings = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < currencyCount; i++)
        {
            [arrayCurrencyStrings addObject:[NSString stringWithFormat:@"%s - %@",
                                                                       aCurrencies[i].szCode,
                                                                       [NSString stringWithUTF8String:aCurrencies[i].szDescription]]];
            [arrayCurrencyNums addObject:[NSNumber numberWithInt:aCurrencies[i].num]];
            [arrayCurrencyCodes addObject:[NSString stringWithUTF8String:aCurrencies[i].szCode]];
        }
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

- (void)enterBackground
{
    for (ABCUser *user in self.loggedInUsers)
    {
        [user enterBackground];
    }
}

- (void)enterForeground
{
    [self checkLoginExpired];
    
    for (ABCUser *user in self.loggedInUsers)
    {
        [user enterForeground];
    }
}

- (NSNumberFormatter *)generateNumberFormatter
{
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setMinimumFractionDigits:2];
    [f setMaximumFractionDigits:2];
    [f setLocale:[NSLocale localeWithLocaleIdentifier:@"USD"]];
    return f;
}

- (NSDate *)dateFromTimestamp:(int64_t) intDate;
{
    return [NSDate dateWithTimeIntervalSince1970: intDate];
}

- (NSString *)formatCurrency:(double) currency withCurrencyNum:(int) currencyNum
{
    return [self formatCurrency:currency withCurrencyNum:currencyNum withSymbol:true];
}

- (NSString *)formatCurrency:(double) currency withCurrencyNum:(int) currencyNum withSymbol:(bool) symbol
{
    NSNumberFormatter *f = [self generateNumberFormatter];
    [f setNumberStyle: NSNumberFormatterCurrencyStyle];
    if (symbol) {
        NSString *symbol = [self currencySymbolLookup:currencyNum];
        [f setNegativePrefix:[NSString stringWithFormat:@"-%@ ",symbol]];
        [f setNegativeSuffix:@""];
        [f setCurrencySymbol:[NSString stringWithFormat:@"%@ ", symbol]];
    } else {
        [f setCurrencySymbol:@""];
    }
    return [f stringFromNumber:[NSNumber numberWithFloat:currency]];
}

// gets the recover questions for a given account
// nil is returned if there were no questions for this account
- (NSArray *)getRecoveryQuestionsForUserName:(NSString *)strUserName
                                   isSuccess:(BOOL *)bSuccess
                                    errorMsg:(NSMutableString *)error
{
    NSMutableArray *arrayQuestions = nil;
    char *szQuestions = NULL;

    *bSuccess = NO; 
    tABC_Error Error;
    tABC_CC result = ABC_GetRecoveryQuestions([strUserName UTF8String],
                                              &szQuestions,
                                              &Error);
    [self setLastErrors:Error];
    if (ABC_CC_Ok == result)
    {
        if (szQuestions && strlen(szQuestions))
        {
            // create an array of strings by pulling each question that is seperated by a newline
            arrayQuestions = [[NSMutableArray alloc] initWithArray:[[NSString stringWithUTF8String:szQuestions] componentsSeparatedByString: @"\n"]];
            // remove empties
            [arrayQuestions removeObject:@""];
            *bSuccess = YES; 
        }
        else
        {
            [error appendString:NSLocalizedString(@"This user does not have any recovery questions set!", nil)];
            *bSuccess = NO; 
        }
    }
    else
    {
        [error appendString:[self getLastErrorString]];
        [self setLastErrors:Error];
    }

    if (szQuestions)
    {
        free(szQuestions);
    }

    return arrayQuestions;
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

- (ABCUser *) getLoggedInUser:(NSString *)username;
{
    // Grab all logged in users
    for (ABCUser *user in self.loggedInUsers)
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
    for (ABCUser *user in self.loggedInUsers)
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
    for (ABCUser *user in self.loggedInUsers)
    {
        [user restoreConnectivity];
    }
}

- (void)lostConnectivity;
{
    for (ABCUser *user in self.loggedInUsers)
    {
        [user lostConnectivity];
    }
}

- (bool)isTestNet
{
    bool result = false;
    tABC_Error Error;

    if (ABC_IsTestNet(&result, &Error) != ABC_CC_Ok) {
        [self setLastErrors:Error];
    }
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

- (NSString *)currencyAbbrevLookup:(int)currencyNum
{
    ABCLog(2,@"ENTER currencyAbbrevLookup: %@", [NSThread currentThread].name);
    NSNumber *c = [NSNumber numberWithInt:currencyNum];
    NSString *cached = [currencyCodesCache objectForKey:c];
    if (cached != nil) {
        ABCLog(2,@"EXIT currencyAbbrevLookup CACHED code:%@ thread:%@", cached, [NSThread currentThread].name);
        return cached;
    }
    tABC_Error error;
    int currencyCount;
    tABC_Currency *currencies = NULL;
    ABC_GetCurrencies(&currencies, &currencyCount, &error);
    ABCLog(2,@"CALLED ABC_GetCurrencies: %@ currencyCount:%d", [NSThread currentThread].name, currencyCount);
    if (error.code == ABC_CC_Ok) {
        for (int i = 0; i < currencyCount; ++i) {
            if (currencyNum == currencies[i].num) {
                NSString *code = [NSString stringWithUTF8String:currencies[i].szCode];
                [currencyCodesCache setObject:code forKey:c];
                ABCLog(2,@"EXIT currencyAbbrevLookup code:%@ thread:%@", code, [NSThread currentThread].name);
                return code;
            }
        }
    }
    ABCLog(2,@"EXIT currencyAbbrevLookup code:NULL thread:%@", [NSThread currentThread].name);
    return @"";
}

- (NSString *)currencySymbolLookup:(int)currencyNum
{
    NSNumber *c = [NSNumber numberWithInt:currencyNum];
    NSString *cached = [currencySymbolCache objectForKey:c];
    if (cached != nil) {
        return cached;
    }
    NSNumberFormatter *formatter = nil;
    NSString *code = [self currencyAbbrevLookup:currencyNum];
    for (NSString *l in NSLocale.availableLocaleIdentifiers) {
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier:l];
        if ([f.currencyCode isEqualToString:code]) {
            formatter = f;
            break;
        }
    }
    if (formatter != nil) {
        [currencySymbolCache setObject:formatter.currencySymbol forKey:c];
        return formatter.currencySymbol;
    } else {
        return @"";
    }
}

- (ABCConditionCode) getLocalAccounts:(NSMutableArray *) accounts;
{
    char * pszUserNames;
    NSArray *arrayAccounts = nil;
    tABC_Error error;
    ABC_ListAccounts(&pszUserNames, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
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
    return ccode;
}

- (BOOL)PINLoginExists:(NSString *)username;
{
    ABCConditionCode ccode;
    bool exists = NO;
    if (username && 0 < username.length)
    {
        tABC_Error error;
        ABC_PinLoginExists([username UTF8String], &exists, &error);
        ccode = [self setLastErrors:error];
        if (ABCConditionCodeOk == ccode)
            return (BOOL) exists;
    }
    return NO;
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


- (ABCConditionCode)uploadLogs:(NSString *)userText;
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

    return [self setLastErrors:error];
}

- (void)uploadLogs:(NSString *)userText
          complete:(void(^)(void))completionHandler
             error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {

        ABCConditionCode ccode;
        ccode = [self uploadLogs:userText];

        NSString *errorString = [self getLastErrorString];

        dispatch_async(dispatch_get_main_queue(),^{
            if (ABC_CC_Ok == ccode) {
                if (completionHandler) completionHandler();
            } else {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    });
}

- (ABCConditionCode)accountDeleteLocal:(NSString *)account;
{
    tABC_Error error;
    ABC_AccountDelete((const char*)[account UTF8String], &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        if ([account isEqualToString:[self getLastAccessedAccount]])
        {
            // If we deleted the account we most recently logged into,
            // set the lastLoggedInAccount to the top most account in the list.
            NSMutableArray *accounts = [[NSMutableArray alloc] init];
            [self getLocalAccounts:accounts];
            [self setLastAccessedAccount:accounts[0]];
        }
    }

    return [self setLastErrors:error];
}

/////////////////////////////////////////////////////////////////
//////////////////// New AirbitzCore methods ////////////////////
/////////////////////////////////////////////////////////////////

#pragma mark - Account Management

- (ABCUser *)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate;
{
    tABC_Error error;
    const char *szPassword = [password length] == 0 ? NULL : [password UTF8String];
    ABC_CreateAccount([username UTF8String], szPassword, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        ABCUser *user = [[ABCUser alloc] initWithCore:self];
        user.delegate = delegate;
        user.name = username;
        user.password = password;
        ccode = [user changePIN:pin];

        if (ABCConditionCodeOk == ccode)
        {
            [self.loggedInUsers addObject:user];

            [self setLastAccessedAccount:username];
            // update user's default currency num to match their locale
            int currencyNum = [self getCurrencyNumOfLocale];
            [user.settings enableTouchID];
            [user setDefaultCurrencyNum:currencyNum];
            [user login];
            return user;
        }
    }
    return nil;
}

- (void)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate
                  complete:(void (^)(ABCUser *)) completionHandler
                     error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ABCUser *user = [self createAccount:username password:password pin:pin delegate:delegate];
        NSString *errorString = [self getLastErrorString];
        ABCConditionCode ccode = [self getLastConditionCode];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(user);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    });
}

- (ABCUser *)signIn:(NSString *)username
           password:(NSString *)password
           delegate:(id)delegate
                otp:(NSString *)otp;
{
    
    tABC_Error error;
    ABCConditionCode ccode = ABCConditionCodeOk;
    bNewDeviceLogin = NO;
    
    if (!username || !password)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        ccode = [self setLastErrors:error];
    }
    else
    {
        if (![self accountExistsLocal:username])
            bNewDeviceLogin = YES;
        
        if (otp)
        {
            ccode = [self setOTPKey:username key:otp];
        }
        
        if (ABCConditionCodeOk == ccode)
        {
            ABC_SignIn([username UTF8String],
                       [password UTF8String], &error);
            ccode = [self setLastErrors:error];
            
            if (ABCConditionCodeOk == ccode)
            {
                
                ABCUser *user = [[ABCUser alloc] initWithCore:self];
                user.delegate = delegate;
                [self.loggedInUsers addObject:user];
                user.name = username;
                user.password = password;
                [user login];
                [user setupLoginPIN];
                return user;
            }
        }
    }
    
    return nil;
}


- (void)signIn:(NSString *)username password:(NSString *)password delegate:(id)delegate otp:(NSString *)otp
      complete:(void (^)(ABCUser *user)) completionHandler
         error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ABCUser *user = [self signIn:username password:password delegate:delegate otp:otp];
        NSString *errorString = [self getLastErrorString];
        ABCConditionCode ccode = [self getLastConditionCode];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(user);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    });
}

- (ABCUser *)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate;
{
    tABC_Error error;
    ABCConditionCode ccode;
    
    if (!username || !pin)
    {
        error.code = (tABC_CC) ABCConditionCodeNULLPtr;
        [self setLastErrors:error];
        return nil;
    }
    
    if ([self PINLoginExists:username])
    {
        ABC_PinLogin([username UTF8String],
                     [pin UTF8String],
                     &error);
        ccode = [self setLastErrors:error];
        
        if (ABCConditionCodeOk == ccode)
        {
            ABCUser *user = [[ABCUser alloc] initWithCore:self];
            user.delegate = delegate;
            [self.loggedInUsers addObject:user];
            user.name = username;
            [user login];
            return user;
        }
    }
    else
    {
        error.code = (tABC_CC) ABCConditionCodeError;
        ccode = [self setLastErrors:error];
    }
    return nil;
    
}

- (void)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate
             complete:(void (^)(ABCUser *user)) completionHandler
                error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ABCUser *user = [self signInWithPIN:username pin:pin delegate:delegate];
        NSString *errorString = [self getLastErrorString];
        ABCConditionCode ccode = [self getLastConditionCode];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(user);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    });
}

- (void)logout:(ABCUser *)user;
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

- (BOOL)checkPasswordRules:(NSString *)password
            secondsToCrack:(double *)secondsToCrack
                     count:(unsigned int *)count
           ruleDescription:(NSMutableArray **)ruleDescription
                rulePassed:(NSMutableArray **)rulePassed
       checkResultsMessage:(NSMutableString **) checkResultsMessage;
{
    BOOL valid = YES;
    tABC_Error error;
    tABC_PasswordRule **aRules = NULL;
    ABC_CheckPassword([password UTF8String],
                      secondsToCrack,
                      &aRules,
                      count,
                      &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    
    *ruleDescription = [NSMutableArray arrayWithCapacity:*count];
    *rulePassed = [NSMutableArray arrayWithCapacity:*count];
    
    if (ABCConditionCodeOk == ccode)
    {
        [*checkResultsMessage appendString:@"Your password...\n"];
        for (int i = 0; i < *count; i++)
        {
            tABC_PasswordRule *pRule = aRules[i];
            (*ruleDescription)[i] = [NSString stringWithUTF8String:pRule->szDescription];
            if (!pRule->bPassed)
            {
                valid = NO;
                [*checkResultsMessage appendFormat:@"%s.\n", pRule->szDescription];
                (*rulePassed)[i] = [NSNumber numberWithBool:NO];
            }
            else
            {
                (*rulePassed)[i] = [NSNumber numberWithBool:YES];
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

- (ABCConditionCode)changePasswordWithRecoveryAnswers:(NSString *)username
                                      recoveryAnswers:(NSString *)answers
                                          newPassword:(NSString *)password;
{
    //    const char *ignore = "ignore";
    tABC_Error error;
    
    if (!username || !answers || !password)
    {
        error.code = ABC_CC_BadPassword;
        return [self setLastErrors:error];
    }
    // Should not have any running watchers. This routine should run on a non-logged in user.
//    [self stopWatchers];
//    [self stopQueues];
    
    // NOTE: userNameTextField is repurposed for current password
    ABC_ChangePasswordWithRecoveryAnswers([username UTF8String], [answers UTF8String], [password UTF8String], &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    
//    [self startWatchers];
//    [self startQueues];
    
    if ([self.localSettings.touchIDUsersEnabled containsObject:username])
    {
        [self.localSettings.touchIDUsersDisabled removeObject:username];
        [self.localSettings saveAll];
        [self.keyChain updateLoginKeychainInfo:username
                                      password:password
                                    useTouchID:YES];
    }
    
    return ccode;
}

- (void)changePasswordWithRecoveryAnswers:(NSString *)username
                          recoveryAnswers:(NSString *)answers
                              newPassword:(NSString *)password
                                 complete:(void (^)(void)) completionHandler
                                    error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
         ABCConditionCode ccode = [self changePasswordWithRecoveryAnswers:username
                                                          recoveryAnswers:answers
                                                              newPassword:password];
         NSString *errorString = [self getLastErrorString];
         dispatch_async(dispatch_get_main_queue(), ^(void) {
             if (ABCConditionCodeOk == ccode)
             {
                 if (completionHandler) completionHandler();
             }
             else
             {
                 if (errorHandler) errorHandler(ccode, errorString);
             }
         });
        
     });
}


- (ABCConditionCode)isAccountUsernameAvailable:(NSString *)username;
{
    tABC_Error error;
    ABC_AccountAvailable([username UTF8String], &error);
    return [self setLastErrors:error];
}

- (void)autoReloginOrTouchIDIfPossible:(NSString *)username
                              delegate:(id)delegate
                         doBeforeLogin:(void (^)(void)) doBeforeLogin
                     completeWithLogin:(void (^)(ABCUser *user, BOOL usedTouchID)) completionWithLogin
                       completeNoLogin:(void (^)(void)) completionNoLogin
                                 error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSString *password;
        BOOL      usedTouchID;
        
        BOOL doRelogin = [self autoReloginOrTouchIDIfPossibleMain:username password:&password usedTouchID:&usedTouchID];
        
        if (doRelogin)
        {
            if (doBeforeLogin) doBeforeLogin();
            [self signIn:username password:password delegate:delegate otp:nil complete:^(ABCUser *user){
                if (completionWithLogin) completionWithLogin(user, usedTouchID);
            } error:^(ABCConditionCode ccode, NSString *errorString) {
                if (errorHandler) errorHandler(ccode, errorString);
            }];
        }
        else
        {
            if (completionNoLogin) completionNoLogin();
        }
    });
}

- (int)getCurrencyNumOfLocale
{
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    NSString *localCurrency = [locale objectForKey:NSLocaleCurrencyCode];
    NSNumber *currencyNum = [localeAsCurrencyNum objectForKey:localCurrency];
    if (currencyNum)
    {
        return [currencyNum intValue];
    }
    return CURRENCY_NUM_USD;
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


- (NSArray *)getOTPResetUsernames;
{
    char *szUsernames = NULL;
    NSString *usernames = nil;
    NSArray *usernameArray = nil;
    tABC_Error error;
    ABC_OtpResetGet(&szUsernames, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode && szUsernames)
    {
        usernames = [NSString stringWithUTF8String:szUsernames];
        usernames = [usernames stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        usernames = [self formatUsername:usernames];
        usernameArray = [[NSArray alloc] initWithArray:[usernames componentsSeparatedByString:@"\n"]];
    }
    if (szUsernames)
        free(szUsernames);
    return usernameArray;
}

- (ABCConditionCode)getOTPLocalKey:(NSString *)username
                               key:(NSString **)key;
{
    tABC_Error error;
    char *szSecret = NULL;
    ABC_OtpKeyGet([username UTF8String], &szSecret, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode && szSecret) {
        *key = [NSString stringWithUTF8String:szSecret];
    }
    if (szSecret) {
        free(szSecret);
    }
    ABCLog(2,@("SECRET: %@"), *key);
    return ccode;
}

- (ABCConditionCode)setOTPKey:(NSString *)username
                          key:(NSString *)key;
{
    tABC_Error error;
    ABC_OtpKeySet([username UTF8String], (char *)[key UTF8String], &error);
    return [self setLastErrors:error];
}

- (ABCConditionCode)getOTPResetDateForLastFailedAccountLogin:(NSDate **)date;
{
    tABC_Error error;
    char *szDate = NULL;
    ABC_OtpResetDate(&szDate, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode) {
        if (szDate == NULL || strlen(szDate) == 0) {
            *date = nil;
        } else {
            NSString *dateStr = [NSString stringWithUTF8String:szDate];

            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];

            NSDate *dateTemp = [dateFormatter dateFromString:dateStr];
            *date = dateTemp;
        }
    }

    if (szDate) free(szDate);

    return ccode;
}

- (ABCConditionCode)requestOTPReset:(NSString *)username;
{
    tABC_Error error;
    ABC_OtpResetSet([username UTF8String], &error);
    return [self setLastErrors:error];
}

- (ABCConditionCode)requestOTPReset:(NSString *)username
                           complete:(void (^)(void)) completionHandler
                              error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        ABCConditionCode ccode = [self requestOTPReset:username];
        NSString *errorString = [self getLastErrorString];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler();
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorString);
            }
        });
    });
    return ABCConditionCodeOk;
}

- (UIImage *)encodeStringToQRImage:(NSString *)string;
{
    unsigned char *pData = NULL;
    unsigned int width;
    tABC_Error error;
    UIImage *image = nil;;
    
    ABC_QrEncode([string UTF8String], &pData, &width, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ABCConditionCodeOk == ccode)
    {
        image = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    }
    
    if (pData) {
        free(pData);
    }
    return image;;
}


- (void)getRecoveryQuestionsChoices: (void (^)(
        NSMutableArray *arrayCategoryString,
        NSMutableArray *arrayCategoryNumeric,
        NSMutableArray *arrayCategoryMust)) completionHandler
        error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
{

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        tABC_Error error;
        tABC_QuestionChoices *pQuestionChoices = NULL;
        ABC_GetQuestionChoices(&pQuestionChoices, &error);

        ABCConditionCode ccode = [self setLastErrors:error];
        NSString *errorString = [self getLastErrorString];

        if (ABCConditionCodeOk == ccode)
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
                errorHandler(ccode, errorString);
            });
        }
        ABC_FreeQuestionChoices(pQuestionChoices);
    });
}

- (void)checkRecoveryAnswers:(NSString *)username answers:(NSString *)strAnswers otp:(NSString *)otp
       complete:(void (^)(BOOL validAnswers)) completionHandler
          error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler
{

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        bool bABCValid = false;
        tABC_Error error;
        ABCConditionCode ccode;

        if (otp)
        {
            ccode = [self setOTPKey:username key:otp];
        }
        
        ABC_CheckRecoveryAnswers([username UTF8String],
                [strAnswers UTF8String],
                &bABCValid,
                &error);
        ccode = [self setLastErrors:error];
        NSString *errorStr = [self getLastErrorString];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (ABCConditionCodeOk == ccode)
            {
                if (completionHandler) completionHandler(bABCValid);
            }
            else
            {
                if (errorHandler) errorHandler(ccode, errorStr);
            }
        });
    });
}

- (BOOL)passwordExists:(NSString *)username;
{
    tABC_Error error;
    bool exists = false;
    ABC_PasswordExists([username UTF8String], &exists, &error);
    ABCConditionCode ccode = [self setLastErrors:error];
    if (ccode == ABCConditionCodeOk) {
        return exists == true ? YES : NO;
    }
    return NO;
}

- (ABCConditionCode) getLastConditionCode;
{
    return [abcError getLastConditionCode];
}

- (NSString *) getLastErrorString;
{
    return [abcError getLastErrorString];
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
+ (int) getDefaultCurrencyNum { return DEFAULT_CURRENCY_NUM; };


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

- (ABCConditionCode)setLastErrors:(tABC_Error)error;
{
    ABCConditionCode ccode = [abcError setLastErrors:error];
    return ccode;
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

/// Example code for using AirbitzCore
//- (void) exampleMethod;
//{
//    AirbitzCore *abc  = [[AirbitzCore alloc] init:@"YourAPIKeyHere"];
//    ABCUser *abcUser  = [abc createAccount:@"myUsername" password:@"MyPa55w0rd!&" pin:@"4283" delegate:self];
//    ABCWallet *wallet = [abcUser createWallet:@"My Awesome Bitcoins" currencyNum:0];
//    
//}

@end

