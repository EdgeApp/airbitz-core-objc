//
//  ABCAccount.h
//  Airbitz
//

#import "AirbitzCore.h"

@class AirbitzCore;
@class ABCAccount;
@class ABCCurrency;
@class ABCDataStore;
@class ABCDenomination;
@class ABCExchangeCache;
@class ABCSpend;
@class ABCSettings;
@class ABCRequest;
@class ABCTransaction;
@class ABCWallet;

@interface BitidSignature : NSObject
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *signature;
@end

///----------------------------------------------------------
/// @name ABCAccount Delegate callbacks
///----------------------------------------------------------

@protocol ABCAccountDelegate <NSObject>

@optional

/// Password has been changed by a remote device. User will be able to login on current device
/// with old password. One user logs in with new password, old password will cease to function.
- (void) abcAccountRemotePasswordChange;

/// User has been logged out. Always called after [ABCAccount logout] once Core has finished logout
/// Also called under some error conditions such as corrupt local data.
- (void) abcAccountLoggedOut:(ABCAccount *)user;

/// Account details such as settings have changed
- (void) abcAccountAccountChanged;

/// Specific wallet has changed. Changes may include new transactions or modified metadata
- (void) abcAccountWalletChanged:(ABCWallet *)wallet;

/// Called when the wallets in the account are still loading their prior transactions.
- (void) abcAccountWalletsLoading;

/// At minimum, the primary wallet has finished loading. Other wallets may still be loading
- (void) abcAccountWalletsLoaded;

/// Wallets in the account have changed. Changes may include new wallet order or wallet names.
- (void) abcAccountWalletsChanged;

/// Account has had OTP enabled on another device. GUI should ask user to add OTP key from
/// OTP authenticated device.
- (void) abcAccountOTPRequired;

/// Current OTP token on device does not match server OTP token. Token may have been changed by another
/// device or user's time clock is skewed.
- (void) abcAccountOTPSkew;

/// The current blockheight has changed. Use should refresh GUI by rereading ABCAccount.arrayWallets
- (void) abcAccountBlockHeightChanged;

/// This device has just sync'ed a transaction to the specified wallet from another device
/// causing a change in balance. This happens if two devices share a wallet. First device will see
/// abcAccountIncomingBitcoin. The second device will see abcAccountBalanceUpdate
- (void) abcAccountBalanceUpdate:(ABCWallet *)wallet transaction:(ABCTransaction *)transaction;

/// The specified wallet has just received a new transaction.
- (void) abcAccountIncomingBitcoin:(ABCWallet *)wallet transaction:(ABCTransaction *)transaction;

@end

@interface ABCAccount : NSObject
///----------------------------------------------------------
/// @name ABCAccount read/write public object variables
///----------------------------------------------------------

/// Delegate object to handle delegate callbacks
@property (assign)            id<ABCAccountDelegate>    delegate;

/// ABC settings that can be set or viewed by app or ABC. Use method [ABCSettings loadSettings]
/// to make sure they are loaded and [ABCSettings saveSettings] to ensure modified settings are latched
@property (atomic, strong) ABCSettings                  *settings;

@property (atomic, strong) ABCExchangeCache             *exchangeCache;

///----------------------------------------------------------
/// @name ABCAccount read-only public object variables
///----------------------------------------------------------

/// Array of Wallet objects currently loaded into account. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayWallets;

/// Array of archived Wallet objects currently loaded into account. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayArchivedWallets;

/// Array of NSString * wallet names. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayWalletNames;

/// Helper property that points to the "currentWallet" in the account. This can be used by
/// GUI as the default wallet used for spending and receive requests. This value is automatically
/// set to a different wallet if the wallet pointed to by currentWallet is deleted.
@property (atomic, strong) ABCWallet                 *currentWallet;

/// Index into arrayWallets to where currentWallet is set to.<br>
/// arrayWallets[currentWalletIndex] = currentWallet
@property (atomic)         int                       currentWalletIndex;

/// Array of NSString* categories with which a user to could choose to tag a transaction with.
/// Categories must start with "Income", "Expense", "Transfer" or "Exchange" plus a ":" and then
/// an arbitrary subcategory such as "Food & Dining". ie. "Expense:Rent"
@property (atomic, strong) NSArray                   *arrayCategories;

/// DataStore object for allowing arbitrary Edge Secure data storage and retrieval on this
/// ABCAccount
@property                  ABCDataStore              *dataStore;

@property (atomic)         BOOL                      bAllWalletsLoaded;
@property (atomic)         int                       numWalletsLoaded;
@property (atomic)         int                       numTotalWallets;
@property (atomic)         int                       numCategories;

/// This account's username
@property (atomic, copy)     NSString                *name;
@property (atomic, copy)     NSString                *password;





// New methods
- (void)makeCurrentWallet:(ABCWallet *)wallet;
- (void)makeCurrentWalletWithIndex:(NSIndexPath *)indexPath;
- (void)makeCurrentWalletWithUUID:(NSString *)uuid;
- (ABCWallet *)selectWalletWithUUID:(NSString *)uuid;
- (void)loadCategories;
- (NSError *)saveCategories:(NSMutableArray *)saveArrayCategories;
- (BOOL) isLoggedIn;


- (bool)setWalletAttributes: (ABCWallet *) wallet;

- (NSString *)createExchangeRateString:(ABCCurrency *)currency
                   includeCurrencyCode:(bool)includeCurrencyCode;
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
 * @param password NSString* new password for currently logged in user
 * (Optional. If used, method returns immediately with void)
 * @param completionHandler (Optional) completion handler code block
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return NSError object or nil if failure. Return void if using completion
 *  handler
 */
- (NSError *)changePassword:(NSString *)password;
- (void)changePassword:(NSString *)password
              complete:(void (^)(void)) completionHandler
                 error:(void (^)(NSError *)) errorHandler;

/*
 * changePIN
 * @param NSString* pin: new pin for currently logged in user
 *
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param completionHandler: completion handler code block
 * @param errorHandler: error handler code block which is called with the following args
 *                          @param ABCConditionCode       ccode: ABC error code
 *                          @param NSString *       errorString: error message
 * @return ABCConditionCode or void if completion handlers used
 */
- (NSError *)changePIN:(NSString *)pin;
- (void)changePIN:(NSString *)pin
                     complete:(void (^)(void)) completionHandler
                        error:(void (^)(NSError *)) errorHandler;

/**
 * Check if this user has a password on the account or if it is
 * a PIN-only account.
 * @return BOOL true if user has a password
 */
- (BOOL)passwordExists:(NSError **)error;
- (BOOL)passwordExists;

/**
 * Check if this user has logged in "recently". Currently fixed to return TRUE
 * within 120 seconds of login. Useful for requiring less security for spending such as a PIN
 * on spend.
 * @return BOOL
 */
- (BOOL)recentlyLoggedIn;


/**
 * Checks a PIN for correctness. This checks against the PIN used
 * during account creation in [AirbitzCore createAccount] or the PIN changed
 * with [ABCAccount changePIN]<br>
 * This is used to guard access to certain actions in the GUI.
 * @param pin NSString* Pin to check
 * @param error (Optional) NSError* Error object. Nil if success
 * @return BOOL YES if PIN is correct
 */
- (BOOL) pinCheck:(NSString *)pin;
- (BOOL) pinCheck:(NSString *)pin error:(NSError **)error;

/**
 * Enable or disable PIN login on this account. Set enable = YES to allow
 * PIN login. Enabling PIN login creates a local account decryption key that
 * is split with one have in local device storage and the other half on Airbitz
 * servers. When using [AirbitzCore signInWithPIN] the PIN is sent to Airbitz servers
 * to authenticate the user. If the PIN is correct, the second half of the decryption
 * key is sent back to the device. Combined with the locally saved key, the two
 * are then used to decrypt the local account thereby loggin in the user.
 * @param enable BOOL set to YES to enable PIN login
 * @return NSError* Nil if success
 */
- (NSError *) pinLoginSetup:(BOOL)enable;

/**
 * Check if this account is allowed to login via PIN
 * @return BOOL YES if PIN login is enabled
 */
- (BOOL) isPINLoginEnabled;

/// -----------------------------------------------------------------------------
/// @name Wallet Management
/// -----------------------------------------------------------------------------

/**
 * Create a wallet in the current account.
 * @param walletName NSString* Name of wallet or set to nil to use default wallet name
 * @param currency NSString* ISO 3 digit currency code for wallet. Set to nil to use default currency from
 *  settings or the global default currency if settings unavailable. ie. "USD, EUR, CAD, PHP"
 * (Optional. If used, method returns immediately with void
 * @param error NSError** May be set to nil. Only used when not using completion handler
 * @param completionHandler (Optional) Code block called on success. Returns void if used<br>
 * - *param* ABCWallet* User object.<br>
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return ABCWallet* wallet object or nil if failure. If using completion handler, returns void.
 */
- (ABCWallet *) createWallet:(NSString *)walletName currency:(NSString *)currency;
- (ABCWallet *) createWallet:(NSString *)walletName currency:(NSString *)currency error:(NSError **)nserror;
- (void) createWallet:(NSString *)walletName currency:(NSString *)currency
             complete:(void (^)(ABCWallet *)) completionHandler
                error:(void (^)(NSError *)) errorHandler;


- (NSError *)createFirstWalletIfNeeded;

/**
 * Returns an ABCWallet object looked up by walletUUID
 * @param walletUUID NSString* uuid of wallet to find
 * @return ABCWallet* Returned wallet object or nil if not found
 */
- (ABCWallet *)getWallet:(NSString *)walletUUID;

/**
 * Changes the order of wallets in [ABCAccount arrayWallets] & [ABCAccount arrayArchivedWallets]
 * The wallet to move is specified by the 'section' and 'row' of the indexPath. Section 0 specifies wallets
 * in arrayWallets. Section 1 specifies arrayArchivedWallet. The 'row' specifies the position within the
 * array. Wallets are reordered by specifying the source wallet
 * position in sourceIndexPath and destination position in destinationIndexPath.
 * @param sourceIndexPath NSIndexPath* The position of the wallet to move
 * @return destinationIndexPath NSIndexPath* The destination array position of the wallet
 */
- (NSError *)reorderWallets:(NSIndexPath *)sourceIndexPath
                toIndexPath:(NSIndexPath *)destinationIndexPath;

/**
 * Returns the number of wallets in the account
 * @param error NSError**
 * @return int number of wallets
 */
- (int) getNumWalletsInAccount:(NSError **)error;

/**
 * Checks if the current account has a pending request to reset (disable)
 * OTP.
 * @param error NSError** error object or nil if success
 * @return BOOL YES if account has pending reset
 */
- (BOOL) hasOTPResetPending:(NSError **)error;

/**
 * Gets the locally saved OTP key for the current user.
 * @param error NSError** error object or nil if success
 * @return key NSString* OTP key
 */
- (NSString *)getOTPLocalKey:(NSError **)nserror;

/**
 * Removes the OTP key for current user.
 * This will remove the key from disk as well.
 * @return NSError* or nil if no error
 */
- (NSError *)removeOTPKey;

/**
 * Reads the OTP configuration from the server. Gets information on whether OTP
 * is enabled for the current account, and how long a reset request will take.
 * An OTP reset is a request to disable OTP made through the method
 * [AirbitzCore requestOTPReset]
 * @param enabled bool* enabled flag if OTP is enabled for this user
 * @param timeout long* number seconds required after a reset is requested
 * @return NSError* or nil if no error
 */
- (NSError *)getOTPDetails:(bool *)enabled
                   timeout:(long *)timeout;

/**
 * Sets up OTP authentication on the server for currently logged in user
 * This will generate a new token if the username doesn't already have one.
 * @param timeout long number seconds required after a reset is requested
 * before OTP is disabled.
 * @return NSError* or nil if no error
 */
- (NSError *)setOTPAuth:(long)timeout;

/**
 * Removes the OTP authentication requirement from the server for the
 * currently logged in user
 * @return NSError* or nil if no error
 */
- (NSError *)removeOTPAuth;

/**
 * Removes the OTP reset request from the server for the
 * currently logged in user
 * @return NSError* or nil if no error
 */
- (NSError *)removeOTPResetRequest;

/*
 * Sets account recovery questions and answers in case use forgets their password
 * @param password NSString* password of currently logged in user
 * @param questions NSString* concatenated string of recovery questions separated by '\n' after each question
 * @param answers NSString* concatenated string of recovery answers separated by '\n' after each answer
 * @param completionHandler (Optional) code block which is called upon success with void
 * (Optional. If used, method returns immediately with void)
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return NSError* or nil if no error. Returns void if using completionHandler
 */

- (NSError *)setupRecoveryQuestions:(NSString *)password
                        questions:(NSString *)questions
                          answers:(NSString *)answers;
- (void)setupRecoveryQuestions:(NSString *)password
                               questions:(NSString *)questions
                                 answers:(NSString *)answers
                                complete:(void (^)(void)) completionHandler
                                   error:(void (^)(NSError *error)) errorHandler;



/*
 * Clears the local cache of blockchain information and force a re-download. This will cause wallets
 * to report incorrect balances which the blockchain is resynced
 * @param completionHandler (Optional) code block which is called upon success with void
 * (Optional. If used, method returns immediately with void)
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return NSError* or nil if no error. Returns void if using completionHandler
 */
- (NSError *)clearBlockchainCache;
- (void)clearBlockchainCache:(void (^)(void)) completionHandler
                       error:(void (^)(NSError *error)) errorHandler;


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

- (NSError *)addCategory:(NSString *)strCategory;



@end


