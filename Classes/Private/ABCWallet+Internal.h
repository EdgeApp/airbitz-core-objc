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

- (id)initWithUser:(ABCAccount *) user;
- (void)handleSweepCallback:(NSString *)txid amount:(uint64_t)amount error:(NSError *)error;
- (void) loadTransactions;

@end
