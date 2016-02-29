//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCRequest+Internal.h"
#import "AirbitzCore+Internal.h"

@interface ABCRequest ()
{

}
@property (nonatomic, strong) ABCError          *abcError;
@property (nonatomic, strong) ABCAccount        *account; // pointer to ABCAccount object that created request
@property (nonatomic, strong) ABCWallet         *wallet;

@end

@implementation ABCRequest
- (id)init;
{
    self = [super init];
    self.abcError = [[ABCError alloc] init];
    return self;
}

- (NSError *)finalizeRequest
{
    tABC_Error error;
    
    if (!self.wallet || !self.account || !self.address)
    {
        error.code = ABC_CC_NULLPtr;
        return [ABCError makeNSError:error];
    }
    // Finalize this request so it isn't used elsewhere
    ABC_FinalizeReceiveRequest([self.account.name UTF8String],
            [self.account.password UTF8String], [self.wallet.uuid UTF8String],
            [self.address UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (NSError *)modifyRequestWithDetails;
{
    tABC_Error error;
    tABC_TxDetails details;
    unsigned char *pData = NULL;
    char *szRequestAddress = NULL;
    char *pszURI = NULL;
    NSError *nserror = nil;
    
    //first need to create a transaction details struct
    memset(&details, 0, sizeof(tABC_TxDetails));
    
    details.amountSatoshi =          self.amountSatoshi;
    details.szName = (char *)       [self.payeeName UTF8String];
    details.szCategory = (char *)   [self.category UTF8String];
    details.szNotes = (char *)      [self.notes UTF8String];
    details.bizId = self.bizId;
    details.attributes = 0x0; //for our own use (not used by the core)
    
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
    ABC_GenerateRequestQRCode([self.wallet.account.name UTF8String],
                              [self.wallet.account.password UTF8String],
                              [self.wallet.uuid UTF8String],
                              pRequestID,
                              &pszURI,
                              &pData,
                              &width,
                              &error);
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

