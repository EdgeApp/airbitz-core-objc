//
// ABCKeychain+Internal.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCKeychain.h"
#import "ABCContext+Internal.h"

#define PASSWORD_KEY            @"key_password"
#define LOGINKEY_KEY            @"key_loginkey"
#define RELOGIN_KEY             @"key_relogin"
#define USE_TOUCHID_KEY         @"key_use_touchid"
#define LOGOUT_TIME_KEY         @"key_logout_time"
#define RECOVERY2_KEY           @"key_recovery2"
#define SEC_ATTR_SERVICE        @"co.airbitz.airbitz"

@class ABCSettings;
@class ABCLocalSettings;

@interface ABCKeychain(Internal)

@property (nonatomic) ABCLocalSettings *localSettings;

- (id) init:(ABCContext *)abc;
- (BOOL) setKeychainData:(NSData *)data key:(NSString *)key authenticated:(BOOL) authenticated;
- (NSData *) getKeychainData:(NSString *)key error:(ABCError **)error;
- (BOOL) setKeychainString:(NSString *)s key:(NSString *)key authenticated:(BOOL) authenticated;
- (BOOL) setKeychainInt:(int64_t) i key:(NSString *)key authenticated:(BOOL) authenticated;
- (int64_t) getKeychainInt:(NSString *)key error:(ABCError **)error;
- (NSString *) getKeychainString:(NSString *)key error:(ABCError **)error;
- (NSString *) createKeyWithUsername:(NSString *)username key:(NSString *)key;
- (BOOL) bHasSecureEnclave;
- (void)authenticateTouchID:(NSString *)promptString fallbackString:(NSString *)fallbackString
                   complete:(void (^)(BOOL didAuthenticate)) completionHandler;
- (void) disableRelogin:(NSString *)username;
- (void) disableTouchID:(NSString *)username;
- (BOOL) disableKeychainBasedOnSettings:(NSString *)username;
- (void) clearKeychainInfo:(NSString *)username;
- (void) updateLoginKeychainInfo:(NSString *)username
                        loginKey:(NSString *)key
                      useTouchID:(BOOL) bUseTouchID;
@end
