//
//  ABCAccount+Internal.h
//  Airbitz
//

#import "ABCAccount.h"
#import "ABCContext+Internal.h"

@interface ABCAccount (Internal)

@property (atomic, strong)  ABCContext              *abc;
@property                   BOOL                    bNewDeviceLogin;
@property (atomic, copy)    NSString                *password;
@property (atomic, copy)    NSString                *loginKey;

- (void)login;
- (void)enterBackground;
- (void)enterForeground;
- (BOOL)didLoginExpire;
- (void)postToGenQRQueue:(void(^)(void))cb;
- (void)postToMiscQueue:(void(^)(void))cb;
- (void)postToWatcherQueue:(void(^)(void))cb;
- (void)postToDataQueue:(void(^)(void))cb;
- (ABCError *)setDefaultCurrency:(NSString *)currencyCode;
- (void)setConnectivity:(BOOL)hasConnectivity;
- (void)setupLoginPIN;
- (void)refreshWallets;
- (void)connectWatcher:(NSString *)uuid;
- (void)clearDataQueue;
- (BOOL)watcherExists:(NSString *)uuid;
- (id)initWithCore:(ABCContext *)airbitzCore;
- (void)free;
- (void)startQueues;
- (void)stopQueues;
- (int)dataOperationCount;
- (long) saveLogoutDate;
- (void)requestExchangeRateUpdate;
- (void)dataSyncAccount;
- (void)logoutAllowRelogin;
- (NSString *)getLoginKey:(ABCError **)error;

@end
