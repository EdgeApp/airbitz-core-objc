//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

@class AirbitzCore;
@class ABCKeychain;
@class ABCAccount;
@class ABCDenomination;

#define ABCArrayExchanges     @[@"Bitstamp", @"BraveNewCoin", @"Coinbase", @"CleverCoin"]

@interface ABCSettings : NSObject

/// @name User Settings that are synced across devices
/// Must call [ABCSettings loadSettings] before reading and
/// [ABCSettings saveSettings] after writing

/// How many seconds after the app is backgrounded before the user should be auto logged out
@property (nonatomic) int secondsAutoLogout;

/// Default currency code for new wallets and for the account total on Wallets screen
@property (nonatomic) ABCCurrency          *defaultCurrency;

@property (nonatomic, strong) ABCDenomination *denomination;
@property (nonatomic, copy) NSString* firstName;
@property (nonatomic, copy) NSString* lastName;
@property (nonatomic, copy) NSString* nickName;
@property (nonatomic, copy) NSString* fullName;
@property (nonatomic, copy) NSString* exchangeRateSource;
@property (nonatomic) bool bNameOnPayments;
@property (nonatomic) bool bSpendRequirePin;
@property (nonatomic) int64_t spendRequirePinSatoshis;

/// Loads all settings into [ABCSettings] structure
- (NSError *)loadSettings;

/// Saves all settings from [ABCSettings] structure
- (NSError *)saveSettings;

- (BOOL) touchIDEnabled;
- (BOOL) enableTouchID;
- (BOOL) enableTouchID:(NSString *)password;
- (void) disableTouchID;

@end

