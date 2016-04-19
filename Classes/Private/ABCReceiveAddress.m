//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCReceiveAddress+Internal.h"
#import "AirbitzCore+Internal.h"

@interface ABCReceiveAddress () <ABCMetaDataDelegate>
{

}
@property (nonatomic, strong)   ABCWallet       *wallet;
@property                       BOOL            requestChanged;

@end

@implementation ABCReceiveAddress
- (id)initWithWallet:(ABCWallet *)wallet;
{
    self = [super init];
    self.metaData = [ABCMetaData alloc];
    self.metaData.delegate = self;
    self.wallet = wallet;

    return self;
}

- (NSError *)createAddress;
{
    tABC_Error error;
    NSError *lnserror = nil;

    char *pRequestID = nil;

    // create the request
    ABC_CreateReceiveRequest([self.wallet.account.name UTF8String],
            [self.wallet.account.password UTF8String],
            [self.wallet.uuid UTF8String],
            &pRequestID,
            &error);
    lnserror = [ABCError makeNSError:error];
    if (lnserror) goto exitnow;
    self.address = [NSString stringWithUTF8String:pRequestID];

    exitnow:

    if (pRequestID) free(pRequestID);

    return lnserror;

}

- (NSString *)address;
{
    if (_requestChanged)
        [self modifyReceiveAddress];
    return _address;
}

#if TARGET_OS_IPHONE
- (UIImage *)qrCode
#else
- (NSImage *)qrCode
#endif
{
    if (_requestChanged || !_qrCode)
        [self modifyReceiveAddress];
    return _qrCode;
}

- (NSString *)uri;
{
    if (_requestChanged || !_uri)
        [self modifyReceiveAddress];
    return _uri;
}

- (void)abcMetaDataChanged
{
    _requestChanged = YES;
}

- (void)setAmountSatoshi:(int64_t)amountSatoshi
{
    _amountSatoshi = amountSatoshi;
    _requestChanged = YES;
}

- (void)modifyReceiveAddress;
{
    tABC_Error error;
    tABC_TxDetails details;
    NSError *lnserror = nil;
    unsigned char *pData = NULL;
    char *pszURI = NULL;
    unsigned int width = 0;
    NSString *label = @"";

    //first need to create a transaction details struct
    memset(&details, 0, sizeof(tABC_TxDetails));

    details.amountSatoshi = _amountSatoshi;
    details.szName = (char *) [_metaData.payeeName UTF8String];
    details.szCategory = (char *) [_metaData.category UTF8String];
    details.szNotes = (char *) [_metaData.notes UTF8String];
    details.bizId = _metaData.bizId;

    //the true fee values will be set by the core
    details.amountFeesAirbitzSatoshi = 0;
    details.amountFeesMinersSatoshi = 0;
    details.amountCurrency = 0;

    ABC_ModifyReceiveRequest([self.wallet.account.name UTF8String],
            [_wallet.account.password UTF8String],
            [_wallet.uuid UTF8String],
            [_address UTF8String],
            &details,
            &error);
    lnserror = [ABCError makeNSError:error];
    if (lnserror) goto exitnow;

    if (self.wallet.account.settings.bNameOnPayments)
    {
        label = self.wallet.account.settings.fullName;
    }

    ABC_AddressUriEncode([_address UTF8String], _amountSatoshi, [label UTF8String], NULL, NULL, NULL, &pszURI, &error);
    lnserror = [ABCError makeNSError:error];
    if (lnserror) goto exitnow;
    
    ABC_QrEncode(pszURI, &pData, &width, &error);
    lnserror = [ABCError makeNSError:error];
    if (lnserror) goto exitnow;

    _qrCode = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    _uri    = [NSString stringWithUTF8String:pszURI];

    exitnow:
    if (pData) free(pData);
    if (pszURI) free(pszURI);

    if (lnserror)
    {
        _qrCode = nil;
        _uri = nil;
    }
    
    _requestChanged = NO;

}


- (NSError *)finalizeRequest
{
    tABC_Error error;
    
    if (!self.wallet || !self.wallet.account || !self.address)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }
    // Finalize this request so it isn't used elsewhere
    ABC_FinalizeReceiveRequest([self.wallet.account.name UTF8String],
            [self.wallet.account.password UTF8String], [self.wallet.uuid UTF8String],
            [self.address UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (void)prioritizeAddress:(BOOL)enable;
{
    NSString *address = nil;

    if (enable)
        address = self.address;

    [self.wallet.account postToWatcherQueue:^{
        tABC_Error error;
        ABC_PrioritizeAddress([self.wallet.account.name UTF8String],
                [self.wallet.account.password UTF8String],
                [self.wallet.uuid UTF8String],
                [address UTF8String],
                &error);
    }];
}

- (NSError *)modifyRequestWithDetails;
{
    tABC_Error error;
    tABC_TxDetails details;
    unsigned char *pData = NULL;
    char *szRequestAddress = NULL;
    char *pszURI = NULL;
    NSError *nserror = nil;
    NSString *label = @"";
    
    //first need to create a transaction details struct
    memset(&details, 0, sizeof(tABC_TxDetails));
    
    details.amountSatoshi =          self.amountSatoshi;
    details.szName = (char *)       [self.metaData.payeeName UTF8String];
    details.szCategory = (char *)   [self.metaData.category UTF8String];
    details.szNotes = (char *)      [self.metaData.notes UTF8String];
    details.bizId = (unsigned int) self.metaData.bizId;
    
    //the true fee values will be set by the core
    details.amountFeesAirbitzSatoshi = 0;
    details.amountFeesMinersSatoshi = 0;
    details.amountCurrency = 0;
    
    char *pRequestID = (char *)[self.address UTF8String];

    ABC_ModifyReceiveRequest([self.wallet.account.name UTF8String],
                             [self.wallet.account.password UTF8String],
                             [self.wallet.uuid UTF8String],
                             pRequestID,
                             &details,
                             &error);
    nserror = [ABCError makeNSError:error];
    if (nserror) goto exitnow;
    
    unsigned int width = 0;
    if (self.wallet.account.settings.bNameOnPayments)
    {
        label = self.wallet.account.settings.fullName;
    }
    
    ABC_AddressUriEncode([_address UTF8String], _amountSatoshi, [label UTF8String], NULL, NULL, NULL, &pszURI, &error);
    nserror = [ABCError makeNSError:error];
    if (nserror) goto exitnow;
    
    ABC_QrEncode(pszURI, &pData, &width, &error);
    nserror = [ABCError makeNSError:error];
    if (nserror) goto exitnow;
    
    self.qrCode = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    self.uri    = [NSString stringWithUTF8String:pszURI];
    
exitnow:
    
    if (szRequestAddress) free(szRequestAddress);
    if (pData) free(pData);
    if (pszURI) free(pszURI);
    
    return nserror;
}


@end

