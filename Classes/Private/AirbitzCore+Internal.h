//
// AirbitzCore+Internal.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABC.h"
#import "AirbitzCore.h"
#import "ABCAccount+Internal.h"
#import "ABCConditionCode.h"
#import "ABCError.h"
#import "ABCKeychain+Internal.h"
#import "ABCLocalSettings.h"
#import "ABCRequest+Internal.h"
#import "ABCSettings+Internal.h"
#import "ABCSpend+Internal.h"
#import "ABCStrings.h"
#import "ABCTransaction.h"
#import "ABCAccount+Internal.h"
#import "ABCUtil.h"
#import "ABCWallet+Internal.h"

@interface AirbitzCore(Internal)

@property (atomic, strong) ABCLocalSettings         *localSettings;
@property (atomic, strong) ABCKeychain              *keyChain;
@property (atomic, strong) NSMutableArray           *loggedInUsers;

- (NSDate *)dateFromTimestamp:(int64_t) intDate;

@end

