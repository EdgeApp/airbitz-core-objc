//
// ABCContext.h
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
#import "ABCError.h"
#import "ABCExchangeCache.h"
#import "ABCKeychain.h"
#import "ABCMetaData.h"
#import "ABCReceiveAddress.h"
#import "ABCSettings.h"
#import "ABCSpend.h"
#import "ABCStrings.h"
#import "ABCTransaction.h"
#import "ABCTxInOut.h"
#import "ABCUtil.h"
#import "ABCWallet.h"

/**
 * The ABCContext object is the starting point in accessing the entire Airbitz SDK. ABCContext should
 * first be initialized using init. From here, developers can create and login to accounts which will
 * return an ABCAccount object representing a logged in account. Within each account, you can create
 * ABCWallet objects using createWallet. Each ABCWallet represents a single BIP32 HD chain of addresses which don't cross
 * over to other wallets. ABCWallets contain ABCTransaction objects representing each incoming or outgoing
 * transaction.
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

@interface ABCContext : NSObject

/// -----------------------------------------------------------------------------
/// @name ABCContext initialization / free routines
/// -----------------------------------------------------------------------------

/**
 * Initialize the ABCContext object. Required for functionality of ABC SDK.
 * @param abcAPIKey NSString* API key obtained from Airbitz Inc.
 * @param hbitsKey (Optional) unique key used to encrypt private keys for use as implementation
 * specific "gift cards" that are only redeemable by applications using this implementation.
 * @return ABCContext Instance of ABCContext object
 */
+ (ABCContext *)makeABCContext:(NSString *)abcAPIKey;
+ (ABCContext *)makeABCContext:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey;

/**
 * Free the ABCContext object.
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
             callback:(void (^)(ABCError *, ABCAccount *account)) callback;


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
                        error:(ABCError **)error;

/**
 * Login to an Airbitz account using completion handlers.
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
- (void)loginWithPassword:(NSString *)username
             password:(NSString *)password
             delegate:(id)delegate
                  otp:(NSString *)otp
             callback:(void (^)(ABCError *error, ABCAccount *account)) callback;

/**
 * Login to an Airbitz account.
 * @param username NSString
 * @param password NSString
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param error ABCError May be set to nil. Only used when not using completion handler
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)loginWithPassword:(NSString *)username
                     password:(NSString *)password
                     delegate:(id)delegate
                        error:(ABCError **)error;

/**
 * Login to an Airbitz account. This routine allows caller to receive back an otpResetToken
 * which is used with [ABCContext requestOTPReset] to remove OTP from the specified account.
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
 * @param error ABCError May be set to nil. Only used when not using completion handler
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)loginWithPassword:(NSString *)username
                     password:(NSString *)password
                     delegate:(id)delegate
                          otp:(NSString *)otp
                        error:(ABCError **)error;

/**
 * Login to an Airbitz account with PIN using completion handlers. Used to sign into
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
- (void)pinLogin:(NSString *)username
                  pin:(NSString *)pin
             delegate:(id)delegate
             complete:(void (^)(ABCAccount *user)) completionHandler
                error:(void (^)(ABCError *)) errorHandler;


/**
 * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
 * been logged into using a full username & password
 * @param username NSString*
 * @param pin NSString*
 * @param delegate ABCAccountDelegate object for callbacks. May be set to nil;
 * @param error NSError** May be set to nil. Only used when not using completion handler
 * @return ABCAccount Account object or nil if failure.
 */
- (ABCAccount *)pinLogin:(NSString *)username
                          pin:(NSString *)pin
                     delegate:(id)delegate
                        error:(ABCError **)error;

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
- (void)recoveryLogin:(NSString *)username
                          answers:(NSString *)answers
                         delegate:(id)delegate
                              otp:(NSString *)otp
                         complete:(void (^)(ABCAccount *account)) completionHandler
                            error:(void (^)(ABCError *, NSDate *resetDate, NSString *resetToken)) errorHandler;

- (void)loginWithRecovery2:(NSString *)username
                   answers:(NSArray *)answers
             recoveryToken:(NSString *)recoveryToken
                  delegate:(id)delegate
                       otp:(NSString *)otp
                  callback:(void (^)(ABCError *error, ABCAccount *account)) callback;

- (ABCAccount *)loginWithRecovery2:(NSString *)username
                           answers:(NSArray *)answers
                     recoveryToken:(NSString *)recoveryToken
                          delegate:(id)delegate
                               otp:(NSString *)otp
                             error:(ABCError **)error;

/**
 *
 */

/**
 * Get ABCAccount object for username if logged in.
 * @param username NSString*
 * @return ABCAccount if logged in. nil otherwise
 */
- (ABCAccount *) getLoggedInUser:(NSString *)username;

/**
 * Check if specified username has a password on the account or if it is
 * a PIN-only account.
 * @param username NSString* user to check
 * @param error NSError**
 * @return BOOL true if user has a password
 */
- (BOOL)accountHasPassword:(NSString *)username error:(ABCError **)error;

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
- (NSArray *) listUsernames:(ABCError **) error;

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
- (ABCError *)usernameAvailable:(NSString *)username;

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
                                 error:(void (^)(ABCError *error)) errorHandler;

/**
 * Checks if PIN login is possible for the given username. This checks if
 * there is a local PIN package on the device from a prior login
 * @param username NSString* username to check
 * @param error NSError** (optional) May be set to nil.
 * @return BOOL YES PIN login is possible
 */
- (BOOL)pinLoginEnabled:(NSString *)username error:(ABCError **)error;
- (BOOL)pinLoginEnabled:(NSString *)username;

/**
 * Deletes named account from local device. Account is recoverable if it contains a password.
 * Use [ABCContext accountHasPassword] to determine if account has a password. Recommend warning
 * user before executing deleteLocalAccount if accountHasPassword returns FALSE.
 * @param username NSString*  username of account to delete
 * @return NSError* nil if method succeeds
 */
- (ABCError *)deleteLocalAccount:(NSString *)username;

/**
 * Returns the NSString* of the last account that was logged into. If that account was deleted,
 * returns the username of another local account. This can be overridden by calling
 * [ABCContext setLastAccessedAccount]
 * @return NSString* username of last account
 */
- (NSString *) getLastAccessedAccount;

/**
 * Overrides the cached account name returned by [ABCContext getLastAccessedAccount]
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
                                       error:(ABCError **)error;

- (NSArray *)getRecovery2Questions:(NSString *)username
                                     recoveryToken:(NSString *)recoveryToken
                                             error:(ABCError **)error;
- (NSString *)getLocalRecoveryToken:(NSString *)username error:(ABCError **)error;

/**
 * Gets a list of recovery questions to ask user. These are suggested questions from the Airbitz
 * servers, but app is free to choose its own to present the user.
 * @return void
 */
+ (void)listRecoveryQuestionChoices: (void (^)(ABCError *error, NSArray *arrayQuestions)) callback;

#pragma mark - OTP Management
/// -----------------------------------------------------------------------------
/// @name OTP (2 Factor Auth) Management
/// -----------------------------------------------------------------------------

/**
 * Returns an array of usernames of accounts local to device that
 * have a pending OTP reset on the server. 
 * @param error ABCError object
 * @return NSArray* of NSString* of usernames
 */
- (NSArray *)listPendingOTPResetUsernames:(ABCError **)error;

/**
 * Checks if the current account has a pending request to reset (disable)
 * OTP.
 * @param username NSString username to check
 * @param error ABCError error object or nil if success
 * @return BOOL YES if account has pending reset
 */
- (BOOL) hasOTPResetPending:(NSString *)username error:(ABCError **)error;

/**
 * Launches an OTP reset timer on the server,
 * which will disable the OTP authentication requirement when it expires.
 * @param username NSString*
 * @param otpResetToken NSString* Reset token returned by the signIn... routines
 * if sign in failes due to missing or incorrect OTP.
 * (Optional. If used, method returns immediately with void)
 * @param callback Code block which is called with the following args<br>
 * - *param* NSError* error
 * @return ABCError object or nil if success. Return void if using callback
 */
- (void)requestOTPReset:(NSString *)username
                  token:(NSString *)otpResetToken
               callback:(void (^)(ABCError *error)) callback;
- (ABCError *)requestOTPReset:(NSString *)username token:(NSString *)token;

#pragma mark - System Calls and Queries
/// ------------------------------------------------------------------
/// @name System Calls and Queries
/// ------------------------------------------------------------------

/**
 * Gets the version of ABCContext compiled into this implementation
 * @return NSString* Version number if string format. ie. "1.8.5"
 */
- (NSString *)getVersion;

/**
 * Check if device has a capability from ABCDeviceCaps
 * @param caps ABCDeviceCaps
 * @return BOOL TRUE if device has specified capability
 */
- (BOOL) hasDeviceCapability:(ABCDeviceCaps) caps;

/**
 * Returns TRUE if ABCContext is compiled for testnet
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
 * Call this routine when application loses and regains network connectibity to have ABC
 * prevent repeated network calls
 * @param hasConnectivity BOOL set to YES when app has connectvity. NO otherwise
 */
- (void)setConnectivity:(BOOL)hasConnectivity;

/*
 * Uploads ABCContext debug log with optional message from user.
 * @param userText NSString* text to send to support staff
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param completionHandler Completion handler code block which is called with void
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error
 * @return ABCError object or nil if success. Return void if using completion
 *  handler
 */
- (void)uploadLogs:(NSString *)userText
          complete:(void(^)(void))completionHandler
             error:(void (^)(ABCError *error)) errorHandler;
- (ABCError *)uploadLogs:(NSString *)userText;


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
+ (NSString *)fixUsername:(NSString *)username error:(ABCError **)error;

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


