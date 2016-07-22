//
//  ABCReact.m
//  AirBitz
//

#import "RCTUtils.h"
#import "RCTBridgeModule.h"
#import "ABCReact.h"

@interface AirbitzCoreRCT () <ABCAccountDelegate>
{
}
@end

AirbitzCore *abc = nil;
ABCAccount *abcAccount = nil;

@implementation AirbitzCoreRCT

- (NSArray *) makeErrorArray:(NSError *)error;
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:[NSString stringWithFormat:@"%d", (int)error.code]];
    [array addObject:error.userInfo[NSLocalizedDescriptionKey]];
    [array addObject:error.userInfo[NSLocalizedFailureReasonErrorKey]];
    [array addObject:error.userInfo[NSLocalizedRecoverySuggestionErrorKey]];
    return array;
}

- (NSError *)makeNSError:(ABCConditionCode)code description:(NSString *)description;
{
    if (ABCConditionCodeOk == code)
    {
        return nil;
    }
    else
    {
        if (!description)
            description = @"";
        
        return [NSError errorWithDomain:ABCErrorDomain
                                   code:code
                               userInfo:@{ NSLocalizedDescriptionKey:description }];
    }
}

- (NSError *)makeErrorABCNotInitialized;
{
    return [self makeNSError:ABCConditionCodeNotInitialized description:@"ABC Not Initialized"];
}

- (NSError *)makeErrorNotLoggedIn;
{
    return [self makeNSError:ABCConditionCodeError description:@"Not logged in"];
}

#define ABC_CHECK_ACCOUNT() \
    if (!abc) \
    { \
        error([self makeErrorABCNotInitialized]); \
        return; \
    } \
    if (!abcAccount) { \
        error([self makeErrorNotLoggedIn]); \
        return; \
    }

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    if (!abc)
    {
        abc = [[AirbitzCore alloc] init:abcAPIKey hbits:hbitsKey];
        if (!abc)
        {
            error([self makeNSError:ABCConditionCodeError
                        description:@"Error initializing ABC"]);
            return;
        }
        else
        {
            complete(@[[NSNull null]]);
            return;
        }
    }
    else
    {
        // Already initialized
        error([self makeNSError:ABCConditionCodeReinitialization
                    description:@"ABC Already Initialized"]);
        return;
    }
}

RCT_EXPORT_METHOD(createAccount:(NSString *)username
                  password:(NSString *)password
                  pin:(NSString *)pin
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    if (!abc)
    {
        error([self makeErrorABCNotInitialized]);
        return;
    }
    if (abcAccount)
    {
        [abcAccount logout];
        abcAccount = nil;
    }
    
    [abc createAccount:username
              password:password
                   pin:pin
              delegate:self
              complete:^(ABCAccount *account)
     {
         abcAccount = account;
         [array addObject:[NSNull null]];
         [array addObject:account.name];
         complete(array);
     }
                 error:^(NSError *nserror)
     {
         error(nserror);
     }];
}

RCT_EXPORT_METHOD(passwordLogin:(NSString *)username
                  password:(NSString *)password
                  otpToken:(NSString *)otp
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    if (!abc)
    {
        error([self makeErrorArray:[self makeNSError:ABCConditionCodeNotInitialized
                                         description:@"ABC Not Initialized"]]);
        return;
    }
    if (abcAccount)
    {
        [abcAccount logout];
        abcAccount = nil;
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [abc passwordLogin:username password:password delegate:self otp:otp complete:^(ABCAccount *account) {
        abcAccount = account;
        [array addObject:[NSNull null]];
        [array addObject:account.name];
        complete(array);
    } error:^(NSError *nserror, NSDate *otpResetDate, NSString *otpResetToken) {
        [array addObject:[NSNull null]];
        [array addObject:[NSString stringWithFormat:@"%d", (int) nserror.code]];
        [array addObject:[NSString stringWithFormat:@"%lu", (unsigned long) [otpResetDate timeIntervalSince1970]]];
        [array addObject:otpResetToken];
    }];
}

RCT_EXPORT_METHOD(pinLogin:(NSString *)username
                  pin:(NSString *)pin
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    if (!abc)
    {
        error([self makeErrorABCNotInitialized]);
        return;
    }
    if (abcAccount)
    {
        [abcAccount logout];
        abcAccount = nil;
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [abc pinLogin:username pin:pin delegate:self complete:^(ABCAccount *account) {
        abcAccount = account;
        [array addObject:[NSNull null]];
        [array addObject:account.name];
        complete(array);
    } error:^(NSError *nserror) {
        error(nserror);
    }];
}

RCT_EXPORT_METHOD(logout:(RCTResponseSenderBlock)complete)
{
    if (abc)
    {
        if (abcAccount)
        {
            [abcAccount logout];
        }
    }
    complete(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(changePassword:(NSString *)password
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    [abcAccount changePassword:password complete:^{
        complete(@[[NSNull null]]);
    } error:^(NSError *nserror) {
        error(nserror);
    }];
}

RCT_EXPORT_METHOD(changePIN:(NSString *)pin
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    [abcAccount changePIN:pin complete:^{
        complete(@[[NSNull null]]);
    } error:^(NSError *nserror) {
        error(nserror);
    }];
}



RCT_EXPORT_METHOD(accountHasPassword:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    ABC_CHECK_ACCOUNT();

    NSError *nserror;
    [abcAccount accountHasPassword:&nserror];
    
    if (nserror)
        error(nserror);
    else
        complete(@[[NSNull null], [NSNumber numberWithBool:YES]]);
}

RCT_EXPORT_METHOD(checkPassword:(NSString *)password
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    BOOL pass = [abcAccount checkPassword:password];
    complete(@[[NSNull null], [NSNumber numberWithBool:pass]]);
}

RCT_EXPORT_METHOD(pinLoginSetup:(BOOL)enable
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseErrorBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount pinLoginSetup:enable];
    if (nserror)
        error(nserror);
    else
        complete(@[[NSNull null]]);
}

#pragma mark ABCAccountDelegate

- (void) abcAccountWalletLoaded:(ABCWallet *)wallet;
{
//    if (!wallet)
//        ABCLog(1, @"abcAccountWalletLoaded:wallet == NULL");
//    else
//        ABCLog(1, @"abcAccountWalletLoaded UUID=%@", wallet.uuid);
//    
//    if (!abcAccount.arrayWallets)
//        ABCLog(1, @"abcAccountWalletLoaded:Assertion Failed. arrayWallet == NULL");
//    
//    if (abcAccount.arrayWallets && abcAccount.arrayWallets[0] && wallet)
//    {
//        if ([wallet.uuid isEqualToString:((ABCWallet *)abcAccount.arrayWallets[0]).uuid])
//        {
//            if (_bShowingWalletsLoadingAlert)
//            {
//                [FadingAlertView dismiss:FadingAlertDismissFast];
//                [MiniDropDownAlertView dismiss:NO];
//            }
//            _bShowingWalletsLoadingAlert = NO;
//            _bDoneShowingWalletsLoadingAlert = YES;
//        }
//    }
//    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_WALLETS_CHANGED object:self userInfo:nil];
}

- (void) abcAccountAccountChanged;
{
    if (abcAccount)
    {
        
    }
//    [self updateWidgetQRCode];
//    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_WALLETS_CHANGED object:self userInfo:nil];
//    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DATA_SYNC_UPDATE object:self];
    
}
- (void)abcAccountLoggedOut:(ABCAccount *)user;
{
//    [[User Singleton] clear];
//    _bShowingWalletsLoadingAlert = NO;
//    _bDoneShowingWalletsLoadingAlert = NO;
//    
//    [slideoutView showSlideout:NO withAnimation:NO];
//    
//    _appMode = APP_MODE_WALLETS;
//    self.tabBar.selectedItem = self.tabBar.items[_appMode];
//    [self loadUserViews];
//    [self resetViews];
//    [MainViewController hideTabBarAnimated:NO];
//    [MainViewController hideNavBarAnimated:NO];
//    abcAccount = nil;
}

- (void) abcAccountRemotePasswordChange;
{
//    if (_passwordChangeAlert == nil && [User isLoggedIn])
//    {
//        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
//        [self resetViews];
//        _passwordChangeAlert = [[UIAlertView alloc] initWithTitle:passwordChangeText
//                                                          message:passwordToAccountChangeText
//                                                         delegate:self
//                                                cancelButtonTitle:nil
//                                                otherButtonTitles:okButtonText, nil];
//        [_passwordChangeAlert show];
//        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
//    }
}

- (void) abcAccountIncomingBitcoin:(ABCWallet *)wallet transaction:(ABCTransaction *)transaction;
{
//    if (wallet) _strWalletUUID = wallet.uuid;
//    _strTxID = transaction.txid;
//    
//    /* If showing QR code, launch receiving screen*/
//    if (_selectedViewController == _requestViewController
//        && [_requestViewController showingQRCode:_strWalletUUID withTx:_strTxID])
//    {
//        RequestState state;
//        
//        //
//        // Let the RequestViewController know a Tx came in for the QR code it's currently scanning.
//        // If it returns kDone as the state. Transition to Tx Details.
//        //
//        state = [_requestViewController updateQRCode:transaction.amountSatoshi];
//        
//        if (state == kDone)
//        {
//            [self handleReceiveFromQR:_strWalletUUID withTx:_strTxID];
//        }
//        
//    }
//    // Prevent displaying multiple alerts
//    else if (_receivedAlert == nil)
//    {
//        if (transaction && transaction.amountSatoshi >= 0) {
//            NSString *title = receivedFundsText;
//            NSString *amtString = [abcAccount.settings.denomination satoshiToBTCString:transaction.amountSatoshi withSymbol:YES cropDecimals:YES];
//            NSString *msg = [NSString stringWithFormat:bitcoinReceivedTapText, amtString];
//            [[AudioController controller] playReceived];
//            _receivedAlert = [[UIAlertView alloc]
//                              initWithTitle:title
//                              message:msg
//                              delegate:self
//                              cancelButtonTitle:cancelButtonText
//                              otherButtonTitles:okButtonText, nil];
//            [_receivedAlert show];
//            // Wait 5 seconds and dimiss
//            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
//            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
//                if (_receivedAlert)
//                {
//                    [_receivedAlert dismissWithClickedButtonIndex:0 animated:YES];
//                }
//            });
//        }
//    }
//    
//    //
//    // If we just received money on the currentWallet then update the Widget's address & QRcode
//    //
//    if ([_strWalletUUID isEqualToString:abcAccount.currentWallet.uuid])
//    {
//        [self updateWidgetQRCode];
//    }
}

- (void)abcAccountOTPRequired;
{
//    if (_otpRequiredAlert == nil) {
//        _otpRequiredAlert = [[UIAlertView alloc]
//                             initWithTitle:tfaOnText
//                             message:tfaEnabledFromDifferentDeviceText
//                             delegate:self
//                             cancelButtonTitle:remindMeLaterText
//                             otherButtonTitles:enableButtonText, nil];
//        [_otpRequiredAlert show];
//    }
}

- (void)abcAccountOTPSkew
{
//    if (_otpSkewAlert == nil) {
//        _otpSkewAlert = [[UIAlertView alloc]
//                         initWithTitle:tfaInvalidText
//                         message:tfaTokenOnThisDeviceInvalidText
//                         delegate:self
//                         cancelButtonTitle:okButtonText
//                         otherButtonTitles:nil, nil];
//        [_otpSkewAlert show];
//    }
}



@end
