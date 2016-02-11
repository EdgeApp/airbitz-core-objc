//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCSettings.h"
#import <Foundation/Foundation.h>
#import "ABCError.h"
#import "AirbitzCore.h"
#import "ABCUtil.h"
#import "ABCKeychain.h"
#import "ABCLocalSettings.h"
#import "ABCUser+Internal.h"
#import "AirbitzCore+Internal.h"


@interface ABCSettings ()

@property (nonatomic, strong) ABCUser               *user;
@property (nonatomic, strong) ABCLocalSettings      *local;
@property (nonatomic, strong) ABCKeychain           *keyChain;
@property (nonatomic, strong) ABCError              *abcError;

@end

@implementation ABCSettings
{

}

- (id)init:(ABCUser *)user localSettings:(ABCLocalSettings *)local keyChain:(ABCKeychain *)keyChain;
{
    self = [super init];
    self.user = user;
    self.local = local;
    self.keyChain = keyChain;
    return self;
}

- (ABCConditionCode)loadSettings;
{
    tABC_Error error;
    tABC_AccountSettings *pSettings = NULL;
    tABC_CC result = ABC_LoadAccountSettings([self.user.name UTF8String],
            [self.user.password UTF8String],
            &pSettings,
            &error);
    if (ABC_CC_Ok == result)
    {
        if ([self haveSettingsChanged:pSettings])
        {
            self.minutesAutoLogout = pSettings->minutesAutoLogout;
            self.defaultCurrencyNum = pSettings->currencyNum;
            if (pSettings->bitcoinDenomination.satoshi > 0)
            {
                self.denomination = pSettings->bitcoinDenomination.satoshi;
                self.denominationType = (ABCDenomination) pSettings->bitcoinDenomination.denominationType;

                [self doSetDenominationLabel];
            }
            self.firstName            = pSettings->szFirstName          ? [NSString stringWithUTF8String:pSettings->szFirstName] : nil;
            self.lastName             = pSettings->szLastName           ? [NSString stringWithUTF8String:pSettings->szLastName] : nil;
            self.nickName             = pSettings->szNickname           ? [NSString stringWithUTF8String:pSettings->szNickname] : nil;
            self.fullName             = pSettings->szFullName           ? [NSString stringWithUTF8String:pSettings->szFullName] : nil;
            self.strPIN               = pSettings->szPIN                ? [NSString stringWithUTF8String:pSettings->szPIN] : nil;
            self.exchangeRateSource   = pSettings->szExchangeRateSource ? [NSString stringWithUTF8String:pSettings->szExchangeRateSource] : nil;

            self.bNameOnPayments = pSettings->bNameOnPayments;
            self.bSpendRequirePin = pSettings->bSpendRequirePin;
            self.spendRequirePinSatoshis = pSettings->spendRequirePinSatoshis;
            self.bDisablePINLogin = pSettings->bDisablePINLogin;

            if (self.user.delegate)
            {
                if ([self.user.delegate respondsToSelector:@selector(abcUserAccountChanged)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.user.delegate abcUserAccountChanged];
                    });
                }
            }
        }
    }
    ABC_FreeAccountSettings(pSettings);
    [self.local loadAll];

    return [self.abcError setLastErrors:error];
}

- (ABCConditionCode)saveSettings;
{
    tABC_Error error;
    tABC_AccountSettings *pSettings;
    BOOL pinLoginChanged = NO;
    BOOL settingsChanged = NO;

    ABC_LoadAccountSettings([self.user.name UTF8String], [self.user.password UTF8String], &pSettings, &error);

    if (ABCConditionCodeOk == [self.abcError setLastErrors:error])
    {
        if (pSettings->bDisablePINLogin != self.bDisablePINLogin)
            pinLoginChanged = settingsChanged = YES;
        if ([self haveSettingsChanged:pSettings])
        {
            pSettings->minutesAutoLogout                      = self.minutesAutoLogout         ;
            pSettings->currencyNum                            = self.defaultCurrencyNum        ;
            pSettings->bitcoinDenomination.satoshi            = self.denomination              ;
            pSettings->bitcoinDenomination.denominationType   = (int) self.denominationType    ;
            pSettings->bNameOnPayments                        = self.bNameOnPayments           ;
            pSettings->bSpendRequirePin                       = self.bSpendRequirePin          ;
            pSettings->spendRequirePinSatoshis                = self.spendRequirePinSatoshis   ;

            self.firstName          ? [ABCUtil replaceString:&(pSettings->szFirstName         ) withString:[self.firstName          UTF8String]] : nil;
            self.lastName           ? [ABCUtil replaceString:&(pSettings->szLastName          ) withString:[self.lastName           UTF8String]] : nil;
            self.nickName           ? [ABCUtil replaceString:&(pSettings->szNickname          ) withString:[self.nickName           UTF8String]] : nil;
            self.fullName           ? [ABCUtil replaceString:&(pSettings->szFullName          ) withString:[self.fullName           UTF8String]] : nil;
            self.strPIN             ? [ABCUtil replaceString:&(pSettings->szPIN               ) withString:[self.strPIN             UTF8String]] : nil;
            self.exchangeRateSource ? [ABCUtil replaceString:&(pSettings->szExchangeRateSource) withString:[self.exchangeRateSource UTF8String]] : nil;
            settingsChanged = YES;
        }

        if (pinLoginChanged)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {

                if (self.bDisablePINLogin)
                {
                    [self deletePINLogin];
                }
                else
                {
                    [self setupLoginPIN];
                }
            });
        }

        if (settingsChanged)
        {
            [self doSetDenominationLabel];
            ABC_UpdateAccountSettings([self.user.name UTF8String], [self.user.password UTF8String], pSettings, &error);
            if (ABCConditionCodeOk == [self.abcError setLastErrors:error])
            {
                ABC_FreeAccountSettings(pSettings);
                [self.keyChain disableKeychainBasedOnSettings:self.user.name];
                [self.local saveAll];
            }
            if (self.user.delegate)
            {
                if ([self.user.delegate respondsToSelector:@selector(abcUserAccountChanged)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.user.delegate abcUserAccountChanged];
                    });
                }
            }
        }
    }

    return (ABCConditionCode) error.code;
}

- (void)deletePINLogin
{
    NSString *username = NULL;
    if ([self.user isLoggedIn])
    {
        username = self.user.name;
    }

    tABC_Error error;
    if (username && 0 < username.length)
    {
        tABC_CC result = ABC_PinLoginDelete([username UTF8String],
                &error);
        if (ABC_CC_Ok != result)
        {
            [self.abcError setLastErrors:error];
        }
    }
}



- (void)setupLoginPIN
{
    if (!self.bDisablePINLogin)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
            tABC_Error error;
            ABC_PinSetup([self.user.name UTF8String],
                    [self.user.password length] > 0 ? [self.user.password UTF8String] : nil,
                    &error);
        });
    }
}

- (BOOL) touchIDEnabled;
{
    if ([self.local.touchIDUsersDisabled indexOfObject:self.user.name] == NSNotFound &&
        [self.local.touchIDUsersEnabled  indexOfObject:self.user.name] != NSNotFound)
    {
        return YES;
    }
    return NO;

}

- (BOOL) enableTouchID;
{
    // Need a password to enable touchID until we get support for login handles
    if (!self.user.password) return NO;

    [self.local.touchIDUsersDisabled removeObject:self.user.name];
    [self.local.touchIDUsersEnabled addObject:self.user.name];
    [self.local saveAll];
    [self.keyChain updateLoginKeychainInfo:self.user.name
                             password:self.user.password
                           useTouchID:YES];

    return YES;
}

- (void) disableTouchID;
{
    // Disable TouchID in LocalSettings
    if (self.user.name)
    {
        [self.local.touchIDUsersDisabled addObject:self.user.name];
        [self.local.touchIDUsersEnabled removeObject:self.user.name];
        [self.local saveAll];
        [self.keyChain updateLoginKeychainInfo:self.user.name
                                 password:self.user.password
                               useTouchID:NO];
    }
}

- (BOOL) haveSettingsChanged:(tABC_AccountSettings *)pSettings;
{
    BOOL settingsChanged = NO;
    if (!pSettings)
        return YES;
    
    if (
            !pSettings ||
            pSettings->bDisablePINLogin                       != self.bDisablePINLogin          ||
            pSettings->minutesAutoLogout                      != self.minutesAutoLogout         ||
            pSettings->currencyNum                            != self.defaultCurrencyNum        ||
            pSettings->bitcoinDenomination.satoshi            != self.denomination              ||
            pSettings->bitcoinDenomination.denominationType   != (int) self.denominationType    ||
            pSettings->bNameOnPayments                        != self.bNameOnPayments           ||
            pSettings->bSpendRequirePin                       != self.bSpendRequirePin          ||
            pSettings->spendRequirePinSatoshis                != self.spendRequirePinSatoshis   ||

            !pSettings->szFirstName ||
        !pSettings->szLastName ||
        !pSettings->szNickname ||
        !pSettings->szFullName ||
        !pSettings->szPIN ||
        !pSettings->szExchangeRateSource ||
            ![self.firstName isEqualToString:               [NSString stringWithUTF8String:pSettings->szFirstName         ]] ||
            ![self.lastName isEqualToString:                [NSString stringWithUTF8String:pSettings->szLastName          ]] ||
            ![self.nickName isEqualToString:                [NSString stringWithUTF8String:pSettings->szNickname          ]] ||
            ![self.fullName isEqualToString:                [NSString stringWithUTF8String:pSettings->szFullName          ]] ||
            ![self.strPIN isEqualToString:                  [NSString stringWithUTF8String:pSettings->szPIN               ]] ||
            ![self.exchangeRateSource isEqualToString:      [NSString stringWithUTF8String:pSettings->szExchangeRateSource]] )
    {
        settingsChanged = YES;
    }
    return settingsChanged;

}

- (void)doSetDenominationLabel
{
    switch (self.denominationType) {
        case ABCDenominationBTC:
            self.denominationLabel = @"BTC";
            self.denominationLabelShort = @"Ƀ ";
            break;
        case ABCDenominationMBTC:
            self.denominationLabel = @"mBTC";
            self.denominationLabelShort = @"mɃ ";
            break;
        case ABCDenominationUBTC:
            self.denominationLabel = @"bits";
            self.denominationLabelShort = @"ƀ ";
            break;

    }
}

@end