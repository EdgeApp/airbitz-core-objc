//
//  ABCUser.h
//  Airbitz
//

#import "AirbitzCore.h"

@class AirbitzCore;
@class ABCSpend;
@class ABCSettings;
@class ABCRequest;
@class ABCTransaction;

@interface BitidSignature : NSObject
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *signature;
@end

/// @name ABCUser Delegate callbacks

@protocol ABCUserDelegate <NSObject>

@optional

/// Password has been changed by a remote device. User will be able to login on current device
/// with old password. One user logs in with new password, old password will cease to function.
- (void) abcUserRemotePasswordChange;

/// User has been logged out. Always called after [ABCUser logout] once Core has finished logout
/// Also called under some error conditions such as corrupt local data.
- (void) abcUserLoggedOut:(ABCUser *)user;

/// Account details such as settings have changed
- (void) abcUserAccountChanged;

/// Specific wallet has changed. Changes may include new transactions or modified metadata
- (void) abcUserWalletChanged:(ABCWallet *)wallet;

/// Called when the wallets in the account are still loading their prior transactions.
- (void) abcUserWalletsLoading;

/// At minimum, the primary wallet has finished loading. Other wallets may still be loading
- (void) abcUserWalletsLoaded;

/// Wallets in the account have changed. Changes may include new wallet order or wallet names.
- (void) abcUserWalletsChanged;

/// Account has had OTP enabled on another device. GUI should ask user to add OTP key from
/// OTP authenticated device.
- (void) abcUserOTPRequired;

/// Current OTP token on device does not match server OTP token. Token may have been changed by another
/// device or user's time clock is skewed.
- (void) abcUserOTPSkew;

- (void) abcUserExchangeRateChanged; // XXX remove me and move to GUI
- (void) abcUserBlockHeightChanged;

/// This device has just sync'ed a transaction to the specified wallet from another device
/// causing a change in balance. This happens if two devices share a wallet. First device will see
/// abcUserIncomingBitcoin. The second device will see abcUserBalanceUpdate
- (void) abcUserBalanceUpdate:(ABCWallet *)wallet txid:(NSString *)txid;

/// The specified wallet has just received a new transaction with given txid.
- (void) abcUserIncomingBitcoin:(ABCWallet *)wallet txid:(NSString *)txid;

@end

@interface ABCUser : NSObject

/// @name AirbitzCore read/write public object variables

/// Delegate object to handle delegate callbacks
@property (assign)            id<ABCUserDelegate>    delegate;

/// ABC settings that can be set or viewed by app or ABC. Use method [ABCSettings loadSettings]
/// to make sure they are loaded and [ABCSettings saveSettings] to ensure modified settings are latched
@property (atomic, strong) ABCSettings               *settings;

/// @name AirbitzCore read-only public object variables

/// Array of Wallet objects currently loaded into account. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayWallets;

/// Array of archived Wallet objects currently loaded into account. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayArchivedWallets;

/// Array of NSString * wallet names. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayWalletNames;

@property (atomic, strong) ABCWallet                 *currentWallet;
@property (atomic, strong) NSArray                   *arrayCategories;
@property (atomic)         int                       currentWalletID;
@property (atomic)         BOOL                      bAllWalletsLoaded;
@property (atomic)         int                       numWalletsLoaded;
@property (atomic)         int                       numTotalWallets;
@property (atomic)         int                       numCategories;

@property (atomic, copy)     NSString                *name;
@property (atomic, copy)     NSString                *password;





// New methods
- (void)reorderWallets: (NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;
- (void)makeCurrentWallet:(ABCWallet *)wallet;
- (void)makeCurrentWalletWithIndex:(NSIndexPath *)indexPath;
- (void)makeCurrentWalletWithUUID:(NSString *)strUUID;
- (ABCWallet *)selectWalletWithUUID:(NSString *)strUUID;
- (void)addCategory:(NSString *)strCategory;
- (void)loadCategories;
- (void)saveCategories:(NSMutableArray *)saveArrayCategories;
- (BOOL) isLoggedIn;



- (ABCWallet *)getWallet: (NSString *)walletUUID;

- (bool)setWalletAttributes: (ABCWallet *) wallet;

- (int) currencyDecimalPlaces;
- (NSString *)formatCurrency:(double) currency withCurrencyNum:(int)currencyNum;
- (NSString *)formatCurrency:(double) currency withCurrencyNum:(int)currencyNum withSymbol:(bool)symbol;
- (NSString *)formatSatoshi:(int64_t) bitcoin;
- (NSString *)formatSatoshi:(int64_t) bitcoin withSymbol:(bool) symbol;
- (NSString *)formatSatoshi:(int64_t) bitcoin withSymbol:(bool) symbol cropDecimals:(int) decimals;
- (NSString *)formatSatoshi:(int64_t) bitcoin withSymbol:(bool) symbol forceDecimals:(int) forcedecimals;
- (NSString *)formatSatoshi:(int64_t) bitcoin withSymbol:(bool) symbol cropDecimals:(int) decimals forceDecimals:(int) forcedecimals;
- (int64_t) denominationToSatoshi: (NSString *) amount;
- (NSString *)conversionStringFromNum:(int) currencyNum withAbbrev:(bool) abbrev;
- (BOOL)needsRecoveryQuestionsReminder;
- (BOOL)passwordOk:(NSString *)password;
- (NSString *) bitidParseURI:(NSString *)uri;
- (BOOL) bitidLogin:(NSString *)uri;
- (BitidSignature *) bitidSign:(NSString *)uri msg:(NSString *)msg;


/// -----------------------------------------------------------------------------
/// @name Account Management
/// -----------------------------------------------------------------------------


/*
 * changePassword
 * @param NSString* password: new password for currently logged in user
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param completionHandler: completion handler code block
 * @param errorHandler: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */
- (ABCConditionCode)changePassword:(NSString *)password;
- (ABCConditionCode)changePassword:(NSString *)password
                          complete:(void (^)(void)) completionHandler
                             error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/*
 * changePIN
 * @param NSString* pin: new pin for currently logged in user
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param completionHandler: completion handler code block
 * @param errorHandler: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */
- (ABCConditionCode)changePIN:(NSString *)pin;
- (ABCConditionCode)changePIN:(NSString *)pin
                     complete:(void (^)(void)) completionHandler
                        error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Check if this user has a password on the account or if it is
 * a PIN-only account.
 * @param username NSString* user to check
 * @return BOOL true if user has a password
 */
- (BOOL)passwordExists;

/**
 * Check if this user has logged in "recently". Currently fixed to return TRUE
 * within 120 seconds of login. Useful for requiring less security for spending such as a PIN
 * on spend.
 * @return BOOL
 */
- (BOOL)recentlyLoggedIn;



/// -----------------------------------------------------------------------------
/// @name Wallet Management
/// -----------------------------------------------------------------------------

/*
 * createWallet
 * @param NSString* walletName: set to nil to use default wallet name
 * @param int       currencyNum: ISO currency number for wallet. set to 0 to use defaultCurrencyNum from
 *                               settings or the global default currency number if settings unavailable
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param completionHandler: completion handler code block
 * @param errorHandler: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */
- (ABCWallet *) createWallet:(NSString *)walletName currencyNum:(int) currencyNum;
- (void) createWallet:(NSString *)walletName currencyNum:(int) currencyNum
             complete:(void (^)(void)) completionHandler
                error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;


/*
 * renameWallet
 * @param NSString* walletUUID: UUID of wallet to rename
 * @param NSString*    newName: new name of wallet
 * @return ABCConditionCode
 */
- (ABCConditionCode) renameWallet:(NSString *)walletUUID
                          newName:(NSString *)walletName;

- (ABCConditionCode) createFirstWalletIfNeeded;
- (ABCConditionCode) getNumWalletsInAccount:(int *)numWallets;

- (BOOL)hasOTPResetPending;

/**
 * Gets the locally saved OTP key for the current user.
 * @return key NSString* OTP key
 */
- (NSString *)getOTPLocalKey;

/**
 * setOTPKey
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
 * removeOTPKey
 * Removes the OTP key for current user.
 * This will remove the key from disk as well.
 * @return ABCConditionCode
 */
- (ABCConditionCode)removeOTPKey;

/**
 * getOTPDetails
 * Reads the OTP configuration from the server.
 * This will remove the key from disk as well.
 * @param     bool*  enabled: enabled flag if OTP is enabled for this user
 * @param     long*  timeout: number seconds required after a reset is requested
 * @return ABCConditionCode
 */
- (ABCConditionCode)getOTPDetails:(bool *)enabled
                          timeout:(long *)timeout;

/**
 * setOTPAuth
 * Sets up OTP authentication on the server for currently logged in user
 * This will generate a new token if the username doesn't already have one.
 * @param     long   timeout: number seconds required after a reset is requested
 *                            before OTP is disabled.
 * @return ABCConditionCode
 */
- (ABCConditionCode)setOTPAuth:(long)timeout;

/**
 * removeOTPAuth
 * Removes the OTP authentication requirement from the server for the
 * currently logged in user
 * @return ABCConditionCode
 */
- (ABCConditionCode)removeOTPAuth;

/**
 * getOTPResetDateForLastFailedAccountLogin
 *
 * Returns the OTP reset date for the last account that failed to log in,
 * if any. Returns an empty string otherwise.
 * @param NSDate   **date: pointer to NSDate for return value date
 * @return ABCConditionCode
 */
- (ABCConditionCode)getOTPResetDateForLastFailedAccountLogin:(NSDate **)date;

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
 * removeOTPResetRequest
 * Removes the OTP reset request from the server for the
 * currently logged in user
 * @return ABCConditionCode
 */
- (ABCConditionCode)removeOTPResetRequest;

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
- (ABCConditionCode)uploadLogs:(NSString *)userText
                      complete:(void(^)(void))completionHandler
                         error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/*
 * walletRemove
 * @param NSString* uuid: UUID of wallet to delete
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param complete: completion handler code block which is called with void
 * @param error: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */

- (ABCConditionCode)walletRemove:(NSString *)uuid;
- (ABCConditionCode)walletRemove:(NSString *)uuid
                        complete:(void(^)(void))completionHandler
                           error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/*
 * setRecoveryQuestions
 * @param NSString* password: password of currently logged in user
 * @param NSString* questions: concatenated string of recovery questions separated by '\n' after each question
 * @param NSString* answers: concatenated string of recovery answers separated by '\n' after each answer
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param complete: completion handler code block which is called with void
 * @param error: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode
 */

- (ABCConditionCode)setRecoveryQuestions:(NSString *)password
                               questions:(NSString *)questions
                                 answers:(NSString *)answers;
- (ABCConditionCode)setRecoveryQuestions:(NSString *)password
                               questions:(NSString *)questions
                                 answers:(NSString *)answers
                                complete:(void (^)(void)) completionHandler
                                   error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;



/*
 * clearBlockchainCache
 * clears the local cache of blockchain info and force a re-download. This will cause wallets
 * to report incorrect balances which the blockchain is resynced
 *
 * @param complete: completion handler code block which is called with ABCSpend *
 *                          @param ABCSpend *    abcSpend: ABCSpend object
 * @param error: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCodeOk (always returns Ok)
 */
- (ABCConditionCode)clearBlockchainCache;
- (ABCConditionCode)clearBlockchainCache:(void (^)(void)) completionHandler
                                   error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;


/*
 * satoshiToCurrency
 *      Convert bitcoin amount in satoshis to a fiat currency amount
 * @param uint_64t     satoshi: amount to convert in satoshis
 * @param int      currencyNum: ISO currency number of fiat currency to convert to
 * @param double    *pCurrency: pointer to resulting value
 * @return ABCConditionCode
 */
- (ABCConditionCode) satoshiToCurrency:(uint64_t) satoshi
                           currencyNum:(int)currencyNum
                              currency:(double *)pCurrency;

/*
 * currencyToSatoshi
 *      Convert fiat amount to a satoshi amount
 * @param double      currency: amount to convert in satoshis
 * @param int      currencyNum: ISO currency number of fiat currency to convert from
 * @param uint_64t   *pSatoshi: pointer to resulting value
 * @return ABCConditionCode
 */
- (ABCConditionCode) currencyToSatoshi:(double)currency
                           currencyNum:(int)currencyNum
                               satoshi:(int64_t *)pSatoshi;

/*
 * shouldAskUserToEnableTouchID
 *  Evaluates if user should be asked to enable touch ID based
 *  on various factors such as if they have ever disabled touchID
 *  in the past, if they have touchID hardware support, and if
 *  this account has a password. PIN only accounts can't user TouchID
 *  at the moment. If user previously had touchID enabled, this will
 *  automatically enable touchID and return NO.
 *  Should be called while logged in.
 * @return BOOL: Should GUI ask if user wants to enable
 */
- (BOOL) shouldAskUserToEnableTouchID;

- (ABCConditionCode)accountDataGet:(NSString *)folder withKey:(NSString *)key data:(NSMutableString *)data;
- (ABCConditionCode)accountDataSet:(NSString *)folder withKey:(NSString *)key withValue:(NSString *)value;
- (ABCConditionCode)accountDataRemove:(NSString *)folder withKey:(NSString *)key;
- (ABCConditionCode)accountDataClear:(NSString *)folder;

- (ABCConditionCode) getLastConditionCode;
- (NSString *) getLastErrorString;


@end


