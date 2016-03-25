//
// ABCWallet+Internal.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCWallet.h"
#import "AirbitzCore+Internal.h"

@class ABCAccount;

@interface ABCWallet (Internal)

@property                           BOOL                bAddressesLoaded;
@property                           BOOL                bBlockHeightChanged;

- (id)initWithUser:(ABCAccount *) user;
- (void)handleSweepCallback:(ABCTransaction *)transaction amount:(uint64_t)amount error:(NSError *)error;
- (void)loadTransactions;
- (void)loadWalletFromCore:(NSString *)uuid;
- (int)getBlockHeight:(NSError **)nserror;


@end
