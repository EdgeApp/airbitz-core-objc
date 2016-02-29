//
// AirbitzCore.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "ABCAccount.h"
#import "ABCConditionCode.h"
#import "ABCCurrency.h"
#import "ABCDenomination.h"
#import "ABCExchangeCache.h"
#import "ABCKeychain.h"
#import "ABCRequest.h"
#import "ABCSettings.h"
#import "ABCSpend.h"
#import "ABCTransaction.h"
#import "ABCTxOutput.h"
#import "ABCUtil.h"
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
        ABCAccount *abcAccount = [abc createAccount:@"myUsername" password:@"MyPa55w0rd!&" pin:@"4283" delegate:self error:nil];
        // New account is auto logged in after creation
    
        // Create a wallet in the user account
        ABCWallet *wallet = [abcAccount createWallet:@"My Awesome Bitcoins" currency:nil];

        // Logout
        [abc logout:abcAccount];

        // Log back in with full credentials
        abcAccount = [abc signIn:@"myUsername" password:@"MyPa55w0rd!&" delegate:self otp:nil resetDate:nil error:nil];
        [abc logout:abcAccount];

        // Log back in with PIN using completion handler codeblock
        [abc signInWithPIN:@"myUsername" pin:@"4283" delegate:self complete:^(ABCAccount *user)
        {
            ABCAccount *abcAccount = user;

            // Get the first wallet in the account
            ABCWallet *wallet = abcAccount.arrayWallets[0];

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

        } error:^(NSError *error)
        {
            NSLog(@"Argh! Error code: %d. Error string:%@", error.code, error.userInfo[NSLocalizedDescriptionKey]);
        }];

    }

    // Delegate method called when bitcoin is received
    - (void) abcAccountIncomingBitcoin:(ABCWallet *)wallet txid:(NSString *)txid;
    {
        NSLog(@"Yay, my wallet just received bitcoin", wallet.name);
    }
*/

// Number of confirmations before Airbitz considers a transaction confirmed
#define ABCConfirmedConfirmationCount    6

// Generic logging routine that gets saved in local storage and optionally sent
// to Airbitz to troubleshoot
#define ABCLog(level, format_string,...) \
((abcDebugLog(level, [NSString stringWithFormat:format_string,##__VA_ARGS__])))

#define ABCErrorDomain @"ABCErrorDomain"

void abcDebugLog(int level, NSString *string);
void abcSetDebugLevel(int level);

typedef enum eABCDeviceCaps
{
    ABCDeviceCapsTouchID,
} ABCDeviceCaps;

@class ABCSpend;
@class ABCSettings;
@class ABCRequest;
@class ABCAccount;

@interface AirbitzCore : NSObject

/// -----------------------------------------------------------------------------
/// @name AirbitzCore initialization / free routines
/// -----------------------------------------------------------------------------

/**
 * Initialize the AirbitzCore object. Required for functionality of ABC SDK.
 * @param abcAPIKey NSString* API key obtained from Airbitz Inc.
 * @param hbitsKey (Optional) unique key used to encrypt private keys for use as implementation
 * specific "gift cards" that are only redeemable by applications using this implementation.
 * @return AirbitzCore* Instance of AirbitzCore object
 */
- (id)init:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey;
- (id)init:(NSString *)abcAPIKey;

/**
 * Free the AirbitzCore object.
 */
- (void)free;



#pragma mark - Account Management
/// -----------------------------------------------------------------------------
/// @name Account Management
/// -----------------------------------------------------------------------------

/** Create an Airbitz account with specified username, password, and PIN with 
 * callback handler
 * @param username NSString*
 * @param password NSString*
 * @param pin NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param completionHandler (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCAccount* Account object.<br>
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return void
 */
- (void)createAccount:(NSString *)username
             password:(NSString *)password
                  pin:(NSString *)pin
             delegate:(id)delegate
             complete:(void (^)(ABCAccount *account)) completionHandler
                error:(void (^)(NSError *)) errorHandler;


/** Create an Airbitz account with specified username, password, and PIN.
 * @param username NSString*
 * @param password NSString*
 * @param pin NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param error NSError** May be set to nil. Only used when not using completion handler
 * @return ABCAccount* Account object or nil if failure. 
 */
- (ABCAccount *)createAccount:(NSString *)username
                     password:(NSString *)password
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(NSError **)error;

/**
 * Sign In to an Airbitz account.
 * @param username NSString*
 * @param password NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param otp NSString* One Time Password token (optional). Send nil if logging in w/o OTP token
 *  or if OTP token has already been saved in this account from prior login
 * @param resetDate NSDate** If login fails due to invalid or unset OTP key, and an OTP reset has been
 * @param error NSError** May be set to nil. Only used when not using completion handler
 * @param completionHandler (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCAccount* Account object created from SignIn call
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*<br>
 * - *param* NSDate* resetDate If login fails due to invalid or unset OTP key, and an OTP reset has been
 *  requested, the data that the reset will occur will be returned in this argument
 * @return ABCAccount* Account object or nil if failure. Return void if using completion
 *  handler
 */
- (void)signIn:(NSString *)username
      password:(NSString *)password
      delegate:(id)delegate
           otp:(NSString *)otp
      complete:(void (^)(ABCAccount *account)) completionHandler
         error:(void (^)(NSError *, NSDate *resetDate)) errorHandler;
- (ABCAccount *)signIn:(NSString *)username
              password:(NSString *)password
              delegate:(id)delegate
                   otp:(NSString *)otp
             resetDate:(NSDate **)resetDate
                 error:(NSError **)error;

/**
 * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
 * been logged into using a full username & password
 * @param username NSString*
 * @param pin NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param error NSError** May be set to nil. Only used when not using completion handler
 * @param completionHandler (Optional) Code block called on success.<br>
 * - *param* ABCAccount* User object.
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 *  requested, the data that the reset will occur will be returned in this argument
 * @return ABCAccount* Account object or nil if failure. Return void if using completion
 *  handler
 */
- (void)signInWithPIN:(NSString *)username
                  pin:(NSString *)pin
             delegate:(id)delegate
             complete:(void (^)(ABCAccount *user)) completionHandler
                error:(void (^)(NSError *)) errorHandler;
- (ABCAccount *)signInWithPIN:(NSString *)username
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(NSError **)error;

/**
 * Log in a user using recovery answers. Will only succeed if user has recovery questions and answers
 * set in their account. Use [ABCAccount setupRecoveryQuestions] to set questions and answers
 * @param username NSString*
 * @param answers  NSString* concatenated string of recovery answers separated by '\n' after each answer
 * @param otp NSString* OTP token if needed to login. May be set to nil.
 * @param completionHandler Completion handler code block<br>
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError*<br>
 * - *param* NSDate* resetDate If login fails due to OTP and a reset has been requested, this contains
 *  the date that the reset will occur.
 * @return void
 */
- (void)signInWithRecoveryAnswers:(NSString *)username
                          answers:(NSString *)answers
                         delegate:(id)delegate
                              otp:(NSString *)otp
                         complete:(void (^)(ABCAccount *account)) completionHandler
                            error:(void (^)(NSError *, NSDate *resetDate)) errorHandler;

/**
 * Get ABCAccount object for username if logged in.
 * @param username NSString*
 * @return ABCAccount* if logged in. nil otherwise
 */
- (ABCAccount *) getLoggedInUser:(NSString *)username;

/**
 * Logout the specified ABCAccount object
 * @param abcAccount ABCAccount* user to logout
 * @return void
 */
- (void)logout:(ABCAccount *)abcAccount;

/**
 * Check if specified username has a password on the account or if it is
 * a PIN-only account.
 * @param username NSString* user to check
 * @param error NSError**
 * @return BOOL true if user has a password
 */
- (BOOL)passwordExists:(NSString *)username error:(NSError **)error;

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
+ (BOOL)checkPasswordRules:(NSString *)password
            secondsToCrack:(double *)secondsToCrack
                     count:(unsigned int *)count
           ruleDescription:(NSMutableArray *)ruleDescription
                rulePassed:(NSMutableArray *)rulePassed
       checkResultsMessage:(NSMutableString *)checkResultsMessage;

/**
 * Get a list of previously logged in usernames on this device
 * @param accounts NSMutableArray* array of strings of account names
 * @return NSError* error code
 */
- (NSError *) listLocalAccounts:(NSMutableArray *) accounts;

/**
 * Checks if an account with the specified username exists locally on the current device.
 * This does not check for existence of the account on the entire Airbitz system. If a username
 * was created but never logged into this device, this will return NO.
 * @param username NSString* Username of account to check
 * @return YES if account exists locally, NO otherwise.
 */
- (BOOL)accountExistsLocal:(NSString *)username;

/**
 * Checks if username is available
 * @param username NSString* username to check
 * @return nil if username is available
 */
- (NSError *)isAccountUsernameAvailable:(NSString *)username;

/*
 * Attempts to auto-relogin the specified user if they are within their auto-logout
 * setting (default 1 hour). Should be called upon initial execution of app and when the Login screen
 * reappears after logout or if user selects a different user to login with. If user can 
 * use TouchID to login and they are outside of their auto-logout time period, this will automatically
 * show the TouchID prompt on supported devices and log them in if authenticated.
 * @param username: user account to attempt to relogin
 * @param delegate delegate object for callbacks
 * @param doBeforeLogin: completion handler code block executes before login is attempted
 * @param completionWithLogin: completion handler code block executes if login is successful<br>
 * - *param* ABCAccount* Account object created from SignIn call
 * - *param* BOOL* usedTouchID: TRUE if user used TouchID to login
 * @param completeNoLogin: completion handler code block executes if relogin not attempted
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return void

 
 */
- (void)autoReloginOrTouchIDIfPossible:(NSString *)username
                              delegate:(id)delegate
                         doBeforeLogin:(void (^)(void)) doBeforeLogin
                   completionWithLogin:(void (^)(ABCAccount *account, BOOL usedTouchID)) completionWithLogin
                     completionNoLogin:(void (^)(void)) completionNoLogin
                                 error:(void (^)(NSError *error)) errorHandler;

/**
 * Checks if PIN login is possible for the given username. This checks if
 * there is a local PIN package on the device from a prior login
 * @param username NSString* username to check
 * @param error NSError** (optional) May be set to nil.
 * @return BOOL YES PIN login is possible
 */
- (BOOL)PINLoginExists:(NSString *)username;
- (BOOL)PINLoginExists:(NSString *)username error:(NSError **)error;

/**
 * Deletes named account from local device. Account is recoverable if it contains a password.
 * Use [AirbitzCore passwordExists] to determine if account has a password. Recommend warning
 * user before executing deleteLocalAccount if passwordExists returns FALSE.
 * @param username NSString*  username of account to delete
 * @return NSError* nil if method succeeds
 */
- (NSError *)deleteLocalAccount:(NSString *)username;

/**
 * Returns the NSString* of the last account that was logged into. If that account was deleted,
 * returns the username of another local account. This can be overridden by calling
 * [AirbitzCore setLastAccessedAccount]
 * @return NSString* username of last account
 */
- (NSString *) getLastAccessedAccount;

/**
 * Overrides the cached account name returned by [AirbitzCore getLastAccessedAccount]
 * @param username NSString* username
 */
- (void) setLastAccessedAccount:(NSString *) username;

#pragma mark - Account Recovery
/// -----------------------------------------------------------------------------
/// @name Account Recovery
/// -----------------------------------------------------------------------------

/**
 * Gets the recovery questions set for the specified username. Questions are
 * returned as an NSArray of NSString*. Recovery questions need to have been previously set
 * with a call to [ABCAccount setupRecoveryQuestions]
 * @param username NSString* username to query
 * @return NSArray* Array of questions in NSString format. Returns nil if no questions
 * have been set.
 */
- (NSArray *)getRecoveryQuestionsForUserName:(NSString *)username
                                       error:(NSError **)error;
/**
 * Gets a list of recovery questions to ask user. These are suggested questions from the Airbitz
 * servers, but app is free to choose its own to present the user.
 * @param complete completion handler code block which is called with the following args<br>
 * - *param* arrayCategoryString NSMutableString* array of string based questions<br>
 * - *param* arrayCategoryNumeric NSMutableString* array of numeric based questions<br>
 * - *param* arrayCategoryMust NSMutableString* array of questions of which one must have an answer
 * @param error error handler code block which is called with the following args<br>
 * - *param* NSError* error
 * @return void
 */
+ (void)listRecoveryQuestionsChoices: (void (^)(
                                               NSMutableArray *arrayCategoryString,
                                               NSMutableArray *arrayCategoryNumeric,
                                               NSMutableArray *arrayCategoryMust)) completionHandler
                              error:(void (^)(NSError *error)) errorHandler;

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
 * @return NSError*
 */
- (NSError *)setOTPKey:(NSString *)username
                   key:(NSString *)key;

/**
 * Returns an array of usernames of accounts local to device that
 * have a pending OTP reset on the server. 
 * @param error NSError object
 * @return NSArray* of NSString* of usernames
 */
- (NSArray *)listPendingOTPResetUsernames:(NSError **)error;

/**
 * Launches an OTP reset timer on the server,
 * which will disable the OTP authentication requirement when it expires.
 * @param username NSString*
 * (Optional. If used, method returns immediately with void)
 * @param completionHandler: completion handler code block
 * @param error error handler code block which is called with the following args<br>
 * - *param* NSError* error
 * @return NSError object or nil if success. Return void if using completion
 *  handler
 */
- (void)requestOTPReset:(NSString *)username
               complete:(void (^)(void)) completionHandler
                  error:(void (^)(NSError *error)) errorHandler;
- (NSError *)requestOTPReset:(NSString *)username;

#pragma mark - ABCExchange Calls
/// ------------------------------------------------------------------
/// @name ABCExchange Calls
/// ------------------------------------------------------------------

/**
 * Gets an ABCExchangeCache object for use in doing currency conversion
 * @return ABCExchangeCache*
 */
- (ABCExchangeCache *) exchangeCacheGet;

#pragma mark - System Calls and Queries
/// ------------------------------------------------------------------
/// @name System Calls and Queries
/// ------------------------------------------------------------------

/**
 * Gets the version of AirbitzCore compiled into this implementation
 * @return NSString* Version number if string format. ie. "1.8.5"
 */
- (NSString *)coreVersion;

/**
 * Check if device has a capability from ABCDeviceCaps
 * @return BOOL TRUE if device has specified capability
 */
- (BOOL) hasDeviceCapability:(ABCDeviceCaps) caps;

/**
 * Returns TRUE if AirbitzCore is compiled for testnet
 * @return BOOL
 */
- (bool) isTestNet;

/**
 * Call this routine from within applicationDidEnterBackground to have ABC
 * spin down any background queues
 */
- (void) enterBackground;


/**
 * Call this routine from within applicationDidEnterBackground to have ABC
 * spin up any background queues
 */
- (void) enterForeground;

/**
 * Call this routine when application loses network connectibity to have ABC
 * prevent repeated network calls
 */
- (void)restoreConnectivity;

/**
 * Call this routine when application re-gains network connectibity to have ABC
 * re-initiate networking
 */
- (void)lostConnectivity;

/*
 * Uploads AirbitzCore debug log with optional message from user.
 * @param userText NSString* text to send to support staff
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param complete completion handler code block which is called with void
 * @param error error handler code block which is called with the following args<br>
 * - *param* NSError* error
 * @return NSError object or nil if success. Return void if using completion
 *  handler
 */
- (NSError *)uploadLogs:(NSString *)userText;
- (void)uploadLogs:(NSString *)userText
          complete:(void(^)(void))completionHandler
             error:(void (^)(NSError *error)) errorHandler;


#pragma mark - Utility Methods
/// ------------------------------------------------------------------
/// @name Utility methods
/// ------------------------------------------------------------------

/**
 * Transforms a username into the internal format used for hashing.
 * This collapses spaces, converts to lowercase,
 * and checks for invalid characters.
 */
+ (NSString *)fixUsername:(NSString *)username error:(NSError **)error;

/**
 * Encodes a string into a QR code returned as UIImage *
 * @param string NSString* string to encode
 * @return UIImage* returned image
 */
+ (UIImage *)encodeStringToQRImage:(NSString *)string error:(NSError **)error;

///**
// * Given a currency code, returns the 3 digit currency code. ie. "USD, CAD, EUR"
// * @param currencyNum int - ISO currency num to lookup
// * @return NSString* 3 digit ISO currency code
// */
//- (NSString *)currencyAbbrevLookup:(int)currencyNum;
//
///**
// * Given a currency code, returns the currency symbol. ie "$"
// * @param currencyNum int - ISO currency num to lookup
// * @return NSString* symbol
// */
//- (NSString *)currencySymbolLookup:(int)currencyNum;
//
/// ------------------------------------------------------------------
/// @name Class methods to retrieve constant parameters from ABC
/// ------------------------------------------------------------------

+ (int) getMinimumUsernamedLength;
+ (int) getMinimumPasswordLength;
+ (int) getMinimumPINLength;




@end
