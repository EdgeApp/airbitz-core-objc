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

@property (nonatomic, strong)   ABCWallet       *wallet;
@property (nonatomic, strong)   ABCMetaData     *metaData;
@property (nonatomic, copy)     NSString        *txid;
@property (nonatomic, copy)     NSString        *malleableTxid;
@property (nonatomic, strong)   NSDate          *date;
@property (nonatomic, assign)   BOOL            bConfirmed;
@property (nonatomic, assign)   BOOL            bSyncing;
@property (nonatomic, assign)   int             confirmations;
@property (nonatomic, assign)   SInt64			amountSatoshi;
@property (nonatomic, assign)   SInt64			minerFees;
@property (nonatomic, assign)   SInt64          providerFee;
@property (nonatomic, assign)   SInt64          balance;
@property (nonatomic, strong)   NSArray         *outputList;
@property (nonatomic, strong)   NSArray         *inputList;

- (void)saveTransactionDetails;

@end
