//
//  ABCError.m
//  Airbitz
//

#import <Foundation/Foundation.h>
#import "AirbitzCore+Internal.h"

@interface ABCError ()

@end

@implementation ABCError

+ (NSError *)makeNSError:(tABC_Error)error;
{
    if (ABCConditionCodeOk == error.code)
    {
        return nil;
    }
    else
    {
        NSString *failureReason = [NSString stringWithUTF8String:error.szDescription];
        NSString *failureDetail = [NSString stringWithFormat:@"%@: %@:%d",
                                   [NSString stringWithUTF8String:error.szSourceFunc],
                                   [NSString stringWithUTF8String:error.szSourceFile],
                                   error.nSourceLine];
        return [NSError errorWithDomain:ABCErrorDomain
                                   code:error.code
                               userInfo:@{ NSLocalizedDescriptionKey:[ABCError errorMap:error] ,
                                           NSLocalizedFailureReasonErrorKey:failureReason,
                                           NSLocalizedRecoverySuggestionErrorKey:failureDetail }];
    }
}

+ (NSError *)makeNSError:(tABC_Error)error description:(NSString *)description;
{
    if (ABCConditionCodeOk == error.code)
    {
        return nil;
    }
    else
    {
        NSString *failureReason = [NSString stringWithUTF8String:error.szDescription];
        NSString *failureDetail = [NSString stringWithFormat:@"%@: %@:%d",
                                   [NSString stringWithUTF8String:error.szSourceFunc],
                                   [NSString stringWithUTF8String:error.szSourceFile],
                                   error.nSourceLine];
        return [NSError errorWithDomain:ABCErrorDomain
                                   code:error.code
                               userInfo:@{ NSLocalizedDescriptionKey:description,
                                           NSLocalizedFailureReasonErrorKey:failureReason,
                                           NSLocalizedRecoverySuggestionErrorKey:failureDetail }];
    }
}



+ (NSString *)errorMap:(tABC_Error)error;
{
    if (ABCConditionCodeInvalidPinWait == error.code)
    {
        NSString *description = [NSString stringWithUTF8String:error.szDescription];
        if ([@"0" isEqualToString:description]) {
            return NSLocalizedString(@"Invalid PIN.", nil);
        } else {
            return [NSString stringWithFormat:
                    NSLocalizedString(@"Too many failed login attempts. Please try again in %@ seconds.", nil),
                    description];
        }
    }
    else
    {
        return [ABCError conditionCodeMap:(ABCConditionCode) error.code];
    }

}

+ (NSString *)conditionCodeMap:(ABCConditionCode) cc;
{
    switch (cc)
    {
        case ABCConditionCodeAccountAlreadyExists:
            return NSLocalizedString(@"This account already exists.", nil);
        case ABCConditionCodeAccountDoesNotExist:
            return NSLocalizedString(@"We were unable to find your account. Be sure your username is correct.", nil);
        case ABCConditionCodeBadPassword:
            return NSLocalizedString(@"Invalid user name or password", nil);
        case ABCConditionCodeWalletAlreadyExists:
            return NSLocalizedString(@"Wallet already exists.", nil);
        case ABCConditionCodeInvalidWalletID:
            return NSLocalizedString(@"Wallet does not exist.", nil);
        case ABCConditionCodeURLError:
        case ABCConditionCodeServerError:
            return NSLocalizedString(@"Unable to connect to Airbitz server. Please try again later.", nil);
        case ABCConditionCodeNoRecoveryQuestions:
            return NSLocalizedString(@"No recovery questions are available for this user", nil);
        case ABCConditionCodeNotSupported:
            return NSLocalizedString(@"This operation is not supported.", nil);
        case ABCConditionCodeInsufficientFunds:
            return NSLocalizedString(@"Insufficient funds", nil);
        case ABCConditionCodeSpendDust:
            return NSLocalizedString(@"Amount is too small", nil);
        case ABCConditionCodeSynchronizing:
            return NSLocalizedString(@"Synchronizing with the network.", nil);
        case ABCConditionCodeNonNumericPin:
            return NSLocalizedString(@"PIN must be a numeric value.", nil);
        case ABCConditionCodeNULLPtr:
            return NSLocalizedString(@"Invalid NULL Ptr passed to ABC", nil);
        case ABCConditionCodeNoAvailAccountSpace:
            return NSLocalizedString(@"No Available Account Space", nil);
        case ABCConditionCodeDirReadError:
            return NSLocalizedString(@"Directory Read Error", nil);
        case ABCConditionCodeFileOpenError:
            return NSLocalizedString(@"File Open Error", nil);
        case ABCConditionCodeFileReadError:
            return NSLocalizedString(@"File Read Error", nil);
        case ABCConditionCodeFileWriteError:
            return NSLocalizedString(@"File Write Error", nil);
        case ABCConditionCodeFileDoesNotExist:
            return NSLocalizedString(@"File Does Not Exist Error", nil);
        case ABCConditionCodeUnknownCryptoType:
        case ABCConditionCodeInvalidCryptoType:
        case ABCConditionCodeDecryptError:
        case ABCConditionCodeDecryptFailure:
        case ABCConditionCodeEncryptError:
        case ABCConditionCodeScryptError:
            return NSLocalizedString(@"Encryption/Decryption Error", nil);
        case ABCConditionCodeMutexError:
            return NSLocalizedString(@"Mutex Error", nil);
        case ABCConditionCodeJSONError:
            return NSLocalizedString(@"JSON Error", nil);
        case ABCConditionCodeNoTransaction:
            return NSLocalizedString(@"No Transactions in Wallet", nil);
        case ABCConditionCodeSysError:
        case ABCConditionCodeNotInitialized:
        case ABCConditionCodeReinitialization:
        case ABCConditionCodeParseError:
        case ABCConditionCodeNoRequest:
        case ABCConditionCodeNoAvailableAddress:
        case ABCConditionCodeError:
        default:
            return NSLocalizedString(@"An error has occurred.", nil);
    }
}


@end