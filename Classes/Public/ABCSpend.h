//
//  ABCSpend.h
//  AirBitz
//

#import "AirbitzCore.h"

@class ABCWallet;
@class ABCPaymentRequest;
@class ABCUnsentTx;

/**
 * ABCSpend is used to build a Spend from the ABCWallet that generated this ABCSpend object.
 * Caller can add multiple spend targets by calling either of addAddress, addTransfer, or
 * addPaymentRequest repeated times. Use signBroadcastAndSave to send the transaction to the
 * blockchain. This spend may also be signed without broadcast by calling signTx.
 */

typedef enum eABCSpendFeeLevel
{
    ABCSpendFeeLevelLow = 0,
    ABCSpendFeeLevelStandard,
    ABCSpendFeeLevelHigh,
    ABCSpendFeeLevelCustom,
} ABCSpendFeeLevel;

@interface ABCSpend : NSObject

@property                           ABCMetaData             *metaData;
@property                           ABCSpendFeeLevel        feeLevel;
@property                           uint64_t                customFeeSatoshis;

/**
 * Adds an address and amount to this spend request
 * @param address NSString Bitcoin public address to send funds to
 * @param amount uint64_t Amount of bitcoin to send in satoshis
 * @return NSError
 */
- (NSError *)addAddress:(NSString *)address amount:(uint64_t)amount;

/**
 * Adds a transfer of funds between ABCWallets in an account. The source
 * wallet is the wallet that created this ABCSpend and once the transaction
 * is sent, the source wallet is tagged with the metaData from this ABCSpend object.
 * The destWallet is tagged with metadata supplied in detaMeta
 * @param destWallet ABCWallet Destination wallet for transfer
 * @param amountSatoshi uint64_t Amount of transfer
 * @param destMeta ABCMetaData Metadata to tag the destination transaction with
 * @return NSError Error object. Nil if success
 */
- (NSError *)addTransfer:(ABCWallet *)destWallet amount:(uint64_t)amountSatoshi destMeta:(ABCMetaData *)destMeta;

/**
 * Adds a BIP70 payment request to this ABCSpend transaction. No amount parameter is
 * provided as the payment request always has the amount included. Generate an
 * ABCPaymentRequest object by calling parseURI then getPaymentRequest
 * @param paymentRequest ABCPaymentRequest object to add
 * @return NSError Error object. Nil if success
 */
- (NSError *)addPaymentRequest:(ABCPaymentRequest *)paymentRequest;

/**
 * Signs this send request and broadcasts it to the blockchain
 * @param error NSError object
 * @return ABCTransaction Transaction object
 */
- (ABCTransaction *)signBroadcastAndSave:(NSError **)error;

/**
 * Signs this send request and broadcasts it to the blockchain. Uses completion handlers
 * @param completionHandler Completion handler code block<br>
 * - *param* ABCTransaction Transaction object
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError error object
 * @return void
 */
- (void)signBroadcastAndSave:(void(^)(ABCTransaction *))completionHandler
                       error:(void(^)(NSError *error)) errorHandler;


/**
 * Calculate the amount of fees needed to send this transaction
 * @param error NSError (optional)
 * @return uint64_t Total fees required for this transaction
 */
- (uint64_t)getFees:(NSError **)error;
- (uint64_t)getFees;

/**
 * Calculate the amount of fees needed to send this transaction
 * @param completionHandler Completion handler code block which is called with uint64_t totalFees<br>
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
 * @param completionHandler Completion handler code block which is called with uint64_t totalFees<br>
 * - *param* uint64_t amountSpendable Total amount spendablein satoshis
 * @param errorHandler Error handler code block which is called with the following args<br>
 * - *param* NSError error object
 */
- (void)getMaxSpendable:(void(^)(uint64_t amountSpendable))completionHandler
                  error:(void(^)(NSError *error)) errorHandler;


- (ABCUnsentTx *)signTx:(NSError **)error;
- (void)signTx:(void(^)(ABCUnsentTx *unsentTx))completionHandler
         error:(void(^)(NSError *error)) errorHandler;


@end



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


