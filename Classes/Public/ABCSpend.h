//
//  ABCSpend.h
//  AirBitz
//

#import "AirbitzCore.h"

@class ABCWallet;

@interface ABCSpend : NSObject

@property (nonatomic, strong)       ABCWallet               *srcWallet;
@property (nonatomic, strong)       ABCWallet               *destWallet;

@property (nonatomic)               uint64_t                amount;

/** True if the GUI can change the amount. */
@property (nonatomic)               bool                    amountMutable;

/** True if this is a signed bip70 payment request. */
@property (nonatomic)               bool                    bSigned;

/** Non-null if the payment request provides a URL
 * to visit once the payment is done. */
@property (nonatomic)               NSString                *returnURL;

/** The destination wallet if this is a transfer, otherwise NULL */
@property (nonatomic)               NSString                *destUUID;

/// Metadata to write into the transaction after the spend has been made
@property (nonatomic, strong)       ABCMetaData             *metaData;

- (id)init:(id)abc;
- (void)spendObjectSet:(void *)o;

- (BOOL)isMutable;
- (uint64_t)maxSpendable;


/*
 * signTx
 * @param txData NSMutableString* pointer to string return signed tx. Must be initialized and non-nil.
 * @return NSError* Error object. nil if success
*/
- (NSError *)signTx:(NSMutableString *)txData;

/*
 * signTx
 * @param completionHandler Completion handler code block which is called with uint64_t totalFees
 * - *param* txData NSString* Signed transaction data
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError* error object
 * @return void
*/
- (void)signTx:(void (^)(NSString * txData)) completionHandler
        error:(void (^)(NSError *error)) errorHandler;


- (NSError *)broadcastTx:(NSString *)rawTx;
- (NSError *)saveTx:(NSString *)rawTx txId:(NSMutableString *)txId;
- (void)signAndSaveTx:(void (^)(NSString * rawTx)) completionHandler
                error:(void (^)(NSError *error)) errorHandler;
- (NSError *)signBroadcastSaveTx:(NSMutableString *)txId;
- (void)signBroadcastSaveTx:(void (^)(NSString * txId)) completionHandler
                      error:(void (^)(NSError *error)) errorHandler;


/*
 * Calculate the amount of fees needed to send this transaction
 * @param uint64_t *totalFees: pointer to populate with total fees
 * @return NSError*
*/
- (NSError *)calcSendFees:(uint64_t *)totalFees;

/*
 * @param completionHandler Code block which is called with uint64_t totalFees
 * - *param* uint64_t totalFees total transaction fees
 * @param errorHandler Code block which is called with the following args
 * - *param* NSError* error object
 * @return void
*/
- (void)calcSendFees:(void (^)(uint64_t totalFees)) completionHandler
               error:(void (^)(NSError *error)) errorHandler;

@end
