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
        callback([self makeErrorABCNotInitialized]); \
        return; \
    } \
    if (!abcAccount) { \
        callback([self makeErrorNotLoggedIn]); \
        return; \
    }

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        abc = [AirbitzCore makeABCContext:abcAPIKey hbits:hbitsKey];
        if (!abc)
        {
            callback([self makeError:ABCConditionCodeError
                        message:@"Error initializing ABC"]);
            return;
        }
        else
        {
            callback(@[[NSNull null]]);
            return;
        }
    }
    else
    {
        // Already initialized
        callback([self makeError:ABCConditionCodeReinitialization
                    message:@"ABC Already Initialized"]);
        return;
    }
}

// -------------------------------------------------------------------------------
#pragma mark - AirbitzCore methods
// -------------------------------------------------------------------------------

RCT_EXPORT_METHOD(createAccount:(NSString *)username
                  password:(NSString *)password
                  pin:(NSString *)pin
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
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
              callback:^(ABCError *error, ABCAccount *account)
     {
         abcAccount = account;
         callback([self makeErrorOrResponseFromNSError:error obj:account.name]);
     }];
}

RCT_EXPORT_METHOD(loginWithPassword:(NSString *)username
                  password:(NSString *)password
                  otpToken:(NSString *)otp
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }
    if (abcAccount)
    {
        [abcAccount logout];
        abcAccount = nil;
    }
    
    [abc loginWithPassword:username password:password delegate:self otp:otp
                  callback:^(ABCError *error, ABCAccount *account)
    {
        if (!error)
        {
            abcAccount = account;
            callback([self makeErrorOrResponseFromNSError:error obj:account.name]);
        }
        else
        {
            if (error && error.code == ABCConditionCodeInvalidOTP)
            {
                callback([self makeError:ABCConditionCodeInvalidOTP
                                 message:@"Invalid OTP"
                              dictionary:@{@"otpResetDate" : [NSNumber numberWithInt:(int)[error.otpResetDate timeIntervalSince1970]],
                                           @"otpResetToken" : error.otpResetToken}]);
            }
            else
            {
                callback([self makeErrorFromNSError:error]);
            }
            
        }
    }];
}

RCT_EXPORT_METHOD(loginWithPIN:(NSString *)username
                  pin:(NSString *)pin
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }
    if (abcAccount)
    {
        [abcAccount logout];
        abcAccount = nil;
    }
    
    [abc pinLogin:username pin:pin delegate:self complete:^(ABCAccount *account) {
        abcAccount = account;
        callback(@[[NSNull null], account.name]);
    } error:^(NSError *nserror) {
        callback([self makeErrorFromNSError:nserror]);
    }];
}

RCT_EXPORT_METHOD(accountHasPassword:(NSString *)accountName
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }
    
    NSError *nserror;
    BOOL hasPassword = [abc accountHasPassword:accountName error:&nserror];
    
    callback([self makeErrorOrResponseFromNSError:nserror obj:[NSNumber numberWithBool:hasPassword] ]);
}

RCT_EXPORT_METHOD(deleteLocalAccount:(NSString *)username
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }
    
    NSError *nserror = [abc deleteLocalAccount:username];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(listUsernames:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }

    ABCError *nserror;
    NSArray *usernames = [abc listUsernames:&nserror];

    callback([self makeErrorOrResponseFromNSError:nserror obj:usernames]);
}

RCT_EXPORT_METHOD(usernameAvailable:(NSString *)username
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }
    BOOL available = false;
    NSError *nserror = [abc isUsernameAvailable:username];
    if (!nserror) available = true;
    if (nserror && (nserror.code == ABCConditionCodeAccountAlreadyExists))
    {
        nserror = nil;
        available = false;
    }
        
    callback([self makeErrorOrResponseFromNSError:nserror obj:[NSNumber numberWithBool:available]]);
}

RCT_EXPORT_METHOD(pinLoginEnabled:(NSString *)username
                  callback:(RCTResponseSenderBlock)callback)
{
    if (!abc)
    {
        callback([self makeErrorABCNotInitialized]);
        return;
    }
    NSError *nserror;
    
    BOOL enabled = [abc pinLoginEnabled:username error:&nserror];
    callback([self makeErrorOrResponseFromNSError:nserror obj:[NSNumber numberWithBool:enabled]]);
}

// -------------------------------------------------------------------------------
#pragma mark - ABCAccount methods
// -------------------------------------------------------------------------------

RCT_EXPORT_METHOD(logout:(RCTResponseSenderBlock)callback)
{
    if (abc)
    {
        if (abcAccount)
        {
            [abcAccount logout];
        }
    }
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(changePassword:(NSString *)password
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    [abcAccount changePassword:password callback:^(ABCError *error) {
        callback([self makeErrorFromNSError:error]);
    }];
}

RCT_EXPORT_METHOD(changePIN:(NSString *)pin
                  complete:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    [abcAccount changePIN:pin callback:^(ABCError *error) {
        callback([self makeErrorFromNSError:error]);
    }];
}

RCT_EXPORT_METHOD(checkPassword:(NSString *)password
                  complete:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    BOOL pass = [abcAccount checkPassword:password];
    callback(@[[NSNull null], [NSNumber numberWithBool:pass]]);
}

RCT_EXPORT_METHOD(enablePINLogin:(BOOL)enable
                  complete:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount enablePINLogin:enable];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(setOTPKey:(NSString *)key
                  complete:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount setOTPKey:key];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(getOTPLocalKey:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror;
    NSString *otpkey = [abcAccount getOTPLocalKey:&nserror];
    if (nserror)
        callback([self makeErrorFromNSError:nserror]);
    else
        callback(@[[NSNull null], otpkey]);
}

RCT_EXPORT_METHOD(getOTPDetails:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    bool enabled;
    long timeout;
    
    NSError *nserror = [abcAccount getOTPDetails:&enabled
                                         timeout:&timeout];
    if (nserror)
        callback([self makeErrorFromNSError:nserror]);
    else
        callback([self makeArrayResponse:[NSNumber numberWithBool:enabled]
                                    obj2:[NSNumber numberWithLong:timeout]]);
}

RCT_EXPORT_METHOD(enableOTP:(NSInteger)timeout
                  complete:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount enableOTP:timeout];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(disableOTP:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount disableOTP];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(cancelOTPResetRequest:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount cancelOTPResetRequest];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(signBitIDRequest:(NSString *)uri
                  message:(NSString *)message
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    ABCBitIDSignature *bitidSig = [abcAccount bitidSign:uri message:message];
    if (bitidSig)
        callback([self makeArrayResponse:bitidSig.address obj2:bitidSig.signature]);
    else
        callback([self makeError:ABCConditionCodeError message:@"Error signing bitid" dictionary:nil]);
}


//RCT_EXPORT_METHOD(getWallets:(RCTResponseSenderBlock)callback
//                  error:(RCTResponseSenderBlock)error)
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSMutableArray *array = [[NSMutableArray alloc] init];
//        
//        for (ABCWallet *w in abcAccount.arrayWallets)
//        {
//
//            NSDictionary *dictWallet = [[NSDictionary alloc] initWithObjectsAndKeys:
//                                        @"name", w.name,
//                                        @"uuid", w.uuid,
//                                        @"balance", [NSNumber numberWithLongLong:w.balance],
//                                        @"blockHeight", [NSNumber numberWithInt:w.blockHeight],
//                                        nil];
//            
//            [array addObject:dictWallet];
//        }
//        
//        callback([self makeResponseFromObj:array]);
//    });
//}

// -------------------------------------------------------------------------------
#pragma mark - ABCWallet methods
// -------------------------------------------------------------------------------


RCT_EXPORT_METHOD(getTransactions:(NSString *)uuid
                  complete:(RCTResponseSenderBlock)callback)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray *array = [[NSMutableArray alloc] init];
        
        for (ABCWallet *w in abcAccount.arrayWallets)
        {
            if ([uuid isEqualToString:w.uuid])
            {
                for (ABCTransaction *tx in w.arrayTransactions)
                {
                    NSDictionary *metaData = [[NSDictionary alloc] initWithObjectsAndKeys:
                                              @"payeeName", tx.metaData.payeeName,
                                              @"category", tx.metaData.category,
                                              @"notes", tx.metaData.notes,
                                              @"bizId", [NSNumber numberWithInteger:tx.metaData.bizId],
                                              @"amountFiat", [NSNumber numberWithDouble:tx.metaData.amountFiat],
                                              nil];
                    
                    NSDictionary *dictTx = [[NSDictionary alloc]
                                            initWithObjectsAndKeys:
                                            @"txid", tx.txid,
                                            @"amountSatoshi", [NSNumber numberWithLongLong:tx.amountSatoshi],
                                            @"date", [NSNumber numberWithLong:floor([tx.date timeIntervalSince1970] * 1000)],
                                            @"balance", [NSNumber numberWithLongLong:tx.balance],
                                            @"height", [NSNumber numberWithUnsignedLongLong:tx.height],
                                            @"isReplaceByFee", [NSNumber numberWithBool:tx.isReplaceByFee],
                                            @"isDoubleSpend", [NSNumber numberWithBool:tx.isDoubleSpend],
                                            @"metaData", metaData,
                                            nil];
                    
                    [array addObject:dictTx];
                }
                break;
            }
        }
        
        callback([self makeResponseFromObj:array]);
    });
}

// -------------------------------------------------------------------------------
#pragma mark - ABCDataStore methods
// -------------------------------------------------------------------------------
RCT_EXPORT_METHOD(writeData:(NSString *)folder
                  key:(NSString *)key
                  value:(NSString *)value
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount.dataStore dataWrite:folder withKey:key withValue:value];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(readData:(NSString *)folder
                  key:(NSString *)key
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    NSMutableString *data = [[NSMutableString alloc] init];
    NSError *nserror = [abcAccount.dataStore dataRead:folder withKey:key data:data];
    if (nserror)
        callback([self makeErrorFromNSError:nserror]);
    else
        callback([self makeResponseFromObj:data]);
}

RCT_EXPORT_METHOD(removeDataKey:(NSString *)folder
                  key:(NSString *)key
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount.dataStore dataRemoveKey:folder withKey:key];
    callback([self makeErrorFromNSError:nserror]);
}

RCT_EXPORT_METHOD(listDataKeys:(NSString *)folder
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    NSMutableArray *keys = [[NSMutableArray alloc] init];
    NSError *nserror = [abcAccount.dataStore dataListKeys:folder keys:keys];
    if (nserror)
        callback([self makeErrorFromNSError:nserror]);
    else
        callback([self makeResponseFromObj:keys]);
}

RCT_EXPORT_METHOD(removeDataFolder:(NSString *)folder
                  callback:(RCTResponseSenderBlock)callback)
{
    ABC_CHECK_ACCOUNT();
    
    NSError *nserror = [abcAccount.dataStore dataRemoveFolder:folder];
    callback([self makeErrorFromNSError:nserror]);
}

#pragma mark ABCAccountDelegate callbacks

@synthesize bridge = _bridge;

- (void) abcAccountWalletLoaded:(ABCWallet *)wallet;
{
//
//    
//    ABCLog(0, @"abcAccountWalletLoaded");
//    
//    [self.bridge.eventDispatcher sendAppEventWithName:@"abcAccountWalletLoaded"
//                                                 body:@{@"uuid": wallet.uuid}];
//    
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
//}
//
//- (void) abcAccountAccountChanged;
//{
//    if (abcAccount)
//    {
//        ABCLog(0, @"abcAccountAccountChanged");
//        
//        [self.bridge.eventDispatcher sendAppEventWithName:@"abcAccountAccountChanged"
//                                                     body:@{@"name": abcAccount.name}];
//
//    }
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

#pragma mark - Return Parameter utility methods

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
    return [self makeErrorOrResponseFromNSError:error obj:nil];
}

- (NSArray *) makeErrorOrResponseFromNSError:(NSError *)error obj:(id)obj;
{
    if (!error)
    {
        if (obj)
            return @[[NSNull null], obj];
        else
            return @[[NSNull null]];
    }

    return [self makeError:(ABCConditionCode)error.code
                   message:error.userInfo[NSLocalizedDescriptionKey]
                dictionary:@{@"message2": error.userInfo[NSLocalizedFailureReasonErrorKey],
                             @"message3": error.userInfo[NSLocalizedRecoverySuggestionErrorKey]}];
}

- (NSArray *)makeError:(ABCConditionCode)code
               message:(NSString *)message
{ return [self makeError:code message:message dictionary:nil];}

- (NSArray *)makeError:(ABCConditionCode)code
               message:(NSString *)message
            dictionary:(NSDictionary *)addDict;
{
    return @[[self makeErrorJson:code message:message dictionary:addDict]];
}

- (NSString *)makeErrorJson:(ABCConditionCode)code
                   message:(NSString *)message
                dictionary:(NSDictionary *)addDict
{
    if (ABCConditionCodeOk == code)
    {
        return nil;
    }
    else
    {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:(int) code] forKey:@"code"];
        if (message && [message length])
            [dict setObject:message forKey:@"message"];
        
        if (addDict)
            [dict addEntriesFromDictionary:addDict];
        
        NSString *json = [self makeJsonFromObj:dict];
        return json;
    }
}

- (NSArray *)makeArrayResponse:(id)obj1 obj2:(id)obj2;
{ return [self makeArrayResponse:obj1 obj2:obj2 obj3:nil obj4:nil]; }

- (NSArray *)makeArrayResponse:(id)obj1 obj2:(id)obj2 obj3:(id)obj3;
{ return [self makeArrayResponse:obj1 obj2:obj2 obj3:obj3 obj4:nil]; }

- (NSArray *)makeArrayResponse:(id)obj1 obj2:(id)obj2 obj3:(id)obj3 obj4:(id)obj4;
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:[NSNull null]];
    if (obj1)
        [array addObject:obj1];
    if (obj2)
        [array addObject:obj2];
    if (obj3)
        [array addObject:obj3];
    if (obj4)
        [array addObject:obj4];
    return [array copy];
}

- (NSArray *)makeResponseFromObj:(id)obj1;
{
    return @[[NSNull null], obj1];
}


- (NSArray *)makeErrorABCNotInitialized;
{
    return [self makeError:ABCConditionCodeNotInitialized message:@"ABC Not Initialized"];
}

- (NSArray *)makeErrorNotLoggedIn;
{
    return [self makeError:ABCConditionCodeError message:@"Not logged in"];
}

//- (NSDictionary *)constantsToExport
//{
//    return @{
//             @"ABCConditionCodeOk"                          : @(ABCConditionCodeOk                  ),
//             @"ABCConditionCodeError"                       : @(ABCConditionCodeError               ),
//             @"ABCConditionCodeNULLPtr"                     : @(ABCConditionCodeNULLPtr             ),
//             @"ABCConditionCodeNoAvailAccountSpace"         : @(ABCConditionCodeNoAvailAccountSpace ),
//             @"ABCConditionCodeDirReadError"                : @(ABCConditionCodeDirReadError        ),
//             @"ABCConditionCodeFileOpenError"               : @(ABCConditionCodeFileOpenError       ),
//             @"ABCConditionCodeFileReadError"               : @(ABCConditionCodeFileReadError       ),
//             @"ABCConditionCodeFileWriteError"              : @(ABCConditionCodeFileWriteError      ),
//             @"ABCConditionCodeFileDoesNotExist"            : @(ABCConditionCodeFileDoesNotExist    ),
//             @"ABCConditionCodeUnknownCryptoType"           : @(ABCConditionCodeUnknownCryptoType   ),
//             @"ABCConditionCodeInvalidCryptoType"           : @(ABCConditionCodeInvalidCryptoType   ),
//             @"ABCConditionCodeDecryptError"                : @(ABCConditionCodeDecryptError        ),
//             @"ABCConditionCodeDecryptFailure"              : @(ABCConditionCodeDecryptFailure      ),
//             @"ABCConditionCodeEncryptError"                : @(ABCConditionCodeEncryptError        ),
//             @"ABCConditionCodeScryptError"                 : @(ABCConditionCodeScryptError         ),
//             @"ABCConditionCodeAccountAlreadyExists"        : @(ABCConditionCodeAccountAlreadyExists),
//             @"ABCConditionCodeAccountDoesNotExist"         : @(ABCConditionCodeAccountDoesNotExist ),
//             @"ABCConditionCodeJSONError"                   : @(ABCConditionCodeJSONError           ),
//             @"ABCConditionCodeBadPassword"                 : @(ABCConditionCodeBadPassword         ),
//             @"ABCConditionCodeWalletAlreadyExists"         : @(ABCConditionCodeWalletAlreadyExists ),
//             @"ABCConditionCodeURLError"                    : @(ABCConditionCodeURLError            ),
//             @"ABCConditionCodeSysError"                    : @(ABCConditionCodeSysError            ),
//             @"ABCConditionCodeNotInitialized"              : @(ABCConditionCodeNotInitialized      ),
//             @"ABCConditionCodeReinitialization"            : @(ABCConditionCodeReinitialization    ),
//             @"ABCConditionCodeServerError"                 : @(ABCConditionCodeServerError         ),
//             @"ABCConditionCodeNoRecoveryQuestions"         : @(ABCConditionCodeNoRecoveryQuestions ),
//             @"ABCConditionCodeNotSupported"                : @(ABCConditionCodeNotSupported        ),
//             @"ABCConditionCodeMutexError"                  : @(ABCConditionCodeMutexError          ),
//             @"ABCConditionCodeNoTransaction"               : @(ABCConditionCodeNoTransaction       ),
//             @"ABCConditionCodeEmpty_Wallet"                : @(ABCConditionCodeEmpty_Wallet        ),
//             @"ABCConditionCodeParseError"                  : @(ABCConditionCodeParseError          ),
//             @"ABCConditionCodeInvalidWalletID"             : @(ABCConditionCodeInvalidWalletID     ),
//             @"ABCConditionCodeNoRequest"                   : @(ABCConditionCodeNoRequest           ),
//             @"ABCConditionCodeInsufficientFunds"           : @(ABCConditionCodeInsufficientFunds   ),
//             @"ABCConditionCodeSynchronizing"               : @(ABCConditionCodeSynchronizing       ),
//             @"ABCConditionCodeNonNumericPin"               : @(ABCConditionCodeNonNumericPin       ),
//             @"ABCConditionCodeNoAvailableAddress"          : @(ABCConditionCodeNoAvailableAddress  ),
//             @"ABCConditionCodeInvalidPinWait"              : @(ABCConditionCodeInvalidPinWait      ),
//             @"ABCConditionCodePinExpired"                  : @(ABCConditionCodePinExpired          ),
//             @"ABCConditionCodeInvalidOTP"                  : @(ABCConditionCodeInvalidOTP          ),
//             @"ABCConditionCodeSpendDust"                   : @(ABCConditionCodeSpendDust           ),
//             @"ABCConditionCodeObsolete"                    : @(ABCConditionCodeObsolete            )
//             };
//};
//
@end

#pragma mark - ABCConditionCode
//
//
//@implementation RCTConvert (ConditionCode)
//RCT_ENUM_CONVERTER(ABCConditionCode, (@{
//    @"ABCConditionCodeOk"                          : @(ABCConditionCodeOk                  ),
//            @"ABCConditionCodeError"                       : @(ABCConditionCodeError               ),
//            @"ABCConditionCodeNULLPtr"                     : @(ABCConditionCodeNULLPtr             ),
//            @"ABCConditionCodeNoAvailAccountSpace"         : @(ABCConditionCodeNoAvailAccountSpace ),
//            @"ABCConditionCodeDirReadError"                : @(ABCConditionCodeDirReadError        ),
//            @"ABCConditionCodeFileOpenError"               : @(ABCConditionCodeFileOpenError       ),
//            @"ABCConditionCodeFileReadError"               : @(ABCConditionCodeFileReadError       ),
//            @"ABCConditionCodeFileWriteError"              : @(ABCConditionCodeFileWriteError      ),
//            @"ABCConditionCodeFileDoesNotExist"            : @(ABCConditionCodeFileDoesNotExist    ),
//            @"ABCConditionCodeUnknownCryptoType"           : @(ABCConditionCodeUnknownCryptoType   ),
//            @"ABCConditionCodeInvalidCryptoType"           : @(ABCConditionCodeInvalidCryptoType   ),
//            @"ABCConditionCodeDecryptError"                : @(ABCConditionCodeDecryptError        ),
//            @"ABCConditionCodeDecryptFailure"              : @(ABCConditionCodeDecryptFailure      ),
//            @"ABCConditionCodeEncryptError"                : @(ABCConditionCodeEncryptError        ),
//            @"ABCConditionCodeScryptError"                 : @(ABCConditionCodeScryptError         ),
//            @"ABCConditionCodeAccountAlreadyExists"        : @(ABCConditionCodeAccountAlreadyExists),
//            @"ABCConditionCodeAccountDoesNotExist"         : @(ABCConditionCodeAccountDoesNotExist ),
//            @"ABCConditionCodeJSONError"                   : @(ABCConditionCodeJSONError           ),
//            @"ABCConditionCodeBadPassword"                 : @(ABCConditionCodeBadPassword         ),
//            @"ABCConditionCodeWalletAlreadyExists"         : @(ABCConditionCodeWalletAlreadyExists ),
//            @"ABCConditionCodeURLError"                    : @(ABCConditionCodeURLError            ),
//            @"ABCConditionCodeSysError"                    : @(ABCConditionCodeSysError            ),
//            @"ABCConditionCodeNotInitialized"              : @(ABCConditionCodeNotInitialized      ),
//            @"ABCConditionCodeReinitialization"            : @(ABCConditionCodeReinitialization    ),
//            @"ABCConditionCodeServerError"                 : @(ABCConditionCodeServerError         ),
//            @"ABCConditionCodeNoRecoveryQuestions"         : @(ABCConditionCodeNoRecoveryQuestions ),
//            @"ABCConditionCodeNotSupported"                : @(ABCConditionCodeNotSupported        ),
//            @"ABCConditionCodeMutexError"                  : @(ABCConditionCodeMutexError          ),
//            @"ABCConditionCodeNoTransaction"               : @(ABCConditionCodeNoTransaction       ),
//            @"ABCConditionCodeEmpty_Wallet"                : @(ABCConditionCodeEmpty_Wallet        ),
//            @"ABCConditionCodeParseError"                  : @(ABCConditionCodeParseError          ),
//            @"ABCConditionCodeInvalidWalletID"             : @(ABCConditionCodeInvalidWalletID     ),
//            @"ABCConditionCodeNoRequest"                   : @(ABCConditionCodeNoRequest           ),
//            @"ABCConditionCodeInsufficientFunds"           : @(ABCConditionCodeInsufficientFunds   ),
//            @"ABCConditionCodeSynchronizing"               : @(ABCConditionCodeSynchronizing       ),
//            @"ABCConditionCodeNonNumericPin"               : @(ABCConditionCodeNonNumericPin       ),
//            @"ABCConditionCodeNoAvailableAddress"          : @(ABCConditionCodeNoAvailableAddress  ),
//            @"ABCConditionCodeInvalidPinWait"              : @(ABCConditionCodeInvalidPinWait      ),
//            @"ABCConditionCodePinExpired"                  : @(ABCConditionCodePinExpired          ),
//            @"ABCConditionCodeInvalidOTP"                  : @(ABCConditionCodeInvalidOTP          ),
//            @"ABCConditionCodeSpendDust"                   : @(ABCConditionCodeSpendDust           ),
//            @"ABCConditionCodeObsolete"                    : @(ABCConditionCodeObsolete            ),
//}), ABCConditionCodeOk, integerValue)
//



