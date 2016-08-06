//
// AirbitzCore+Internal.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABC.h"
#import "AirbitzCore.h"
#import "ABCAccount+Internal.h"
#import "ABCCategories+Internal.h"
#import "ABCCurrency+Internal.h"
#import "ABCDataStore+Internal.h"
#import "ABCError+Internal.h"
#import "ABCExchangeCache+Internal.h"
#import "ABCKeychain+Internal.h"
#import "ABCLocalSettings.h"
#import "ABCMetaData+Internal.h"
#import "ABCParsedURI+Internal.h"
#import "ABCReceiveAddress+Internal.h"
#import "ABCSettings+Internal.h"
#import "ABCSpend+Internal.h"
#import "ABCStrings.h"
#import "ABCTransaction+Internal.h"
#import "ABCAccount+Internal.h"
#import "ABCWallet+Internal.h"

@interface AirbitzCore(Internal)

@property (atomic, strong) ABCLocalSettings         *localSettings;
@property (atomic, strong) ABCKeychain              *keyChain;
@property (atomic, strong) NSMutableArray           *loggedInUsers;
@property (atomic, strong) ABCExchangeCache         *exchangeCache;
@property (atomic, strong) NSOperationQueue         *exchangeQueue;

- (NSDate *)dateFromTimestamp:(int64_t) intDate;
- (ABCError *)setupOTPKey:(NSString *)username
                   key:(NSString *)key;

@end

