//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCSettings+Internal.h"
#import "AirbitzCore+Internal.h"


@interface ABCSettings ()

@property (nonatomic, strong) ABCAccount            *account;
@property (nonatomic, strong) ABCLocalSettings      *local;
@property (nonatomic, strong) ABCKeychain           *keyChain;
@property (nonatomic, strong) ABCError              *abcError;

@end

@implementation ABCSettings
{

}

- (id)init:(ABCAccount *)account localSettings:(ABCLocalSettings *)local keyChain:(ABCKeychain *)keyChain;
{
    self = [super init];
    self.account = account;
    self.local = local;
    self.keyChain = keyChain;
    return self;
}

- (NSError *)loadSettings;
{
    tABC_Error error;
    tABC_AccountSettings *pSettings = NULL;
    tABC_CC result = ABC_LoadAccountSettings([self.account.name UTF8String],
            [self.account.password UTF8String],
            &pSettings,
            &error);
    if (ABC_CC_Ok == result)
    {
        if ([self haveSettingsChanged:pSettings])
        {
            self.secondsAutoLogout = pSettings->secondsAutoLogout;
            self.defaultCurrency = [self.account.exchangeCache getCurrencyFromNum:pSettings->currencyNum];
            self.denomination = [ABCDenomination getDenominationForMultiplier:pSettings->bitcoinDenomination.satoshi];
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

            if (self.account.delegate)
            {
                if ([self.account.delegate respondsToSelector:@selector(abcAccountAccountChanged)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.account.delegate abcAccountAccountChanged];
                    });
                }
            }
        }
    }
    ABC_FreeAccountSettings(pSettings);
    [self.local loadAll];

    return [ABCError makeNSError:error];
}

- (NSError *)saveSettings;
{
    tABC_Error error;
    tABC_AccountSettings *pSettings;
    BOOL pinLoginChanged = NO;
    BOOL settingsChanged = NO;

    ABC_LoadAccountSettings([self.account.name UTF8String], [self.account.password UTF8String], &pSettings, &error);
    NSError *nserror = [ABCError makeNSError:error];

    if (!nserror)
    {
        if (pSettings->bDisablePINLogin != self.bDisablePINLogin)
            pinLoginChanged = settingsChanged = YES;
        int currencyNum = self.defaultCurrency.currencyNum;
        if ([self haveSettingsChanged:pSettings])
        {
            pSettings->secondsAutoLogout                      = self.secondsAutoLogout         ;
            pSettings->currencyNum                            = currencyNum                    ;
            pSettings->bitcoinDenomination.satoshi            = self.denomination.multiplier   ;
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

        if (settingsChanged)
        {
            ABC_UpdateAccountSettings([self.account.name UTF8String], [self.account.password UTF8String], pSettings, &error);
            NSError *nserror = [ABCError makeNSError:error];
            
            if (!nserror)
            {
                ABC_FreeAccountSettings(pSettings);
                [self.keyChain disableKeychainBasedOnSettings:self.account.name];
                [self.local saveAll];
            }
            if (self.account.delegate)
            {
                if ([self.account.delegate respondsToSelector:@selector(abcAccountAccountChanged)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.account.delegate abcAccountAccountChanged];
                    });
                }
            }
        }
    }

    return nserror;
}

- (BOOL) touchIDEnabled;
{
    if ([self.local.touchIDUsersDisabled indexOfObject:self.account.name] == NSNotFound &&
        [self.local.touchIDUsersEnabled  indexOfObject:self.account.name] != NSNotFound)
    {
        return YES;
    }
    return NO;

}

- (BOOL) enableTouchID;
{
    // Need a password to enable touchID until we get support for login handles
    if (!self.account.password) return NO;

    [self.local.touchIDUsersDisabled removeObject:self.account.name];
    [self.local.touchIDUsersEnabled addObject:self.account.name];
    [self.local saveAll];
    [self.keyChain updateLoginKeychainInfo:self.account.name
                             password:self.account.password
                           useTouchID:YES];

    return YES;
}

- (void) disableTouchID;
{
    // Disable TouchID in LocalSettings
    if (self.account.name)
    {
        [self.local.touchIDUsersDisabled addObject:self.account.name];
        [self.local.touchIDUsersEnabled removeObject:self.account.name];
        [self.local saveAll];
        [self.keyChain updateLoginKeychainInfo:self.account.name
                                 password:self.account.password
                               useTouchID:NO];
    }
}

- (BOOL) haveSettingsChanged:(tABC_AccountSettings *)pSettings;
{
    BOOL settingsChanged = NO;

    int currencyNum = self.defaultCurrency.currencyNum;
    
    if (
        !pSettings ||
        pSettings->bDisablePINLogin                       != self.bDisablePINLogin          ||
        pSettings->secondsAutoLogout                      != self.secondsAutoLogout         ||
        pSettings->currencyNum                            != currencyNum                    ||
        pSettings->bitcoinDenomination.satoshi            != self.denomination.multiplier   ||
        pSettings->bNameOnPayments                        != self.bNameOnPayments           ||
        pSettings->bSpendRequirePin                       != self.bSpendRequirePin          ||
        pSettings->spendRequirePinSatoshis                != self.spendRequirePinSatoshis   ||

        ![self isNSStringEqualToCString:self.firstName            cstring:pSettings->szFirstName         ] ||
        ![self isNSStringEqualToCString:self.lastName             cstring:pSettings->szLastName          ] ||
        ![self isNSStringEqualToCString:self.nickName             cstring:pSettings->szNickname          ] ||
        ![self isNSStringEqualToCString:self.fullName             cstring:pSettings->szFullName          ] ||
        ![self isNSStringEqualToCString:self.strPIN               cstring:pSettings->szPIN               ] ||
        ![self isNSStringEqualToCString:self.exchangeRateSource   cstring:pSettings->szExchangeRateSource] )
    {
        settingsChanged = YES;
    }
    return settingsChanged;
}

- (BOOL) isNSStringEqualToCString:(NSString *)string cstring:(char *)cstring
{
    NSString *str = string;
    char *cstr = cstring;
    
    if (!str)
        str = @"";
    
    if (!cstr)
        cstr = "";
    
    if ([str isEqualToString:[NSString stringWithUTF8String:cstr]])
        return YES;

    return NO;
}


@end