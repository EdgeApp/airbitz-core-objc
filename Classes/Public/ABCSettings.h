//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCContext.h"

@class ABCContext;
@class ABCKeychain;
@class ABCAccount;
@class ABCDenomination;

/**
 * ABCSettings represent settings for the associated ABCAccount. Like all other account info,
 * these settings are locally encrypted and synchronized between devices.
 * Must call [ABCSettings loadSettings] before reading and
 * [ABCSettings saveSettings] after writing
 */

@interface ABCSettings : NSObject

/// How many seconds after the app is backgrounded before the user should be auto logged out
@property (nonatomic) int secondsAutoLogout;

/// Default currency code for new wallets and for the account total on Wallets screen
@property (nonatomic) ABCCurrency          *defaultCurrency;

/// Current denomination for account (BTC, mBTC, or bits)
@property (nonatomic, strong) ABCDenomination *denomination;

/// Users first name (optional)
@property (nonatomic, copy) NSString* firstName;

/// Users last name (optional)
@property (nonatomic, copy) NSString* lastName;

/// Users nick name (optional)
@property (nonatomic, copy) NSString* nickName;

/// Users full name (read only) set by ABC as a combination of first, last, and nickname
@property (nonatomic, copy) NSString* fullName;

/// Preferred exchange rate source. Set to one of the values in ABCArrayExchanges
@property (nonatomic, copy) NSString* exchangeRateSource;

/// List of user override Bitcoin servers. Must be Electrum servers, one per line separated by '\n'. Must be of the format
/// stratum://[servername]:[port]
/// ie. stratum://electrum.mydomain.com:50001
/// User may have multiple servers each seperated by a newline '\n'
@property (nonatomic, copy) NSString* overrideBitcoinServerList;

/// If YES, payment request QR Codes and URIs should have the user's firstName, lastName, and nickName on the request
@property (nonatomic) bool bNameOnPayments;

/// Require a PIN on spend. This is not enforced by ABC but a reference for the GUI to verify
@property (nonatomic) bool bSpendRequirePin;

/// Use the bitcoin server override list
@property (nonatomic) bool bOverrideBitcoinServers;

/// Require a PIN if spending greater than spendRequirePinSatoshis. This is not enforced by ABC but a reference for the GUI to verify
@property (nonatomic) int64_t spendRequirePinSatoshis;

/**
 * Loads all settings into ABCSettings from encrypted storage
 * @return NSSError object
 */
- (ABCError *)loadSettings;

/**
 * Saves all settings from ABCSettings to encrypted storage
 * @return NSSError object
 */
- (ABCError *)saveSettings;

/**
 * Returns YES if touchID is allowed on this account and device
 * @return YES if allowed
 */
- (BOOL) touchIDEnabled;

/**
 * Enable touchID on this account and device. This may require the optional
 * password parameter if this account was logged into with out a password (ie. with PIN)
 * @param password (optional)
 * @return YES if successfully enabled
 */
- (BOOL) enableTouchID:(NSString *)password;
- (BOOL) enableTouchID;

/**
 * Disables TouchID for this account & device
 */
- (void) disableTouchID;
@end

