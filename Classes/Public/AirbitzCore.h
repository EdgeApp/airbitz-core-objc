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

static const int ABCDenominationBTC  = 0;
static const int ABCDenominationMBTC = 1;
static const int ABCDenominationUBTC = 2;

#define ABC_CONFIRMED_CONFIRMATION_COUNT 6
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
 * @param complete (Optional) Code block called on success. Returns void if used
 * - *param* ABCUser* User object.<br>
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return ABCUser* User object or nil if failuer
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
 * @param otp NSString* One Time Password token (optional) send nil if logging in w/o OTP token
 *                       or if OTP token has already been saved in this account from prior login
 * @param complete (Optional) Code block called on success. Returns void if used
 * - *param* ABCUser* User object.<br>
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 */
- (ABCUser *)signIn:(NSString *)username password:(NSString *)password delegate:(id)delegate otp:(NSString *)otp;
- (void)signIn:(NSString *)username password:(NSString *)password delegate:(id)delegate otp:(NSString *)otp
      complete:(void (^)(ABCUser *user)) completionHandler
         error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
 * been logged into using a full username & password
 * @param username NSString*
 * @param pin NSString*
 * @param delegate ABCUserDelegate object for callbacks. May be set to nil;
 * @param complete (Optional) Code block called on success. Returns void if used
 * - *param* ABCUser* User object.<br>
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 */
- (ABCUser *)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate;
- (void)signInWithPIN:(NSString *)username pin:(NSString *)pin delegate:(id)delegate
             complete:(void (^)(ABCUser *user)) completionHandler
                error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

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
 * @param completeWithLogin: completion handler code block executes if login is successful
 * - *param* ABCUser* User object
 * - *param* BOOL* usedTouchID: TRUE if user used TouchID to login
 * @param completeNoLogin: completion handler code block executes if relogin not attempted
 * @param errorHandler: error handler code block which is called if relogin attempted but failed
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

#pragma mark - OTP Management
/// -----------------------------------------------------------------------------
/// @name OTP (2 Factor Auth) Management
/// -----------------------------------------------------------------------------

/**
 * Associates an OTP key with the given username.
 * This will not write to disk until the user has successfully logged in
 * at least once.
 * @param NSString* username: user to set the OTP key for
 * @param NSString*      key: key to set
 * @return ABCConditionCode
 */
- (ABCConditionCode)setOTPKey:(NSString *)username
                          key:(NSString *)key;

/**
 * getOTPResetDateForLastFailedAccountLogin
 *
 * Returns the OTP reset date for the last account that failed to log in,
 * if any. Returns an empty string otherwise.
 * @param NSDate   **date: pointer to NSDate for return value date
 * @return ABCConditionCode
 */
- (ABCConditionCode)getOTPResetDateForLastFailedAccountLogin:(NSDate **)date;

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
- (ABCConditionCode)requestOTPReset:(NSString *)username;
- (ABCConditionCode)requestOTPReset:(NSString *)username
                           complete:(void (^)(void)) completionHandler
                              error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * encodeStringToQRImage
 * Encodes a string into a QR code returned as UIImage *
 *
 * @param     NSString*   string: string to encode
 * @param     UIImage**    image: returned image
 * @return ABCConditionCode
 */
- (ABCConditionCode)encodeStringToQRImage:(NSString *)string
                                    image:(UIImage **)image;


/**
 * PINLoginExists
 * Checks if PIN login is possible for the given username. This checks if
 * there is a local PIN package on the device from a prior login
 *
 * @param     NSString   *username: username to check
 * @return    BOOL: YES if username is available
 */
- (BOOL)PINLoginExists:(NSString *)username;

- (NSString *) getLastAccessedAccount;
- (void) setLastAccessedAccount:(NSString *) account;


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

/*
 * accountDeleteLocal
 *      Deletes named account from local device. Account is recoverable if it contains a password
 * @param NSString* username: username of account to delete
 *
 * @return ABCConditionCode
 */
- (ABCConditionCode)accountDeleteLocal:(NSString *)username;


/*
 * @param NSString* username: username
 * @param NSString* strAnswers: concatenated string of recovery answers separated by '\n' after each answer
 *
 * @param complete: completion handler code block which is called with void
 * @param error: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */
- (void)checkRecoveryAnswers:(NSString *)username answers:(NSString *)strAnswers otp:(NSString *)otp
                    complete:(void (^)(BOOL validAnswers)) completionHandler
                       error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/*
 * getRecoveryQuestionsChoices
 * @param complete: completion handler code block which is called with the following args
 *                          @param NSMutableString  arrayCategoryString:  array of string based questions
 *                          @param NSMutableString  arrayCategoryNumeric: array of numeric based questions
 *                          @param NSMutableString  arrayCategoryMust:    array of questions of which one must have an answer
 * @param error: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return void
 */
- (void)getRecoveryQuestionsChoices: (void (^)(
        NSMutableArray *arrayCategoryString,
        NSMutableArray *arrayCategoryNumeric,
        NSMutableArray *arrayCategoryMust)) completionHandler
                              error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Returns TRUE if AirbitzCore is compiled for testnet
 * @return BOOL
 */
- (bool)isTestNet;


/*
 * getLocalAccounts
 *      Get a list of previously logged in usernames on this device
 * @param  accounts NSMutableArray* array of strings of account names
 * @return ABCConditionCode error code
 */
- (ABCConditionCode) getLocalAccounts:(NSMutableArray *) accounts;

- (ABCConditionCode) getLastConditionCode;
- (NSString *) getLastErrorString;
- (BOOL) hasDeviceCapability:(ABCDeviceCaps) caps;

+ (int) getMinimumUsernamedLength;
+ (int) getMinimumPasswordLength;
+ (int) getMinimumPINLength;
+ (int) getDefaultCurrencyNum;


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



@end
