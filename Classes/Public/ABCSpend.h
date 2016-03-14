//
//  ABCSpend.h
//  AirBitz
//

#import "AirbitzCore.h"

@class ABCWallet;

@interface ABCPaymentRequest : NSObject
@property                           NSString                *domain;
@property                           uint64_t                amountSatoshi;
@property                           NSString                *memo;
@property                           NSString                *merchant;
@end

@interface ABCUnsentTx : NSObject
@property                           NSString                *base16;

- (NSError *)broadcastTx;
- (ABCTransaction *)saveTx:(NSError **)error;
@end


@interface ABCSpend : NSObject

@property                           ABCMetaData             *metaData;

- (NSError *)addAddress:(NSString *)address amount:(uint64_t)amount;
- (NSError *)addTransfer:(ABCWallet *)destWallet amount:(uint64_t)amountSatoshi destMeta:(ABCMetaData *)destMeta;
- (NSError *)addPaymentRequest:(ABCPaymentRequest *)paymentRequest;

/**
 * Calculate the amount of fees needed to send this transaction
 * @param error NSError (optional)
 * @return uint64_t Total fees required for this transaction
 */
- (uint64_t)getFees:(NSError **)error;
- (uint64_t)getFees;

/**
 * Calculate the amount of fees needed to send this transaction
 * @param completionHandler Completion handler code block which is called with uint64_t totalFees
 * - *param* uint64_t Amount of fees in satoshis
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError error object
 */
- (void)getFees:(void(^)(uint64_t fees))completionHandler
          error:(void(^)(NSError *error)) errorHandler;

/**
 * Get the maximum amount spendable from this wallet using the currenct ABCSpend object
 * @param error NSError (optional)
 * @return uint64_t Maximum spendable from this wallet in satoshis
 */
- (uint64_t)getMaxSpendable:(NSError **)error;
- (uint64_t)getMaxSpendable;

/**
 * Get the maximum amount spendable from this wallet using completion handlers
 * @param completionHandler Completion handler code block which is called with uint64_t totalFees
 * - *param* uint64_t amountSpendable Total amount spendablein satoshis
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError error object
 */
- (void)getMaxSpendable:(void(^)(uint64_t amountSpendable))completionHandler
                  error:(void(^)(NSError *error)) errorHandler;


- (ABCUnsentTx *)signTx:(NSError **)error;
- (void)signTx:(void(^)(ABCUnsentTx *unsentTx))completionHandler
         error:(void(^)(NSError *error)) errorHandler;

- (ABCTransaction *)signBroadcastAndSave:(NSError **)error;
- (void)signBroadcastAndSave:(void(^)(ABCTransaction *))completionHandler
                       error:(void(^)(NSError *error)) errorHandler;

@end
