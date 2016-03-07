//
//  ABCWallet.h
//  Airbitz
//
//  Created by Paul Puey.
//  Copyright (c) 2016 AirBitz. All rights reserved.
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

@interface ABCWallet : NSObject

@property (nonatomic, copy)     NSString        *uuid;
@property (nonatomic, copy)     NSString        *name;
@property (nonatomic, assign)   ABCCurrency        *currency;
@property (nonatomic, assign)   unsigned int    archived;
@property (nonatomic, assign)   double          balance;
@property (nonatomic, strong)   NSArray         *arrayTransactions;
@property (nonatomic, assign)   BOOL            loaded;
@property (nonatomic, strong)   ABCAccount      *account;

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


/**
 * Create an ABCSpend object from text. Text could be a bitcoin address or BIP21/BIP70 URI.
 * @param uri NSString*  Bitcoin address or full BIP21/BIP70 uri
 * @param error NSError** Pointer to error object.
 * @return ABCSpend ABCSpend object or nil if failure.
 */
- (ABCSpend *)newSpendFromText:(NSString *)uri error:(NSError **)error;

/**
 * Create an ABCSpend object from text. Text could be a bitcoin address or BIP21/BIP70 URI.
 * @param uri NSString*  Bitcoin address or full BIP21/BIP70 uri
 * @param completionHandler Completion handler code block which is called with ABCSpend.<br>
 * - *param* ABCSpend ABCSpend object.
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error object
 * @return void
 */
- (void)newSpendFromText:(NSString *)uri
                complete:(void(^)(ABCSpend *sp))completionHandler
                   error:(void (^)(NSError *error)) errorHandler;

/**
 * Creates a ABCSpend object from a wallet to wallet transfer. Transfer goes from
 * current object wallet to [ABCWallet] destWallet
 * @param destWallet ABCWallet of destination wallet for transfer
 * @param error NSError** Pointer to error object.
 * @return ABCSpend ABCSpend object or nil if failure
 */
- (ABCSpend *)newSpendTransfer:(ABCWallet *)destWallet error:(NSError **)error;

- (ABCSpend *)newSpendInternal:(NSString *)address
                         label:(NSString *)label
                      category:(NSString *)category
                         notes:(NSString *)notes
                 amountSatoshi:(uint64_t)amountSatoshi;

/**
 * Export a wallet's transactions to CSV format
 * @param csv NSMutableString* allocated and initialized mutable string to receive CSV contents.
 *  Must not be nil.
 * @return NSError* error object. nil if success
 */
- (NSError *)exportTransactionsToCSV:(NSMutableString *) csv;

/*
 * Export a wallet's private seed in raw entropy format
 * @param seed NSMutableString* allocated and initialized mutable string to receive private seed contents.
 *  Must not be nil.
 * @return NSError* error object. nil if success
 */
- (NSError *)exportWalletPrivateSeed:(NSMutableString *) seed;

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

- (void)deprioritizeAllAddresses;
- (ABCTransaction *)getTransaction:(NSString *) txId;
- (int64_t)getTotalSentToday;
- (void)refreshServer:(BOOL)bData notify:(void(^)(void))cb;
- (NSString *)conversionString;
- (NSMutableArray *)searchTransactionsIn:(NSString *)term addTo:(NSMutableArray *) arrayTransactions;
- (void)loadWalletFromCore:(NSString *)uuid;



@end
