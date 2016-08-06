//
//  ABCAccount.h
//  Airbitz
//

#import "ABCContext.h"

/**
 * The ABCAccount object represents a fully logged in account. This is returned by various signIn
 * routines from ABCContext. It contains an ABCSettings object which are account settings that
 * carry over from device to device. ABCAccount also contains an array of ABCWallet object wallets and archived
 * wallets which should be checked for the parameter loaded=YES before being accessed.
 *
 * The ABCDataStore object dataStore allows reading/writing of encrypted and backed up key/value
 * data to the user's account. This data is accessible from any device that the user authenticates
 * into using an app running on the Airbitz SDK.
 */

@class ABCContext;
@class ABCAccount;
@class ABCCategories;
@class ABCCurrency;
@class ABCDataStore;
@class ABCDenomination;
@class ABCError;
@class ABCExchangeCache;
@class ABCSpend;
@class ABCSettings;
@class ABCReceiveAddress;
@class ABCTransaction;
@class ABCWallet;
@class ABCBitIDSignature;
@protocol ABCAccountDelegate;

@interface ABCAccount : NSObject
///----------------------------------------------------------
/// @name ABCAccount read/write public object variables
///----------------------------------------------------------

/// Delegate object to handle delegate callbacks
@property (assign)            id<ABCAccountDelegate>    delegate;

/// ABC settings that can be set or viewed by app or ABC. Use method [ABCSettings loadSettings]
/// to make sure they are loaded and [ABCSettings saveSettings] to ensure modified settings are latched
@property (atomic, strong) ABCSettings                  *settings;

/// ABCExchangeCache object. Used to convert bitcoin values to/from fiat in various formats
/// The exchange cache is internally implemented as a global object shared across all users of
/// ABCContext in the same application.
@property (atomic, strong) ABCExchangeCache             *exchangeCache;

///----------------------------------------------------------
/// @name ABCAccount read-only public object variables
///----------------------------------------------------------

/// Array of ABCWallet objects currently loaded into account. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayWallets;

/// Array of archived ABCWallet objects currently loaded into account. This array is read-only and app should only
/// access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayArchivedWallets;

/// Array of NSString wallet names for non-archived wallets. This array maps index-for-index
/// to arrayWallets. This array is read-only and app should only access the array while in the main queue.
@property (atomic, strong) NSMutableArray            *arrayWalletNames;

/// Helper property that points to the "currentWallet" in the account. This can be used by
/// GUI as the default wallet used for spending and receive requests. This value is automatically
/// set to a different wallet if the wallet pointed to by currentWallet is deleted.
@property (atomic, strong) ABCWallet                 *currentWallet;

/// Index into arrayWallets to where currentWallet is set to.<br>
/// arrayWallets[currentWalletIndex] = currentWallet
@property (atomic)         int                       currentWalletIndex;

/// ABCCategories object which lists category options a user could choose to tag a transaction with.
/// Categories must start with "Income", "Expense", "Transfer" or "Exchange" plus a ":" and then
/// an arbitrary subcategory such as "Food & Dining". ie. "Expense:Rent"
@property (atomic, strong) ABCCategories             *categories;

/// ABCDataStore object for allowing arbitrary Edge Secure data storage and retrieval on this
/// ABCAccount.
@property                  ABCDataStore              *dataStore;

/// YES once all wallets in this account have been successfully loaded after a signIn
@property (atomic)         BOOL                      bAllWalletsLoaded;

/// Number of wallets that have been loaded after a signIn
@property (atomic)         int                       numWalletsLoaded;

/// Number of wallets in this account
@property (atomic)         int                       numTotalWallets;

/// This account's username
@property (atomic, copy)     NSString                *name;

- (void)makeCurrentWallet:(ABCWallet *)wallet;
- (void)makeCurrentWalletWithIndex:(NSIndexPath *)indexPath;
- (void)makeCurrentWalletWithUUID:(NSString *)uuid;
- (ABCWallet *)selectWalletWithUUID:(NSString *)uuid;
- (BOOL) isLoggedIn;

/**
 * Creates a user displayable exchange rate string using the current user's
 * denomination settings. ie. "1 BTC = $451" or "1 mBTC = $0.451"
 * @param currency ABCCurrency object representing choice of fiat
 *  currency to use for conversion
 * @param includeCurrencyCode BOOL If YES, include the fiat currency code in the
 *  conversion string. ie. "1 BTC = $451 USD"
 */
- (NSString *)createExchangeRateString:(ABCCurrency *)currency
                   includeCurrencyCode:(bool)includeCurrencyCode;


/// -----------------------------------------------------------------------------
/// @name Account Management
/// -----------------------------------------------------------------------------

/**
 * @param password NSString Set password for current ABCAccount
 * (Optional. If used, method returns immediately with void)
 * @param completionHandler (Optional) completion handler code block
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError
 * @return ABCError object or nil if success. Return void if using completion
 *  handler
 */
- (void)changePassword:(NSString *)password
           callback:(void (^)(ABCError *error)) callback;
- (ABCError *)changePassword:(NSString *)password;

/**
 * @param pin NSString Set PIN for current ABCAccount
 * (Optional. If used, method returns immediately with ABCCConditionCodeOk)
 * @param callback Callback code block
 * - *param* NSError
 * @return ABCError Error object. Nil if success. Returns void if completion handlers used
 */
- (void)changePIN:(NSString *)pin
      callback:(void (^)(ABCError *error)) callback;
- (ABCError *)changePIN:(NSString *)pin;

/**
 * Check if this user has a password on the account or if it is
 * a PIN-only account.
 * @param error (Optional) NSError* Error object. Nil if success
 * @return BOOL true if user has a password
 */
- (BOOL)accountHasPassword:(ABCError **)error;
- (BOOL)accountHasPassword;

/**
 * Check if this user has logged in "recently". Currently fixed to return TRUE
 * within 120 seconds of login. Useful for requiring less security for spending such as a PIN
 * on spend.
 * @return BOOL
 */
- (BOOL)recentlyLoggedIn;

/**
 * Checks a PIN for correctness. This checks against the PIN used
 * during account creation in [ABCContext createAccount] or the PIN changed
 * with [ABCAccount changePIN]<br>
 * This is used to guard access to certain actions in the GUI.
 * @param pin NSString* Pin to check
 * @param error (Optional) NSError* Error object. Nil if success
 * @return BOOL YES if PIN is correct
 */
- (BOOL) checkPIN:(NSString *)pin error:(ABCError **)error;
- (BOOL) checkPIN:(NSString *)pin;

/**
 * Checks if password is the correct password for this account
 * @param password NSString Password to check
 * @return BOOL YES if password is correct
 */
- (BOOL)checkPassword:(NSString *)password;

/**
 * Enable or disable PIN login on this account. Set enable = YES to allow
 * PIN login. Enabling PIN login creates a local account decryption key that
 * is split with one have in local device storage and the other half on Airbitz
 * servers. When using [ABCContext pinLogin:username:pin:delegate:error] the PIN is sent to Airbitz servers
 * to authenticate the user. If the PIN is correct, the second half of the decryption
 * key is sent back to the device. Combined with the locally saved key, the two
 * are then used to decrypt the local account thereby loggin in the user.
 * @param enable BOOL set to YES to enable PIN login
 * @return NSError* Nil if success
 */
- (ABCError *) enablePINLogin:(BOOL)enable;

/**
 * Check if this account is allowed to login via PIN
 * @return BOOL YES if PIN login is enabled
 */
- (BOOL) hasPINLogin;

/**
 * Logout the current ABCAccount object
 * @return void
 */
- (void)logout;



/// -----------------------------------------------------------------------------
/// @name Wallet Management
/// -----------------------------------------------------------------------------

/**
 * Create a wallet in the current account with completion handlers
 * @param walletName NSString* Name of wallet or set to nil to use default wallet name
 * @param currency NSString* ISO 3 digit currency code for wallet. Set to nil to use default currency from
 *  settings or the global default currency if settings unavailable. ie. "USD, EUR, CAD, PHP"
 * (Optional. If used, method returns immediately with void
 * @param completionHandler Code block called on success.<br>
 * - *param* ABCWallet Fully created ABCWallet object.
 * @param errorHandler Code block called on error with parameters<br>
 * - *param* NSError*
 * @return void
 */
- (void) createWallet:(NSString *)walletName
             currency:(NSString *)currency
             complete:(void (^)(ABCWallet *)) completionHandler
                error:(void (^)(ABCError *)) errorHandler;


/**
 * Create a wallet in the current account.
 * @param walletName NSString* Name of wallet or set to nil to use default wallet name
 * @param currency NSString* ISO 3 digit currency code for wallet. Set to nil to use default currency from
 *  settings or the global default currency if settings unavailable. ie. "USD, EUR, CAD, PHP"
 * @param error NSError** May be set to nil. (Optional)
 * @return ABCWallet wallet object or nil if failure.
 */
- (ABCWallet *) createWallet:(NSString *)walletName currency:(NSString *)currency error:(ABCError **)error;
- (ABCWallet *) createWallet:(NSString *)walletName currency:(NSString *)currency;

- (ABCError *)createFirstWalletIfNeeded;

/**
 * Returns an ABCWallet object looked up by walletUUID
 * @param walletUUID NSString* uuid of wallet to find
 * @return ABCWallet Returned wallet object or nil if not found
 */
- (ABCWallet *)getWallet:(NSString *)walletUUID;

/**
 * Changes the order of wallets in [ABCAccount arrayWallets] & [ABCAccount arrayArchivedWallets]
 * The wallet to move is specified by the 'section' and 'row' of the indexPath. Section 0 specifies wallets
 * in arrayWallets. Section 1 specifies arrayArchivedWallet. The 'row' specifies the position within the
 * array. Wallets are reordered by specifying the source wallet
 * position in sourceIndexPath and destination position in destinationIndexPath.
 * @param sourceIndexPath NSIndexPath* The position of the wallet to move
 * @param destinationIndexPath NSIndexPath* The destination array position of the wallet
 * @return NSError* Error object. Nil if success.
 */
- (ABCError *)reorderWallets:(NSIndexPath *)sourceIndexPath
                toIndexPath:(NSIndexPath *)destinationIndexPath;

/**
 * Returns an array of the wallet IDs in the account
 * @param error ABCError (optional)
 * @return NSArray array of NSString wallet IDs
 */
- (NSArray *)listWalletIDs:(ABCError **)error;
- (NSArray *)listWalletIDs;

/// -----------------------------------------------------------------------------
/// @name One Time Password (OTP) (2 Factor Authentication)
/// -----------------------------------------------------------------------------

/**
 * Associates an OTP key with the account. An OTP key can be retrieved from
 * a previously logged in account using [ABCAccount getOTPLocalKey]. The account
 * must have had OTP enabled by using [ABCAccount enableOTP]
 * @param key NSString* key to set
 * @return NSError*
 */
- (ABCError *)setupOTPKey:(NSString *)key;

/**
 * Gets the locally saved OTP key for the current user.
 * @param error ABCError error object or nil if success
 * @return NSString OTP key
 */
- (NSString *)getOTPLocalKey:(ABCError **)error;

/**
 * Reads the OTP configuration from the server. Gets information on whether OTP
 * is enabled for the current account, and how long a reset request will take.
 * An OTP reset is a request to disable OTP made through the method
 * [ABCContext requestOTPReset]
 * @param enabled bool* enabled flag if OTP is enabled for this user
 * @param timeout long* number seconds required after a reset is requested
 * @return NSError* or nil if no error
 */
- (ABCError *)getOTPDetails:(bool *)enabled
                   timeout:(long *)timeout;

/**
 * Sets up OTP authentication on the server for currently logged in user
 * This will generate a new token if the username doesn't already have one.
 * @param timeout long number seconds required after a reset is requested
 * before OTP is disabled.
 * @return NSError* or nil if no error
 */
- (ABCError *)enableOTP:(long)timeout;

/**
 * Removes the OTP authentication requirement from the server for the
 * currently logged in user. Also removes local key from device
 * @return NSError* or nil if no error
 */
- (ABCError *)disableOTP;

/**
 * Removes the OTP reset request from the server for the
 * currently logged in user
 * @return NSError* or nil if no error
 */
- (ABCError *)cancelOTPResetRequest;

/// -----------------------------------------------------------------------------
/// @name Password Recovery
/// -----------------------------------------------------------------------------


/**
 * Sets account recovery questions and answers in case use forgets their password
 * @param questions NSString* concatenated string of recovery questions separated by '\n' after each question
 * @param answers NSString* concatenated string of recovery answers separated by '\n' after each answer
 * @param completionHandler (Optional) code block which is called upon success with void
 * (Optional. If used, method returns immediately with void)
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return NSError* or nil if no error. Returns void if using completionHandler
 */
- (void)setupRecoveryQuestions:(NSString *)questions
                       answers:(NSString *)answers
                      complete:(void (^)(void)) completionHandler
                         error:(void (^)(ABCError *error)) errorHandler;
- (ABCError *)setupRecoveryQuestions:(NSString *)questions
                            answers:(NSString *)answers;

/**
 * GUI utility function to help determine if the user should be asked to setup
 * recovery questions and answers. This routine factors the amount of funds the account
 * has received and whether or not recovery Q/A has already been setup.
 * @return BOOL YES if user should be asked.
 */
- (BOOL)needsRecoveryQuestionsReminder;

/// -----------------------------------------------------------------------------
/// @name Misc ABCAccount methods
/// -----------------------------------------------------------------------------

/**
 * Clears the local cache of blockchain information and force a re-download. This will cause wallets
 * to report incorrect balances which the blockchain is resynced
 * @param completionHandler (Optional) code block which is called upon success with void
 * (Optional. If used, method returns immediately with void)
 * @param errorHandler (Optional) Code block called on error with parameters<br>
 * - *param* NSError*
 * @return NSError* or nil if no error. Returns void if using completionHandler
 */
- (void)clearBlockchainCache:(void (^)(void)) completionHandler
                       error:(void (^)(ABCError *error)) errorHandler;
- (ABCError *)clearBlockchainCache;


/**
 * Evaluates if user should be asked to enable touch ID based
 * on various factors such as if they have ever disabled touchID
 * in the past, if they have touchID hardware support, and if
 * this account has a password. PIN only accounts can't user TouchID
 * at the moment. If user previously had touchID enabled, this will
 * automatically enable touchID and return NO.
 * Should be called while logged in.
 * @return BOOL: Should GUI ask if user wants to enable
 */
- (BOOL) shouldAskUserToEnableTouchID;

///----------------------------------------------------------
/// @name BitID methods
///----------------------------------------------------------

/**
 * Parses a BitID URI and returns the domain of the URL for display to user.
 * @param uri NSString URI to parse
 * @return NSString Domain of BitID request
 */
- (NSString *) bitidParseURI:(NSString *)uri;

/**
 * Login to a BitID server given the request URI
 * @param uri NSString URI request from server in the form "bitid://server.com/bitid?x=NONCE"
 * @return ABCError Error object if failure. Nil if success.
 */
- (ABCError *) bitidLogin:(NSString *)uri;

// Undocumented. Do not use
- (ABCError *) bitidLoginMeta:(NSString *)uri kycURI:(NSString *)kycURI;

/**
 * Sign an arbitrary message with a BitID URI. The URI determines the key derivation
 * used to sign the message.
 * @param uri NSString URI request from server in the form "bitid://server.com/bitid?x=NONCE"
 * @param message NSString message to sign.
 * @return ABCBitIDSignature BitID signature object
 */
- (ABCBitIDSignature *)signBitIDRequest:(NSString *)uri message:(NSString *)message;


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
/// @param account ABCAccount account that has been logged out
- (void) abcAccountLoggedOut:(ABCAccount *)account;

/// Account details such as settings have changed
- (void) abcAccountAccountChanged;

/// Specific wallet has changed. Changes may include new transactions or modified metadata
/// @param wallet ABCWallet
- (void) abcAccountWalletChanged:(ABCWallet *)wallet;

/// Specific wallet has finished loading. Other wallets may still be loading
/// @param wallet ABCWallet
- (void) abcAccountWalletLoaded:(ABCWallet *)wallet;

/// Wallets in the account have changed. Changes may include new wallet order or wallet names.
- (void) abcAccountWalletsChanged;

/// Account has had OTP enabled on another device. GUI should ask user to add OTP key from
/// OTP authenticated device.
- (void) abcAccountOTPRequired;

/// Current OTP token on device does not match server OTP token. Token may have been changed by another
/// device or user's time clock is skewed.
- (void) abcAccountOTPSkew;

/// The current blockheight has changed for the specified wallet.
/// @param wallet ABCWallet
- (void) abcAccountBlockHeightChanged:(ABCWallet *)wallet;

/// This device has just sync'ed a transaction to the specified wallet from another device
/// causing a change in balance. This happens if two devices share a wallet. First device will see
/// abcAccountIncomingBitcoin. The second device will see abcAccountBalanceUpdate
/// @param wallet ABCWallet The wallet whose balance was updated
/// @param transaction ABCTransaction The transaction which caused the balance change
- (void) abcAccountBalanceUpdate:(ABCWallet *)wallet transaction:(ABCTransaction *)transaction;

/// The specified wallet has just received a new incoming funds transaction which has not yet
/// been seen by other devices with this account.
/// @param wallet ABCWallet The wallet whose balance was updated
/// @param transaction ABCTransaction The transaction which caused the incoming coin.
- (void) abcAccountIncomingBitcoin:(ABCWallet *)wallet transaction:(ABCTransaction *)transaction;

@end



/**
 * ABCBitIDSignature is the result of a signed BitID request.
 */
@interface ABCBitIDSignature : NSObject

/// Public address used to sign the request
@property (nonatomic, strong) NSString *address;

/// Resulting signature of the request
@property (nonatomic, strong) NSString *signature;
@end

