//
//  ABCTransaction.h
//  AirBitz
//
//  Created by Adam Harris on 3/3/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "AirbitzCore.h"

@class ABCWallet;
@class ABCMetaData;

@interface ABCTransaction : NSObject

/// ABCWallet object this transaction is from
@property (nonatomic, strong)   ABCWallet       *wallet;

/// ABCMetaData associated with this transaction
@property (nonatomic, strong)   ABCMetaData     *metaData;

/// Txid of this transaction
@property (nonatomic, copy)     NSString        *txid;

/// Date this transaction was detected. Note that at this time, Airbitz has
/// a pending issue where the date is marked as the date the transaction is
/// detected by the wallet, not necessarily when it was broadcast or confirmed.
/// If a wallet is not running, it will not properly detect a transaction and
/// have the correct date stamp
@property (nonatomic, strong)   NSDate          *date;

/// Block height that this transaction confirmed. 0 if unconfirmed
@property (nonatomic, assign)   unsigned long   height;

/// Amount of this transaction in satoshis. Amount is negative for outgoing spends
@property (nonatomic, assign)   SInt64			amountSatoshi;

/// Total amount of miner fees of this transaction
@property (nonatomic, assign)   SInt64			minerFees;

/// Amount of provider fees of transaction. Provider fees are optional fees charged by
/// the operator of wallet SDK. The Airbitz mobile app charges no provider fees
@property (nonatomic, assign)   SInt64          providerFee;

/// This transaction has the Replace by Fee (RBF) flag set. User should be warned that
/// this transaction can be easily double spent
@property (nonatomic, assign)   BOOL            isReplaceByFee;

/// This transaction has been detected to have a double spend attempt on its inputs
@property (nonatomic, assign)   BOOL            isDoubleSpend;

/// The current running balance of the wallet as of this transaction
@property (nonatomic, assign)   SInt64          balance;

/// Array of ABCTxInOut objects
@property (nonatomic, strong)   NSArray         *inputOutputList;



- (void)saveTransactionDetails;

@end
