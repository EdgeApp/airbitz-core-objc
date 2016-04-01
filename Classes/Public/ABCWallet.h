//
//  ABCWallet.h
//  Airbitz
//
//  Created by Paul Puey.
//  Copyright (c) 2016 Airbitz. All rights reserved.
//
#import "AirbitzCore.h"

#define WALLET_ATTRIBUTE_ARCHIVE_BIT 0x1 // BIT0 is the archive bit

typedef NS_ENUM(NSUInteger, ABCImportDataModel) {
    ABCImportWIF,
    ABCImportHBitsURI,
};

@class ABCAccount;
@class ABCReceiveAddress;
@class AirbitzCore;
@class ABCSpend;
@class ABCTransaction;

/**
 * ABCWallet represents a single HD, multiple address, wallet within an ABCAccount.
 * This object is the basis for Sends and Requests. Initiate sends by calling
 * createNewSpend which returns an ABCSpend object. Use createNewReceiveAddress to
 * generate an ABCReceiveAddress which contains a bitcoin address to receive funds.
 */

@interface ABCWallet : NSObject

///----------------------------------------------------------
/// @name ABCWallet properties
///----------------------------------------------------------

/// Wallet random UUID used for various routines
@property (nonatomic, copy)     NSString        *uuid;

/// Text name of wallet. Defaults to "My Wallet" but can be changed with renameWallet
@property (nonatomic, copy)     NSString        *name;

/// ABCCurrency object determines the fiat currency which this wallet uses to save
/// exchange rate values of each transaction.
@property (nonatomic, assign)   ABCCurrency     *currency;

/// YES if this wallet is archived. App should not allow the user to get an address or
/// spend money from an archived wallet although the SDK does not enforce such rules.
@property (nonatomic, assign)   unsigned int    archived;

/// The total balance of this wallet in satoshis
@property (nonatomic, assign)   int64_t         balance;

/// Array of ABCTransaction objects in this wallet
@property (nonatomic, strong)   NSArray         *arrayTransactions;

/// YES if this wallet and it's transactions have been loaded. This is NO on initial
/// signIn while wallet info is being decrypted and loaded
@property (nonatomic, assign)   BOOL            loaded;

/// The ABCAccount object which contains this wallet.
@property (nonatomic, strong)   ABCAccount      *account;

/// The current blockheight of the bitcoin network
@property (nonatomic, assign)   int             blockHeight;


///----------------------------------------------------------
/// @name Wallet Management
///----------------------------------------------------------

/**
 * @param newName NSString* new name of wallet
 * NSError* error code
 */
- (NSError *) renameWallet:(NSString *)newName;

/**
 * Deletes wallet from user's account. This will render wallet completely inaccessible including any
 * future funds that may be sent to any addresses in this wallet. Give users ample warning before
 * calling this routine.
 * @param completionHandler Completion handler code block which is called with void. (Optional. If used, method
 * returns immediately with void)
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error object
 * @return NSError* or nil if no error. Returns void if completion handlers are used.
 */
- (void)removeWallet:(void(^)(void))completionHandler
               error:(void (^)(NSError *error)) errorHandler;
- (NSError *)removeWallet;

///----------------------------------------------------------
/// @name Transaction Management
///----------------------------------------------------------

/**
 * Gets an ABCTransaction object for bitcoin transactionID txid
 * @param txId NSString Standard Bitcoin transaction ID
 * @return ABCTransaction Transaction object or nil if fails to find
 * transaction in wallet.
 */
- (ABCTransaction *)getTransaction:(NSString *) txId;

/**
 * Searches transactions in wallet for any transactions with metadata
 * matching term and returns the matching transactions in arrayTransactions
 * @param term NSString Search term
 * @param arrayTransactions Allocated NSMutableArray for the resulting matching transactions
 * @return NSError Error object
 */
- (NSError *)searchTransactionsIn:(NSString *)term addTo:(NSMutableArray *) arrayTransactions;


///----------------------------------------------------------
/// @name Bitcoin Address Creation
///----------------------------------------------------------

/** 
 * Create a receive request from the current wallet using completion handlers
 * Caller may then optionally set the values in the following properties:<br>
 * ABCReceiveAddress.metadata<br>
 * ABCReceiveAddress.amountSatoshi<br>
 * ABCReceiveAddress.uriMessage<br>
 * ABCReceiveAddress.uriLabel<br>
 * ABCReceiveAddress.uriCategory<br><br>
 * Caller can then read the following properties<br>
 * ABCReceiveAddress.address<br>
 * ABCReceiveAddress.qrCode<br>
 * ABCReceiveAddress.uri<br><br>
 * Properties in the metadata object are permanently associated with the ABCReceiveAddress such that any
 * future payments to this address will have that metadata automatically tagged in the transaction. User must
 * read either the address, qrCode, or uri properties to ensure that modified fields in ABCReceiveAddress.metadata are
 * saved. The qrCode and uri values will include the amountSatoshi, uriMessage, uriLabel, and uriCategory properties
 * @param completionHandler Completion handler code block which is called with void. (Optional. If used, method
 * returns immediately with void)<br>
 * - *param* ABCReceiveAddress* Receive address object
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error object
 * @return void
 */
- (void)createNewReceiveAddress:(void (^)(ABCReceiveAddress *))completionHandler
                          error:(void (^)(NSError *error)) errorHandler;

/**
 * Create a receive request from the current wallet.
 * Caller may then optionally set the values in the following properties:<br>
 * ABCReceiveAddress.metadata<br>
 * ABCReceiveAddress.amountSatoshi<br>
 * ABCReceiveAddress.uriMessage<br>
 * ABCReceiveAddress.uriLabel<br>
 * ABCReceiveAddress.uriCategory<br><br>
 * Caller can then read the following properties<br>
 * ABCReceiveAddress.address<br>
 * ABCReceiveAddress.qrCode<br>
 * ABCReceiveAddress.uri<br><br>
 * Properties in the metadata object are permanently associated with the ABCReceiveAddress such that any
 * future payments to this address will have that metadata automatically tagged in the transaction. User must
 * read either the address, qrCode, or uri properties to ensure that modified fields in ABCReceiveAddress.metadata are
 * saved. The qrCode and uri values will include the amountSatoshi, uriMessage, uriLabel, and uriCategory properties
 * @param error NSError** (optional)
 * @return ABCReceiveAddress* or nil if failure
 */
- (ABCReceiveAddress *)createNewReceiveAddress:(NSError **)error;
- (ABCReceiveAddress *)createNewReceiveAddress;

/**
 * Retrieves an ABCReceiveAddress object for the given public address
 * At this time, metadata or amountSatoshi values previously associated with this
 * receive address are not re-populated into this ABCReceiveAddress object even
 * if they are still saved in the internal ABC database.
 * @param address NSString* Bitcoin public address from a previous ABCReceiveAddress
 * @param error NSError** Pointer to error object (optional)
 * @return ABCReceiveAddress* ABCReceiveAddress object
 */
- (ABCReceiveAddress *)getReceiveAddress:(NSString *)address error:(NSError **)error;
- (ABCReceiveAddress *)getReceiveAddress:(NSString *)address;

///----------------------------------------------------------
/// @name Spend Bitcoin Routines
///----------------------------------------------------------
/**
 * Create a new ABCSpend object. Can be explicitly deallocated using ABCSpend free.
 * @param error Return pointer to NSError object
 * @return ABCSpend object
 */
- (ABCSpend *)createNewSpend:(NSError **)error;

///----------------------------------------------------------
/// @name Import and Export Routines
///----------------------------------------------------------

/**
 * Import (sweep) private key funds into this wallet. Private key is discarded
 * after sweep.
 * @param privateKey NSString* WIF or HBITS format private key string
 * @param importingHandler Called when private key is determined to be valid and ABC is sweeping funds. May take up to 30 seconds to sweep.
 * - *param* address NSString* public address of private key
 * @param completionHandler Called on success.<br>
 * - *param* dataModel ABCImportDataModel of private key<br>
 * - *param* address NSString* public address of private key<br>
 * - *param* transaction ABCTransaction that swept funds<br>
 * - *param* amount uint64_t amount of satoshis swept into wallet
 * @param errorHandler Error code block called on error with parameters<br>
 * - *param* NSError* error
 * @return void
 */
- (void)importPrivateKey:(NSString *)privateKey
               importing:(void (^)(NSString *address)) importingHandler
                complete:(void (^)(ABCImportDataModel dataModel, NSString *address, ABCTransaction *transaction, uint64_t amount)) completionHandler
                   error:(void (^)(NSError *)) errorHandler;

/**
 * Export a wallet's transactions to CSV format
 * @param csv NSMutableString* allocated and initialized mutable string to receive CSV contents.
 *  Must not be nil.
 * @return NSError* error object. nil if success
 */
- (NSError *)exportTransactionsToCSV:(NSMutableString *) csv;
- (NSError *)exportTransactionsToCSV:(NSMutableString *) csv start:(NSDate *)start end:(NSDate* )end;

/**
 * Export a wallet's transactions to Quickbooks QBO format
 * @param qbo NSMutableString* allocated and initialized mutable string to receive CSV contents.
 *  Must not be nil.
 * @return NSError* error object. nil if success
 */
- (NSError *)exportTransactionsToQBO:(NSMutableString *) qbo;
- (NSError *)exportTransactionsToQBO:(NSMutableString *) qbo start:(NSDate *)start end:(NSDate* )end;

/*
 * Export a wallet's private seed in raw entropy format
 * @param seed NSMutableString* allocated and initialized mutable string to receive private seed contents.
 *  Must not be nil.
 * @return NSError* error object. nil if success
 */
- (NSError *)exportWalletPrivateSeed:(NSMutableString *) seed;


- (void)deprioritizeAllAddresses;
- (int64_t)getTotalSentToday;
- (void)refreshServer:(BOOL)bData notify:(void(^)(void))cb;
- (NSString *)conversionString;



@end
