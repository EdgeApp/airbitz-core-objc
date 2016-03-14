//
//  ABCParsedURI.m
//  Airbitz
//

#import "AirbitzCore+Internal.h"

@interface ABCParsedURI ()
{
}

@end

@implementation ABCParsedURI

- (ABCPaymentRequest *) getPaymentRequest:(NSError **)nserror;
{
    ABCPaymentRequest *paymentRequest = nil;
    tABC_PaymentRequest *pPaymentRequest = NULL;
    NSError *lnserror = nil;
    tABC_Error error;
    
    if (self.paymentRequestURL)
    {
        ABC_FetchPaymentRequest((char *)[self.paymentRequestURL UTF8String], &pPaymentRequest, &error);
        lnserror = [ABCError makeNSError:error];
        
        if (!lnserror)
        {
            paymentRequest = [ABCPaymentRequest alloc];
            
            paymentRequest.pPaymentRequest      = pPaymentRequest;
            paymentRequest.amountSatoshi        = pPaymentRequest->amountSatoshi;
            if (pPaymentRequest->szDomain)
                paymentRequest.domain           = [NSString stringWithUTF8String:pPaymentRequest->szDomain];
            if (pPaymentRequest->szMemo)
                paymentRequest.memo             = [NSString stringWithUTF8String:pPaymentRequest->szMemo];
            if (pPaymentRequest->szMerchant)
                paymentRequest.merchant         = [NSString stringWithUTF8String:pPaymentRequest->szMerchant];
        }
    }
    
    if (nserror) *nserror = lnserror;
    
    return paymentRequest;
}

@end