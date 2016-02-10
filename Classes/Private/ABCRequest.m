//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCRequest.h"
#import "ABCError.h"
#import "ABCUtil.h"
#import "ABCUser+Internal.h"
#import "AirbitzCore+Internal.h"

@interface ABCRequest ()
{

}
@property (nonatomic, strong) ABCError          *abcError;
@property (nonatomic, strong) ABCUser           *user; // pointer to ABCUser object that created request

@end

@implementation ABCRequest
- (id)init;
{
    self = [super init];
    self.abcError = [[ABCError alloc] init];
    return self;
}

- (ABCConditionCode)finalizeRequest
{
    tABC_Error error;
    
    if (!self.wallet || !self.user || !self.address)
    {
        error.code = ABC_CC_NULLPtr;
        return [self.abcError setLastErrors:error];
    }
    // Finalize this request so it isn't used elsewhere
    ABC_FinalizeReceiveRequest([self.user.name UTF8String],
            [self.user.password UTF8String], [self.wallet.strUUID UTF8String],
            [self.address UTF8String], &error);
    return [self.abcError setLastErrors:error];
}

- (ABCConditionCode)modifyRequestWithDetails;
{
    tABC_Error error;
    tABC_TxDetails details;
    ABCConditionCode ccode;
    unsigned char *pData = NULL;
    char *szRequestAddress = NULL;
    char *pszURI = NULL;
    
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

    ABC_ModifyReceiveRequest([self.wallet.user.name UTF8String],
                             [self.wallet.user.password UTF8String],
                             [self.wallet.strUUID UTF8String],
                             pRequestID,
                             &details,
                             &error);
    ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk != ccode)
        goto exitnow;
    
    unsigned int width = 0;
    ABC_GenerateRequestQRCode([self.wallet.user.name UTF8String],
                              [self.wallet.user.password UTF8String],
                              [self.wallet.strUUID UTF8String],
                              pRequestID,
                              &pszURI,
                              &pData,
                              &width,
                              &error);
    ccode = [self.abcError setLastErrors:error];
    if (ABCConditionCodeOk != ccode)
        goto exitnow;
    self.qrCode = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    self.uri    = [NSString stringWithUTF8String:pszURI];
    
exitnow:
    
    if (szRequestAddress) free(szRequestAddress);
    if (pData) free(pData);
    if (pszURI) free(pszURI);
    
    return ccode;
}


@end

