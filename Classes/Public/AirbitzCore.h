//
// AirbitzCore.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "ABCAccount.h"
#import "ABCCategories.h"
#import "ABCConditionCode.h"
#import "ABCCurrency.h"
#import "ABCDataStore.h"
#import "ABCDenomination.h"
#import "ABCExchangeCache.h"
#import "ABCKeychain.h"
#import "ABCMetaData.h"
#import "ABCReceiveAddress.h"
#import "ABCSettings.h"
#import "ABCSpend.h"
#import "ABCTransaction.h"
#import "ABCTxInOut.h"
#import "ABCUtil.h"
#import "ABCWallet.h"

/**
 AirbitzCore (ABC) is a client-side blockchain and Edge Security SDK providing auto-encrypted
 and auto-backed up accounts and wallets with zero-knowledge security and privacy. 
 All blockchain/bitcoin private and public keys are fully encrypted by the users' credentials
 before being backed up on to peer to peer servers. ABC allows developers to create new
 Airbitz wallet accounts or login to pre-existing accounts. Account encrypted data is
 automatically synchronized between all devices and apps using the Airbitz SDK. This allows a
 third party application to generate payment requests or send funds for the users' account
 that may have been created on the Airbitz Mobile Bitcoin Wallet or any other Airbitz SDK
 application. 
 
 In addition, the ABCDataStore object in the Airbitz ABCAccount object allows developers to
 store arbitrary Edge-Secured data on the user's account which is automatically encrypted,
 automatically backed up, and automatically synchronized between the user's authenticated 
 devices.

    // Global account object
    ABCAccount *gAccount;

    - (void) exampleMethod
    {
        // Create an account
        AirbitzCore *abc  = [[AirbitzCore alloc] init:@"YourAPIKeyHere"];
        ABCAccount *abcAccount = [abc createAccount:@"myusername" password:@"MyPa55w0rd!&" pin:@"4283" delegate:self error:nil];
        // New account is auto logged in after creation

        // Use Airbitz Edge Security to write encrypted/backed up/synchronized data to the account
        [gAccount.dataStore dataWrite:@"myAppUserInfo" withKey:@"user_email" withValue:@"theuser@hisdomain.com"];

        // Read back the data
        NSMutableString *usersEmail = [[NSMutableString alloc] init];
        [gAccount.dataStore dataRead:@"myAppUserInfo" withKey:@"user_email" data:usersEmail];

        // usersEmail now contains "theuser@hisdomain.com"

        // Create a wallet in the user account
        ABCWallet *wallet = [abcAccount createWallet:@"My Awesome Wallet" currency:nil];

        // Logout
        [abc logout:abcAccount];

        // Log back in with full credentials
        abcAccount = [abc signIn:@"myusername" password:@"MyPa55w0rd!&" delegate:self error:nil];

        // Logout
        [abc logout:abcAccount];

        // Log back in with PIN using completion handler codeblock
        [abc signInWithPIN:@"myusername" pin:@"4283" delegate:self complete:^(ABCAccount *account)
        {
            gAccount = account;

        } error:^(NSError *error) {
            NSLog(@"Argh! Error code: %d. Error string:%@", (int)error.code, error.userInfo[NSLocalizedDescriptionKey]);
        }];

    }

    // Delegate method called when wallets are loaded after a signIn
    - (void) abcAccountWalletsLoaded
    {
        // Get the first wallet in the account
        ABCWallet *wallet = gAccount.arrayWallets[0];

        // Create a bitcoin request
        ABCReceiveAddress *request = [wallet createNewReceiveAddress];

        // Put in some optional meta data into this request so incoming funds are automatically tagged
        request.metaData.payeeName     = @"William Swanson"; // Name of the person receiving request
        request.metaData.category      = @"Income:Rent";     // Category of payment. Auto tags category when funds come in
        request.metaData.notes         = @"Rent payment for Jan 2016";

        // Put in an optional request amount and use fiat exchange rate conversion methods
        request.amountSatoshi          = [gAccount.exchangeCache currencyToSatoshi:5.00 currencyCode:@"USD" error:nil];

        // Use the request results
        NSString *bitcoinAddress = request.address;
        NSString *bitcoinURI     = request.uri;
        UIImage  *bitcoinQRCode  = request.qrCode;

        // Now go and display the QR code or send payment to address in some other way.
    }

    // Delegate method called when bitcoin is received
    - (void) abcAccountIncomingBitcoin:(ABCWallet *)wallet txid:(NSString *)txid;
    {
        NSLog(@"Yay, my wallet just received bitcoin");
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
@class ABCReceiveAddress;
@class ABCAccount;
@class ABCPasswordRuleResult;

@interface AirbitzCore : NSObject

/// -----------------------------------------------------------------------------
/// @name AirbitzCore initialization / free routines
/// -----------------------------------------------------------------------------

/**
 * Initialize the AirbitzCore object. Required for functionality of ABC SDK.
 * @param abcAPIKey NSString* API key obtained from Airbitz Inc.
 * @param hbitsKey (Optional) unique key used to encrypt private keys for use as implementation
 * specific "gift cards" that are only redeemable by applications using this implementation.
 * @return AirbitzCore Instance of AirbitzCore object
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

/** 
 * Create an Airbitz account with specified username, password, and PIN with
 * callback handler
 * @param username NSString
 * @param password NSString
 * @param pin NSString
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param completionHandler (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCAccount Account object.<br>
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError
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
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)createAccount:(NSString *)username
                     password:(NSString *)password
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(NSError **)error;

/**
 * Sign In to an Airbitz account using completion handlers.
 * @param username NSString
 * @param password NSString
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param otp NSString One Time Password token (optional). Send nil if logging in w/o OTP token
 *  or if OTP token has already been saved in this account from prior login
 * @param completionHandler (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCAccount Account object created from SignIn call
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError<br>
 * - *param* NSDate otpResetDate If login fails due to invalid or unset OTP key, and an OTP reset has been
 *  requested, the data that the reset will occur will be returned in this argument<br>
 * - *param* NSString otpResetToken. If login fails due to OTP set on this account, use this token
 *  in requestOTPReset to request a reset of OTP. The reset will take 7 days
 * @return void
 */
- (void)signIn:(NSString *)username
      password:(NSString *)password
      delegate:(id)delegate
           otp:(NSString *)otp
      complete:(void (^)(ABCAccount *account)) completionHandler
         error:(void (^)(NSError *, NSDate *otpResetDate, NSString *otpResetToken)) errorHandler;

/**
 * Sign In to an Airbitz account.
 * @param username NSString
 * @param password NSString
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param error NSError May be set to nil. Only used when not using completion handler
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)signIn:(NSString *)username
              password:(NSString *)password
              delegate:(id)delegate
                 error:(NSError **)error;

/**
 * Sign In to an Airbitz account. This routine allows caller to receive back an otpResetToken
 * which is used with [AirbitzCore requestOTPReset] to remove OTP from the specified account.
 * The otpResetToken is only returned if the caller has provided the correct username and password
 * but the account had OTP enabled. In such case, signIn will also provide an otpResetDate which is
 * the date when the account OTP will be disabled if a prior OTP reset was successfully requested.
 * The reset date is set to 7 days from when a reset was initially requested.
 * @param username NSString
 * @param password NSString
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param otp NSString* One Time Password token (optional). Send nil if logging in w/o OTP token
 *  or if OTP token has already been saved in this account from prior login
 * @param otpResetToken NSMutableString A reset token to be used to request disabling of OTP for
 *  this account.
 * @param otpResetDate NSDate Date which the account reset will occur
 * @param error NSError May be set to nil. Only used when not using completion handler
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)signIn:(NSString *)username
              password:(NSString *)password
              delegate:(id)delegate
                   otp:(NSString *)otp
         otpResetToken:(NSMutableString *)otpResetToken
          otpResetDate:(NSDate **)otpResetDate
                 error:(NSError **)error;

/**
 * Sign In to an Airbitz account with PIN using completion handlers. Used to sign into 
 * devices that have previously been logged into using a full username & password
 * @param username NSString*
 * @param pin NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param completionHandler (Optional) Code block called on success.<br>
 * - *param* ABCAccount User object.
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 *  requested, the data that the reset will occur will be returned in this argument
 * @return void
 */
- (void)signInWithPIN:(NSString *)username
                  pin:(NSString *)pin
             delegate:(id)delegate
             complete:(void (^)(ABCAccount *user)) completionHandler
                error:(void (^)(NSError *)) errorHandler;


/**
 * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
 * been logged into using a full username & password
 * @param username NSString*
 * @param pin NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param error NSError** May be set to nil. Only used when not using completion handler
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)signInWithPIN:(NSString *)username
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(NSError **)error;

/**
 * Log in a user using recovery answers. Will only succeed if user has recovery questions and answers
 * set in their account. Use [ABCAccount setupRecoveryQuestions] to set questions and answers
 * @param username NSString*
 * @param answers  NSString* concatenated string of recovery answers separated by '\n' after each answer
 * @param delegate Delegate owner to handle ABCAccount delegate callbacks
 * @param otp NSString* OTP token if needed to login. May be set to nil.
 * @param completionHandler Completion handler code block<br>
 * - *param* ABCAccount Returned account object logged in.
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError*<br>
 * - *param* NSDate* resetDate If login fails due to OTP and a reset has been requested, this contains
 *  the date that the reset will occur.<br>
 * - *param* NSString* OTP reset token. If login fails due to OTP set on this account, use this token
 * @return void
 */
- (void)signInWithRecoveryAnswers:(NSString *)username
                          answers:(NSString *)answers
                         delegate:(id)delegate
                              otp:(NSString *)otp
                         complete:(void (^)(ABCAccount *account)) completionHandler
                            error:(void (^)(NSError *, NSDate *resetDate, NSString *resetToken)) errorHandler;

/**
 * Get ABCAccount object for username if logged in.
 * @param username NSString*
 * @return ABCAccount if logged in. nil otherwise
 */
- (ABCAccount *) getLoggedInUser:(NSString *)username;

/**
 * Logout the specified ABCAccount object
 * @param abcAccount ABCAccount user to logout
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

/** 
 * Checks a password for valid entropy looking for correct minimum
 * requirements such as upper, lowercase letters, numbers, and # of digits. This should be used
 * by app to give feedback to user before creating a new account.
 * @param password NSString* Password to check
 * @return ABCPasswordRuleResult* Results of password check. 
 */
+ (ABCPasswordRuleResult *)checkPasswordRules:(NSString *)password;

/**
 * Get a list of previously logged in usernames on this device
 * @param accounts NSMutableArray* array of strings of account names
 * @return NSError* error code
 */
- (NSError *) listLocalAccounts:(NSMutableArray *) accounts;

/**
 * Checks if an account with the specified username exists locally on the current device.
 * This does not check for existence of the account on the entire Airbitz system. If a username
 * was created but never logged into this device, this will return NO. This routine
 * does not require network connectivity to operate.
 * @param username NSString* Username of account to check
 * @return YES if account exists locally, NO otherwise.
 */
- (BOOL)accountExistsLocal:(NSString *)username;

/**
 * Checks if username is available on the global Airbitz username space. This requires
 * network connectivity to function.
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
 * - *param* ABCAccount Account object created from SignIn call
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
- (BOOL)PINLoginExists:(NSString *)username error:(NSError **)error;
- (BOOL)PINLoginExists:(NSString *)username;

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
 * returned as an NSArray of NSString. Recovery questions need to have been previously set
 * with a call to [ABCAccount setupRecoveryQuestions]
 * @param username NSString* username to query
 * @param error NSError** May be set to nil. 
 * @return NSArray* Array of questions in NSString format. Returns nil if no questions
 * have been set.
 */
- (NSArray *)getRecoveryQuestionsForUserName:(NSString *)username
                                       error:(NSError **)error;
/**
 * Gets a list of recovery questions to ask user. These are suggested questions from the Airbitz
 * servers, but app is free to choose its own to present the user.
 * @param completionHandler Completion handler code block which is called with the following args<br>
 * - *param* arrayCategoryString NSMutableString* array of string based questions<br>
 * - *param* arrayCategoryNumeric NSMutableString* array of numeric based questions<br>
 * - *param* arrayCategoryMust NSMutableString* array of questions which cannot be answered via 
 *  information from public records
 * @param errorHandler Error handler code block which is called with the following args<br>
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
 * Associates an OTP key with the given username. An OTP key can be retrieved from
 * a previously logged in account using [ABCAccount getOTPLocalKey]. The account
 * must have had OTP enabled by using [ABCAccount setOTPAuth]
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
 * @param token NSString* Reset token returned by the signIn... routines
 * if sign in failes due to missing or incorrect OTP.
 * (Optional. If used, method returns immediately with void)
 * @param completionHandler Completion handler code block
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error
 * @return NSError object or nil if success. Return void if using completion
 *  handler
 */
- (void)requestOTPReset:(NSString *)username token:(NSString *)token
               complete:(void (^)(void)) completionHandler
                  error:(void (^)(NSError *error)) errorHandler;
- (NSError *)requestOTPReset:(NSString *)username token:(NSString *)token;

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
 * @param caps ABCDeviceCaps
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
 * @param completionHandler Completion handler code block which is called with void
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error
 * @return NSError object or nil if success. Return void if using completion
 *  handler
 */
- (void)uploadLogs:(NSString *)userText
          complete:(void(^)(void))completionHandler
             error:(void (^)(NSError *error)) errorHandler;
- (NSError *)uploadLogs:(NSString *)userText;


#pragma mark - Utility Methods
/// ------------------------------------------------------------------
/// @name Utility methods
/// ------------------------------------------------------------------

/**
 * Transforms a username into the internal format used for hashing.
 * This collapses spaces, converts to lowercase,
 * and checks for invalid characters.
 * @param username NSString* Username to fix
 * @param error NSError** May be set to nil.
 * @return NSString* Fixed username with text lowercased, leading and
 * trailing white space removed, and all whitespace condensed to one space.
 */
+ (NSString *)fixUsername:(NSString *)username error:(NSError **)error;

/// ------------------------------------------------------------------
/// @name Class methods to retrieve constant parameters from ABC
/// ------------------------------------------------------------------

/**
 * Get the minimum allowable length of a username for new accounts
 * @return int Minimum length
 */
+ (int) getMinimumUsernamedLength;


/**
 * Get the minimum allowable length of a password for accounts
 * @return int Minimum length
 */
+ (int) getMinimumPasswordLength;

/**
 * Get the minimum allowable length of a PIN for accounts
 * @return int Minimum length
 */
+ (int) getMinimumPINLength;

@end


/// -----------------------------------------------------------------------------
/// @name ABCPasswordRuleResult struct/object
/// -----------------------------------------------------------------------------

/// Object returned by checkPasswordRules to determine if password meets the minimum
/// entropy requirements
@interface ABCPasswordRuleResult : NSObject

/// Estimated number of seconds to crack encryption based on this password on a
/// current desktop computer
@property       double      secondsToCrack;

/// Password does not meet minimum lenght requrements (10 characters)
@property       BOOL        tooShort;

/// Password must have at least one number
@property       BOOL        noNumber;

/// Password must have an upper case letter
@property       BOOL        noUpperCase;

/// Password must have a lower case letter
@property       BOOL        noLowerCase;

/// Password has passed all the tests
@property       BOOL        passed;
@end


