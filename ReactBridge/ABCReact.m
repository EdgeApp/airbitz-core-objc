//
//  ABCReact.m
//  AirBitz
//

#import "RCTUtils.h"
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"
#import "ABCReact.h"

@interface AirbitzCoreRCT () <ABCAccountDelegate>
{
}
@end

AirbitzCore *abc = nil;
ABCAccount *abcAccount = nil;

@implementation AirbitzCoreRCT

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
                  error:(RCTResponseSenderBlock)error)
{
    if (!abc)
    {
        abc = [[AirbitzCore alloc] init:abcAPIKey hbits:hbitsKey];
        if (!abc)
        {
            error([self makeError:ABCConditionCodeError
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
        error([self makeError:ABCConditionCodeReinitialization
                    description:@"ABC Already Initialized"]);
        return;
    }
}

RCT_EXPORT_METHOD(createAccount:(NSString *)username
                  password:(NSString *)password
                  pin:(NSString *)pin
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
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
    
    [abc createAccount:username
              password:password
                   pin:pin
              delegate:self
              complete:^(ABCAccount *account)
     {
         abcAccount = account;
         complete(@[[NSNull null], account.name]);
     }
                 error:^(NSError *nserror)
     {
         error([self makeErrorFromNSError:nserror]);
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
        error([self makeErrorABCNotInitialized]);
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
        complete(@[[NSNull null], account.name]);
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
                  error:(RCTResponseSenderBlock)error)
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
    
    [abc pinLogin:username pin:pin delegate:self complete:^(ABCAccount *account) {
        abcAccount = account;
        complete(@[[NSNull null], account.name]);
    } error:^(NSError *nserror) {
        error([self makeErrorFromNSError:nserror]);
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
                  error:(RCTResponseSenderBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    [abcAccount changePassword:password complete:^{
        complete(@[[NSNull null]]);
    } error:^(NSError *nserror) {
        error([self makeErrorFromNSError:nserror]);
    }];
}

RCT_EXPORT_METHOD(changePIN:(NSString *)pin
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    [abcAccount changePIN:pin complete:^{
        complete(@[[NSNull null]]);
    } error:^(NSError *nserror) {
        error([self makeErrorFromNSError:nserror]);
    }];
}



RCT_EXPORT_METHOD(accountHasPassword:(NSString *)accountName
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    ABC_CHECK_ACCOUNT();

    NSError *nserror;
    BOOL hasPassword = [abc accountHasPassword:accountName error:&nserror];
    
    if (nserror)
        error([self makeErrorFromNSError:nserror]);
    else
        complete(@[[NSNull null], [NSNumber numberWithBool:hasPassword]]);
}

RCT_EXPORT_METHOD(checkPassword:(NSString *)password
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    BOOL pass = [abcAccount checkPassword:password];
    complete(@[[NSNull null], [NSNumber numberWithBool:pass]]);
}

RCT_EXPORT_METHOD(pinLoginSetup:(BOOL)enable
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount pinLoginSetup:enable];
    if (nserror)
        error([self makeErrorFromNSError:nserror]);
    else
        complete(@[[NSNull null]]);
}

#pragma mark ABCAccountDelegate

@synthesize bridge = _bridge;

- (void) abcAccountWalletLoaded:(ABCWallet *)wallet;
{
    
    
    ABCLog(0, @"abcAccountWalletLoaded");
    
    [self.bridge.eventDispatcher sendAppEventWithName:@"abcAccountWalletLoaded"
                                                 body:@{@"uuid": wallet.uuid}];
    
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
        ABCLog(0, @"abcAccountAccountChanged");
        
        [self.bridge.eventDispatcher sendAppEventWithName:@"abcAccountAccountChanged"
                                                     body:@{@"name": abcAccount.name}];

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

#pragma mark Return Parameter utility methods

//
// To standardize between React Native on ObjC and Android, all methods use two callbacks of type RCTResponseSenderBlock.
// One for success (complete) and one for failure (error). RCTResponseSenderBlock takes an NSArray but the first element
// is only for errors. For ABC we always send NSNull for the first argument and return parameters in the 2nd argument.
// Convention shall be that if there is only one return parameter, it is simply the 2nd array argument. If there is more than one,
// It shall be encoded as a Json string. Error parameters are returned the same way as success parameters but are simply
// differentiated by the callback
//
// Errors are always encoded as a string encoding of a Json array with the first parameter as the integer error cod
// and 2nd, 3rd, and 4th parameters as descriptions.
//

- (NSString *) makeJsonFromObj:(id)obj;
{
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:&error];
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
}

- (NSArray *) makeErrorFromNSError:(NSError *)error;
{
    return [self makeError:(ABCConditionCode)error.code
               description:error.userInfo[NSLocalizedDescriptionKey]
              description2:error.userInfo[NSLocalizedFailureReasonErrorKey]
              description3:error.userInfo[NSLocalizedRecoverySuggestionErrorKey]];
}

- (NSArray *)makeError:(ABCConditionCode)code
           description:(NSString *)description;
{ return [self makeError:code description:description description2:nil description3:nil]; }

- (NSArray *)makeError:(ABCConditionCode)code
           description:(NSString *)description
          description2:(NSString *)description2;
{ return [self makeError:code description:description description2:description2 description3:nil]; }

- (NSArray *)makeError:(ABCConditionCode)code
           description:(NSString *)description
          description2:(NSString *)description2
          description3:(NSString *)description3;
{
    if (ABCConditionCodeOk == code)
    {
        return @[[NSNull null]];
    }
    else
    {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        
        [dict setObject:[NSNumber numberWithInt:(int) code] forKey:@"code"];
        if (description && [description length])
            [dict setObject:description forKey:@"description"];
        if (description2 && [description2 length])
            [dict setObject:description2 forKey:@"description2"];
        if (description3 && [description3 length])
            [dict setObject:description2 forKey:@"description3"];
        
        return [self makeResponseFromObj:dict];
    }
}

- (NSArray *)makeArrayResponse:(id)obj1 obj2:(id)obj2;
{ return [self makeArrayResponse:obj1 obj2:obj2 obj3:nil obj4:nil]; }

- (NSArray *)makeArrayResponse:(id)obj1 obj2:(id)obj2 obj3:(id)obj3;
{ return [self makeArrayResponse:obj1 obj2:obj2 obj3:obj3 obj4:nil]; }

- (NSArray *)makeArrayResponse:(id)obj1 obj2:(id)obj2 obj3:(id)obj3 obj4:(id)obj4;
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    if (obj1)
        [array addObject:obj1];
    if (obj2)
        [array addObject:obj2];
    if (obj3)
        [array addObject:obj3];
    if (obj4)
        [array addObject:obj4];
    NSString *json = [self makeJsonFromObj:array];
    return @[[NSNull null], json];
}

- (NSArray *)makeResponseFromObj:(id)obj1;
{
    NSString *json = [self makeJsonFromObj:obj1];
    return @[[NSNull null], json];
}


- (NSArray *)makeErrorABCNotInitialized;
{
    return [self makeError:ABCConditionCodeNotInitialized description:@"ABC Not Initialized"];
}

- (NSArray *)makeErrorNotLoggedIn;
{
    return [self makeError:ABCConditionCodeError description:@"Not logged in"];
}



@end
