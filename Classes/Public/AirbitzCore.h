//
// AirbitzCore.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//
#import "ABCConditionCode.h"
#import "ABCKeychain.h"
#import "ABCRequest.h"
#import "ABCSettings.h"
#import "ABCSpend.h"
#import "ABCTransaction.h"
#import "ABCTxOutput.h"
#import "ABCUser.h"
#import "ABCWallet.h"

/**
 AirbitzCore (ABC) is a client-side blockchain and EdgeSecurity SDK providing auto-encrypted
 and auto-backed up accounts and wallets with zero-knowledge security and privacy. All
 blockchain/bitcoin private and public keys are fully encrypted by the users' credentials
 before being backed up on to peer to peer servers. ABC allows developers to create new
 Airbitz wallet accounts or login to pre-existing accounts. Account encrypted data is
 automatically synchronized between all devices and apps using the Airbitz SDK. This allows a
 third party application to generate payment requests or send funds for the users' account
 that may have been created on the Airbitz Mobile Bitcoin Wallet or any other Airbitz SDK
 application.
 
    - (void) exampleMethod
    {
        // Create an account
        AirbitzCore *abc  = [[AirbitzCore alloc] init:@"YourAPIKeyHere"];
        ABCUser *abcUser  = [abc createAccount:@"myUsername" password:@"MyPa55w0rd!&" pin:@"4283" delegate:self];
        // New account is auto logged in after creation

        // Create a wallet in the user account
        ABCWallet *wallet = [abcUser createWallet:@"My Awesome Bitcoins" currencyNum:0];

        // Logout
        [abc logout:abcUser];

        // Log back in with full credentials
        abcUser = [abc signIn:@"myUsername" password:@"MyPa55w0rd!&" delegate:self otp:nil];
        [abc logout:abcUser];

        // Log back in with PIN using completion handler codeblock
        [abc signInWithPIN:@"myUsername" pin:@"4283" delegate:self complete:^(ABCUser *user)
        {
            ABCUser *abcUser = user;

            // Get the first wallet in the account
            ABCWallet *wallet = abcUser.arrayWallets[0];

            // Create a bitcoin request
            ABCRequest *request = [[ABCRequest alloc] init];
            
            // Put in some optional meta data into this request so incoming funds are automatically tagged
            request.payeeName     = @"William Swanson"; // Name of the person receiving request
            request.category      = @"Income:Rent";     // Category of payment. Auto tags category when funds come in
            request.notes         = @"Rent payment for Jan 2016";
            request.amountSatoshi = 12345000;
            
            [wallet createReceiveRequestWithDetails:request];

            // Use the request results
            NSString *bitcoinAddress = request.address;
            NSString *bitcoinURI     = request.uri;
            UIImage  *bitcoinQRCode  = request.qrCode;
            
            // Now go and display the QR code or send payment to address in some other way.

        } error:^(ABCConditionCode ccode, NSString *errorString)
        {
            NSLog(@"Argh! Error code: %d. Error string:%@", ccode, errorString);
        }];
        
    }

    // Delegate method called when bitcoin is received
    - (void) abcUserIncomingBitcoin:(ABCWallet *)wallet txid:(NSString *)txid;
    {
        NSLog(@"Yay, my wallet just received bitcoin", wallet.strName);
    }
 */


#define ABC_CONFIRMED_CONFIRMATION_COUNT    6
#define ABC_PIN_REQUIRED_PERIOD_SECONDS     120
#define ABC_ARRAY_EXCHANGES     @[@"Bitstamp", @"BraveNewCoin", @"Coinbase", @"CleverCoin"]

#define ABCLog(level, format_string,...) \
((abcDebugLog(level, [NSString stringWithFormat:format_string,##__VA_ARGS__])))

void abcDebugLog(int level, NSString *string);
void abcSetDebugLevel(int level);

typedef enum eABCDeviceCaps
{
    ABCDeviceCapsTouchID,
} ABCDeviceCaps;

@class ABCSpend;
@class ABCSettings;
@class ABCRequest;
@class ABCUser;

@interface AirbitzCore : NSObject

/// @name AirbitzCore currency public read-only variables

@property (nonatomic, strong) NSArray                   *arrayCurrencyCodes;
@property (nonatomic, strong) NSArray                   *arrayCurrencyNums;
@property (nonatomic, strong) NSArray                   *arrayCurrencyStrings;

- (id)init:(NSString *)abcAPIKey;
- (id)init:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey;
- (void)free;

- (BOOL)accountExistsLocal:(NSString *)username;
- (NSArray *)getRecoveryQuestionsForUserName:(NSString *)strUserName
                                   isSuccess:(BOOL *)bSuccess
                                    errorMsg:(NSMutableString *)error;
- (void)restoreConnectivity;
- (void)lostConnectivity;
- (NSString *)coreVersion;
- (NSString *)currencyAbbrevLookup:(int) currencyNum;
- (NSString *)currencySymbolLookup:(int)currencyNum;

#pragma mark - Account Management

/// -----------------------------------------------------------------------------
/// @name Account Management
/// -----------------------------------------------------------------------------

/** Create an Airbitz account with specified username, password, and PIN.
 * @param username NSString*
 * @param password NSString*
 * @param pin NSString*
 * @param delegate ABCUserDelegate object for callbacks. May be set to nil;
 * @param complete (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCUser* User object.<br>
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return ABCUser* User object or nil if failure
 */
- (void)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate
             complete:(void (^)(ABCUser *)) completionHandler
                error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
- (ABCUser *)createAccount:(NSString *)username password:(NSString *)password pin:(NSString *)pin delegate:(id)delegate;


/**
 * Sign In to an Airbitz account.
 * @param username NSString*
 * @param password NSString*
 * @param delegate ABCUserDelegate object for callbacks. May be set to nil;
 * @param otp NSString* One Time Password token (optional). Send nil if logging in w/o OTP token
 *                       or if OTP token has already been saved in this account from prior login
 * @param complete (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCUser* User object.
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return ABCUser*
 */
- (void)signIn:(NSString *)username password:(NSString *)password delegate:(id)delegate otp:(NSString *)otp
      complete:(void (^)(ABCUser *user)) completionHandler
         error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
- (ABCUser *)signIn:(NSString *)username password:(NSString *)password delegate:(id)delegate otp:(NSString *)otp;

/**
 * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
 * been logged into using a full username & password
 * @param username NSString*
 * @param pin NSString*
 * @param delegate ABCUserDelegate object for callbacks. May be set to nil;
 * @param complete (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCUser* User object.<br>
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return ABCUser*
 */
- (void)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate
             complete:(void (^)(ABCUser *user)) completionHandler
                error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
- (ABCUser *)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate;

/**
 * Get ABCUser object for username if logged in.
 * @param username NSString*
 * @return ABCUser* if logged in. nil otherwise
 */
- (ABCUser *) getLoggedInUser:(NSString *)username;

/**
 * Logout the specified ABCUser object
 * @param abcUser ABCUser* user to logout
 * @return void
 */
- (void)logout:(ABCUser *)abcUser;

/**
 * Check if specified username has a password on the account or if it is
 * a PIN-only account.
 * @param username NSString* user to check
 * @return BOOL true if user has a password
 */
- (BOOL)passwordExists:(NSString *)username;


/** Checks a password for valid entropy looking for correct minimum
 *  requirements such as upper, lowercase letters, numbers, and # of digits. This should be used
 *  by app to give feedback to user before creating a new account.
 * @param password NSString* Password to check
 * @param secondsToCrack double* estimated time it takes to crack password
 * @param count int* pointer to number of rules used
 * @param ruleDescription NSMutableArray* array of NSString* with description of each rule
 * @param rulePassed NSMutableArray* array of NSNumber* with BOOL of whether rule passed
 * @param checkResultsMessage NSMutableString* message describing all failures
 * @return BOOL True if password passes all requirements
 */
- (BOOL)checkPasswordRules:(NSString *)password
            secondsToCrack:(double *)secondsToCrack
                     count:(unsigned int *)count
           ruleDescription:(NSMutableArray **)ruleDescription
                rulePassed:(NSMutableArray **)rulePassed
       checkResultsMessage:(NSMutableString **) checkResultsMessage;

/**
 * Get a list of previously logged in usernames on this device
 * @param  accounts NSMutableArray* array of strings of account names
 * @return ABCConditionCode error code
 */
- (ABCConditionCode) getLocalAccounts:(NSMutableArray *) accounts;

/**
 * Checks if username is available
 * @param username NSString* username to check
 * @return ABCConditionCodeOk if username is available
 */
- (ABCConditionCode)isAccountUsernameAvailable:(NSString *)username;

/*
 * Attempts to auto-relogin the specified user if they are within their auto-logout
 * setting (default 1 hour). Should be called upon initial execution of app and when the Login screen
 * reappears after logout or if user selects a different user to login with. If user can 
 * use TouchID to login and they are outside of their auto-logout time period, this will automatically
 * show the TouchID prompt on supported devices and log them in if authenticated.
 * @param username: user account to attempt to relogin
 * @param delegate delegate object for callbacks
 * @param doBeforeLogin: completion handler code block executes before login is attempted
 * @param completeWithLogin: completion handler code block executes if login is successful<br>
 * - *param* ABCUser* User object<br>
 * - *param* BOOL* usedTouchID: TRUE if user used TouchID to login
 * @param completeNoLogin: completion handler code block executes if relogin not attempted
 * @param errorHandler: error handler code block which is called if relogin attempted but failed<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return void
 */
- (void)autoReloginOrTouchIDIfPossible:(NSString *)username
                              delegate:(id)delegate
                         doBeforeLogin:(void (^)(void)) doBeforeLogin
                     completeWithLogin:(void (^)(ABCUser *user, BOOL usedTouchID)) completionWithLogin
                       completeNoLogin:(void (^)(void)) completionNoLogin
                                 error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Checks if PIN login is possible for the given username. This checks if
 * there is a local PIN package on the device from a prior login
 * @param username NSString* username to check
 * @return BOOL YES PIN login is possible
 */
- (BOOL)PINLoginExists:(NSString *)username;

/*
 * accountDeleteLocal
 *      Deletes named account from local device. Account is recoverable if it contains a password
 * @param NSString* username: username of account to delete
 *
 * @return ABCConditionCode
 */
- (ABCConditionCode)accountDeleteLocal:(NSString *)username;

#pragma mark - Account Recovery
/// -----------------------------------------------------------------------------
/// @name Account Recovery
/// -----------------------------------------------------------------------------

/**
 * changePasswordWithRecoveryAnswers
 * @param username NSString* username whose password to change
 * @param recoveryAnswers NSString* recovery answers delimited by '\n'
 * @param newPassword NSString* new password
 * @param complete (Optional) Code block called on success. Returns void if used
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 */
- (ABCConditionCode)changePasswordWithRecoveryAnswers:(NSString *)username
                                      recoveryAnswers:(NSString *)answers
                                          newPassword:(NSString *)password;
- (void)changePasswordWithRecoveryAnswers:(NSString *)username
                          recoveryAnswers:(NSString *)answers
                              newPassword:(NSString *)password
                                 complete:(void (^)(void)) completionHandler
                                    error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * @param username NSString*
 * @param answers  NSString* concatenated string of recovery answers separated by '\n' after each answer
 * @param otp NSString* OTP token if needed to login. May be set to nil.
 * @param complete: completion handler code block<br>
 * - *param* BOOL validAnswers TRUE if recovery answers are correct
 * @param error: error handler code block which is called with the following args<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return void
 */
- (void)checkRecoveryAnswers:(NSString *)username answers:(NSString *)answers otp:(NSString *)otp
                    complete:(void (^)(BOOL validAnswers)) completionHandler
                       error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Gets a list of recovery questions to ask user. These are suggested questions from the Airbitz
 * servers, but app is free to choose its own to present the user.
 * @param complete completion handler code block which is called with the following args<br>
 * - *param* arrayCategoryString NSMutableString* array of string based questions<br>
 * - *param* arrayCategoryNumeric NSMutableString* array of numeric based questions<br>
 * - *param* arrayCategoryMust NSMutableString* array of questions of which one must have an answer
 * @param error error handler code block which is called with the following args<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return void
 */
- (void)getRecoveryQuestionsChoices: (void (^)(
                                               NSMutableArray *arrayCategoryString,
                                               NSMutableArray *arrayCategoryNumeric,
                                               NSMutableArray *arrayCategoryMust)) completionHandler
                              error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

#pragma mark - OTP Management
/// -----------------------------------------------------------------------------
/// @name OTP (2 Factor Auth) Management
/// -----------------------------------------------------------------------------

/**
 * Associates an OTP key with the given username.
 * This will not write to disk until the user has successfully logged in
 * at least once.
 * @param username NSString* user to set the OTP key for
 * @param key NSString* key to set
 * @return ABCConditionCode
 */
- (ABCConditionCode)setOTPKey:(NSString *)username
                          key:(NSString *)key;

/**
 * Returns the OTP reset date for the last account that failed to log in,
 * if any. Returns an empty string otherwise.
 * @param date NSDate** pointer to NSDate for return value date
 * @return ABCConditionCode
 */
- (ABCConditionCode)getOTPResetDateForLastFailedAccountLogin:(NSDate **)date;

/**
 * Returns an array of usernames of accounts local to device that
 * have a pending OTP reset on the server. Use getOTPResetDateForLastFailedAccountLogin
 * to get the NSDate of when the OTP reset will occur.
 * @return NSArray* of NSString* of usernames
 */
- (NSArray *)getOTPResetUsernames;

/**
 * requestOTPReset
 * Launches an OTP reset timer on the server,
 * which will disable the OTP authentication requirement when it expires.
 *
 * This only works after the caller has successfully authenticated
 * with the server, such as through a password login,
 * but has failed to fully log in due to a missing OTP key.
 * @param NSString   *username:
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param completionHandler: completion handler code block
 * @param errorHandler: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */
- (ABCConditionCode)requestOTPReset:(NSString *)username
                           complete:(void (^)(void)) completionHandler
                              error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;
- (ABCConditionCode)requestOTPReset:(NSString *)username;

/*
 * uploadLogs
 * @param NSString* userText: text to send to support staff
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param complete: completion handler code block which is called with void
 * @param error: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */
- (ABCConditionCode)uploadLogs:(NSString *)userText;
- (void)uploadLogs:(NSString *)userText
          complete:(void(^)(void))completionHandler
             error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/// @name Error Return

/**
 * Get the most recent ABCCConditionCode from the previous API call.
 * @return ABCConditionCode error code
 */
- (ABCConditionCode) getLastConditionCode;

/**
 * Get the error string from the most recent ABCCConditionCode from the previous API call.
 * @return ABCConditionCode error code
 */
- (NSString *) getLastErrorString;

/// ------------------------------------------------------------------
/// @name System Query
/// ------------------------------------------------------------------

/**
 * Check if device has a capability from ABCDeviceCaps
 * @return BOOL TRUE if device has specified capability
 */
- (BOOL) hasDeviceCapability:(ABCDeviceCaps) caps;

/**
 * Returns TRUE if AirbitzCore is compiled for testnet
 * @return BOOL
 */
- (bool)isTestNet;

/*
 * enterBackground
 * Call this routine from within applicationDidEnterBackground to have ABC
 * spin down any background queues
 */
- (void)enterBackground;


/*
 * enterBackground
 * Call this routine from within applicationDidEnterBackground to have ABC
 * spin down any background queues
 */
- (void)enterForeground;

/// ------------------------------------------------------------------
/// @name Utility methods
/// ------------------------------------------------------------------

/**
 * Encodes a string into a QR code returned as UIImage *
 * @param string NSString* string to encode
 * @return UIImage* returned image
 */
- (UIImage *)encodeStringToQRImage:(NSString *)string;

/// @name Class methods to retrieve constant parameters from ABC

+ (int) getMinimumUsernamedLength;
+ (int) getMinimumPasswordLength;
+ (int) getMinimumPINLength;
+ (int) getDefaultCurrencyNum;

- (NSString *) getLastAccessedAccount;
- (void) setLastAccessedAccount:(NSString *) account;


@end
