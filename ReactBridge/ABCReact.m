//
//  ABCReact.m
//  AirBitz
//

#import "RCTBridgeModule.h"
#import "ABCReact.h"

@interface AirbitzCoreRCT () <ABCAccountDelegate>
{
    AirbitzCore *abc;
}
@end

@implementation AirbitzCoreRCT
//
//- (NSString *)pointerToString:(id) pointer
//{
//    void *voidPtr = (__bridge void *) pointer;
//  
//    NSString *str = [NSString stringWithFormat:@"%llx", (unsigned long long)voidPtr];
//  
//    return str;
//}
//
//- (void *)stringToPointer:(NSString *)string
//{
//    unsigned long long result = 0;
//    NSScanner *scanner = [NSScanner scannerWithString:string];
//    
//    [scanner setScanLocation:0]; // bypass '#' character
//    [scanner scanHexLongLong:&result];
//    
//    void *voidPtr = (void *) result;
//    
//    return voidPtr;
//}
//

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(NSString *)abcAPIKey hbits:(NSString *)hbitsKey
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    if (!abc)
    {
        abc = [[AirbitzCore alloc] init:abcAPIKey hbits:hbitsKey];
        if (!abc)
        {
            [array addObject:@"Error initializing ABC"];
            error(array);
        }
    }
    else
    {
        [array addObject:@"Error"];
        error(array);
    }
    
    [array addObject:[NSNull null]];
    
    complete(array);
}

RCT_EXPORT_METHOD(createAccount:(NSString *)username
                  password:(NSString *)password
                  pin:(NSString *)pin
                  complete:(RCTResponseSenderBlock)complete
                  error:(RCTResponseSenderBlock)error)
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    if (!abc)
    {
        [array addObject:@"Error ABC Not initialized"];
        error(array);
    }
    
    [abc createAccount:username
              password:password
                   pin:pin
              delegate:self
              complete:^(ABCAccount *account)
     {
         [array addObject:[NSNull null]];
         complete(array);
     }
                 error:^(NSError *nserror)
     {
         [array addObject:nserror.userInfo[NSLocalizedDescriptionKey]];
         error(array);
     }];
}

@end
