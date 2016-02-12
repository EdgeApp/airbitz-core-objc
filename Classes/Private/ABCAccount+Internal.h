//
//  ABCAccount+Internal.h
//  Airbitz
//

#import "AirbitzCore+Internal.h"

@interface ABCAccount (Internal)

@property (atomic, strong)   AirbitzCore             *abc;

- (void)login;
- (void)logout;
- (void)enterBackground;
- (void)enterForeground;
- (BOOL)didLoginExpire;
- (void)postToGenQRQueue:(void(^)(void))cb;
- (void)postToMiscQueue:(void(^)(void))cb;
- (void)postToWatcherQueue:(void(^)(void))cb;
- (void)postToDataQueue:(void(^)(void))cb;
- (ABCConditionCode)setDefaultCurrencyNum:(int)currencyNum;
- (void)restoreConnectivity;
- (void)lostConnectivity;
- (void)setupLoginPIN;
- (void)watchAddresses: (NSString *) walletUUID;
- (void)refreshWallets;
- (void)connectWatcher:(NSString *)uuid;
- (void)clearDataQueue;
- (BOOL)watcherExists:(NSString *)uuid;
- (id)initWithCore:(AirbitzCore *)airbitzCore;
- (void)free;
- (void)startQueues;
- (void)stopQueues;
- (int)dataOperationCount;
- (long) saveLogoutDate;
- (int) maxDecimalPlaces;

@end
