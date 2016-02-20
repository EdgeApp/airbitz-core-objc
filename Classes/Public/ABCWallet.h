//
//  ABCWallet.h
//  Airbitz
//
//  Created by Paul Puey.
//  Copyright (c) 2016 AirBitz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirbitzCore.h"

#define WALLET_ATTRIBUTE_ARCHIVE_BIT 0x1 // BIT0 is the archive bit

typedef NS_ENUM(NSUInteger, ABCImportDataModel) {
    ABCImportWIF,
    ABCImportHBitsURI,
};

@class ABCAccount;
@class ABCRequest;
@class AirbitzCore;
@class ABCSpend;
@class ABCTransaction;

@interface ABCWallet : NSObject

@property (nonatomic, copy)     NSString        *strUUID;
@property (nonatomic, copy)     NSString        *strName;
@property (nonatomic, assign)   int             currencyNum;
@property (nonatomic, copy)     NSString        *currencyAbbrev;
@property (nonatomic, copy)     NSString        *currencySymbol;
@property (nonatomic, assign)   unsigned int    archived;
@property (nonatomic, assign)   double          balance;
@property (nonatomic, strong)   NSArray         *arrayTransactions;
@property (nonatomic, assign)   BOOL            loaded;
@property (nonatomic, strong)   ABCAccount         *user;
/**
 * @param newName NSString* new name of wallet
 * NSError* error code
 */
- (NSError *) renameWallet:(NSString *)newName;



/** Create a receive request from the current wallet. User should pass in an allocated
 * ABCRequest object with optional values set for amountSatoshi, payee, category, notes, or bizID.
 * The object will have a uri, address, and QRcode UIImage filled in when method completes
 * @param request ABCRequest*
 * @param complete (Optional) Code block called on success. Returns void if used
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return ABCAccount* User object or nil if failure
 */
- (ABCConditionCode)createReceiveRequestWithDetails:(ABCRequest *)request;
- (void)createReceiveRequestWithDetails:(ABCRequest *)request
                               complete:(void (^)(void)) completionHandler
                                  error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Finalizes the request so the address cannot be used by future requests. Forces address
 * rotation so the next request gets a different address
 * @param requestID NSString* Bitcoin address to finalize
 * @return ABCConditionCode
 */
- (ABCConditionCode)finalizeRequestWithAddress:(NSString *)address;

/**
 * Create an ABCSpend object from text. Text could be a bitcoin address or BIP21/BIP70 URI.
 * @param uri NSString*  bitcoin address or full BIP21/BIP70 uri
 * @param complete (Optional) Code block called on success. Method returns void if used
 * - *param* ABCSpend* ABCSpend object.
 * @param error (Optional) Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return ABCSpend* ABCSpend object or nil if failure
 */
- (ABCSpend *)newSpendFromText:(NSString *)uri;
- (void)newSpendFromText:(NSString *)uri
                complete:(void(^)(ABCSpend *sp))completionHandler
                   error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

/**
 * Creates a ABCSpend object from a wallet to wallet transfer. Transfer goes from
 * current object wallet to [ABCWallet] destWallet
 * @param destWallet ABCWallet* of destination wallet for transfer
 * @return ABCSpend* ABCSpend object or nil if failure
 */
- (ABCSpend *)newSpendTransfer:(ABCWallet *)destWallet;

- (ABCSpend *)newSpendInternal:(NSString *)address
                         label:(NSString *)label
                      category:(NSString *)category
                         notes:(NSString *)notes
                 amountSatoshi:(uint64_t)amountSatoshi;

/**
 * Export a wallet's transactions to CSV format
 * @return csv NSString* full CSV export in a single NSString
 */
- (NSString *)exportTransactionsToCSV;

/*
 * Export a wallet's private seed in raw entropy format
 * @return seed NSString*
 */
- (NSString *)exportWalletPrivateSeed;

/**
 * Import (sweep) private key funds into this wallet. Private key is discarded
 * after sweep.
 * @param privateKey NSString* WIF or HBITS format private key string
 * @param importingHandler Called when private key is determined to be valid and ABC is sweeping funds. May take up to 30 seconds to sweep.
 * - *param* address NSString* public address of private key
 * @param completionHandler Called on success.<br>
 * - *param* dataModel ABCImportDataModel of private key<br>
 * - *param* address NSString* public address of private key<br>
 * - *param* txid NSString* txid of transaction that swept funds<br>
 * - *param* amount uint64_t amount of satoshis swept into wallet
 * @param error Code block called on error with parameters<br>
 * - *param* ABCCondition code<br>
 * - *param* NSString* errorString
 * @return void
 */
- (void)importPrivateKey:(NSString *)privateKey
               importing:(void (^)(NSString *address)) importingHandler
                complete:(void (^)(ABCImportDataModel dataModel, NSString *address, NSString *txid, uint64_t amount)) completionHandler
                   error:(void (^)(ABCConditionCode ccode, NSString *errorString)) errorHandler;

- (void)prioritizeAddress:(NSString *)address;
- (void) loadTransactions;
- (ABCTransaction *)getTransaction:(NSString *) txId;
- (int64_t)getTotalSentToday;
- (void)refreshServer:(BOOL)bData notify:(void(^)(void))cb;
- (NSString *)conversionString;
- (NSMutableArray *)searchTransactionsIn:(NSString *)term addTo:(NSMutableArray *) arrayTransactions;
- (ABCConditionCode) getLastConditionCode;
- (NSString *) getLastErrorString;
- (void)loadWalletFromCore:(NSString *)uuid;



@end
