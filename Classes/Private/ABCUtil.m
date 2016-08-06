//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//


#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <sys/sysctl.h>
#import "ABCUtil.h"
#import "ABCContext+Internal.h"



@implementation ABCUtil
{

}

+ (ABCParsedURI *)parseURI:(NSString *)uri error:(ABCError **)nserror;
{
    tABC_ParsedUri *parsedUri = NULL;
    char *szBitidDomain = NULL;
    char *szBitidCallbackURI = NULL;
    ABCParsedURI *abcParsedURI = nil;
    tABC_Error error;
    ABCError *lnserror = nil;
    
    if (!uri)
    {
        error.code = ABC_CC_NULLPtr;
        lnserror = [ABCError makeNSError:error];
    }
    else
    {
        ABC_ParseUri((char *)[uri UTF8String], &parsedUri, &error);
        lnserror = [ABCError makeNSError:error];
    }
    
    if (!lnserror && parsedUri)
    {
        abcParsedURI                        = [ABCParsedURI alloc];
        abcParsedURI.metadata               = [ABCMetaData alloc];
        abcParsedURI.amountSatoshi          = parsedUri->amountSatoshi;
        abcParsedURI.bitidKYCRequest        = parsedUri->bitidKYCRequest;
        abcParsedURI.bitidKYCProvider       = parsedUri->bitidKYCProvider;
        abcParsedURI.bitidPaymentAddress    = parsedUri->bitidPaymentAddress;
        
        if (parsedUri->szAddress)
            abcParsedURI.address            = [NSString stringWithUTF8String:parsedUri->szAddress];
        if (parsedUri->szWif)
            abcParsedURI.privateKey         = [NSString stringWithUTF8String:parsedUri->szWif];
        if (parsedUri->szBitidUri)
        {
            abcParsedURI.bitIDURI           = [NSString stringWithUTF8String:parsedUri->szBitidUri];
            ABC_BitidParseUri(nil, nil, [abcParsedURI.bitIDURI UTF8String], &szBitidDomain, &szBitidCallbackURI, &error);
            if (szBitidDomain)
                abcParsedURI.bitIDDomain    = [NSString stringWithUTF8String:szBitidDomain];
            if (szBitidCallbackURI)
                abcParsedURI.bitIDCallbackURI    = [NSString stringWithUTF8String:szBitidCallbackURI];
        }
        if (parsedUri->szLabel)
            abcParsedURI.metadata.payeeName = [NSString stringWithUTF8String:parsedUri->szLabel];
        if (parsedUri->szMessage)
            abcParsedURI.metadata.notes     = [NSString stringWithUTF8String:parsedUri->szMessage];
        if (parsedUri->szCategory)
            abcParsedURI.metadata.category  = [NSString stringWithUTF8String:parsedUri->szCategory];
        if (parsedUri->szRet)
            abcParsedURI.returnURI          = [NSString stringWithUTF8String:parsedUri->szRet];
        if (parsedUri->szPaymentProto)
            abcParsedURI.paymentRequestURL  = [NSString stringWithUTF8String:parsedUri->szPaymentProto];
        
        
    }
    
    if (nserror) *nserror = lnserror;
    
    if (parsedUri) free(parsedUri);
    if (szBitidDomain) free(szBitidDomain);
    
    return abcParsedURI;
}

+ (NSString *)encodeURI:(NSString *)address
                 amount:(uint64_t)amount
                  label:(NSString *)label
                message:(NSString *)message
               category:(NSString *)category
                    ret:(NSString *)ret;
{
    char *pszResult = NULL;
    tABC_Error error;
    
    ABC_AddressUriEncode([address UTF8String],
                         amount, [label UTF8String],
                         [message UTF8String], [category UTF8String], [ret UTF8String], &pszResult, &error);
    NSString *uri = [NSString stringWithUTF8String:pszResult];
    return uri;
}

+ (UIImage *)encodeStringToQRImage:(NSString *)string error:(ABCError **)nserror;
{
    unsigned char *pData = NULL;
    unsigned int width;
    tABC_Error error;
    UIImage *image = nil;
    ABCError *nserror2 = nil;
    
    ABC_QrEncode([string UTF8String], &pData, &width, &error);
    nserror2 = [ABCError makeNSError:error];
    if (!nserror2)
    {
        image = [ABCUtil dataToImage:pData withWidth:width andHeight:width];
    }
    
    if (pData) {
        free(pData);
    }
    if (nserror) *nserror = nserror2;
    return image;;
}

+ (NSString *)safeStringWithUTF8String:(const char *)bytes;
{
    if (bytes) {
        return [NSString stringWithUTF8String:bytes];
    } else {
        return @"";
    }
}

// replaces the string in the given variable with a duplicate of another
+ (void)replaceString:(char **)ppszValue withString:(const char *)szNewValue
{
    if (ppszValue)
    {
        if (*ppszValue)
        {
            free(*ppszValue);
        }
        *ppszValue = strdup(szNewValue);
    }
}


+ (void)freeStringArray:(char **)aszStrings count:(unsigned int)count
{
    if ((aszStrings != NULL) && (count > 0))
    {
        for (int i = 0; i < count; i++)
        {
            free(aszStrings[i]);
        }
        free(aszStrings);
    }
}

#if TARGET_OS_IPHONE

+ (UIImage *)dataToImage:(const unsigned char *)data withWidth:(int)width andHeight:(int)height
{
    //converts raw monochrome bitmap data (each byte is a 1 or a 0 representing a pixel) into a UIImage
    char *pixels = malloc(4 * width * width);
    char *buf = pixels;

    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            if (data[(y * width) + x] & 0x1)
            {
                //printf("%c", '*');
                *buf++ = 0;
                *buf++ = 0;
                *buf++ = 0;
                *buf++ = 255;
            }
            else
            {
                printf(" ");
                *buf++ = 255;
                *buf++ = 255;
                *buf++ = 255;
                *buf++ = 255;
            }
        }
        //printf("\n");
    }

    CGContextRef ctx;
    CGImageRef imageRef;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    ctx = CGBitmapContextCreate(pixels,
            (float)width,
            (float)height,
            8,
            width * 4,
            colorSpace,
            (CGBitmapInfo)kCGImageAlphaPremultipliedLast ); //documentation says this is OK
    CGColorSpaceRelease(colorSpace);
    imageRef = CGBitmapContextCreateImage (ctx);
    UIImage* rawImage = [UIImage imageWithCGImage:imageRef];

    CGContextRelease(ctx);
    CGImageRelease(imageRef);
    free(pixels);
    return rawImage;
}

#else // OSX Version

+ (NSImage *)dataToImage:(const unsigned char *)data withWidth:(int)width andHeight:(int)height
{
    //converts raw monochrome bitmap data (each byte is a 1 or a 0 representing a pixel) into a UIImage
    char *pixels = malloc(4 * width * width);
    char *buf = pixels;
    
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            if (data[(y * width) + x] & 0x1)
            {
                //printf("%c", '*');
                *buf++ = 0;
                *buf++ = 0;
                *buf++ = 0;
                *buf++ = 255;
            }
            else
            {
                printf(" ");
                *buf++ = 255;
                *buf++ = 255;
                *buf++ = 255;
                *buf++ = 255;
            }
        }
        //printf("\n");
    }
    
    CGContextRef ctx;
    CGImageRef imageRef;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    ctx = CGBitmapContextCreate(pixels,
                                (float)width,
                                (float)height,
                                8,
                                width * 4,
                                colorSpace,
                                (CGBitmapInfo)kCGImageAlphaPremultipliedLast ); //documentation says this is OK
    CGColorSpaceRelease(colorSpace);
    imageRef = CGBitmapContextCreateImage (ctx);
    CGSize size;
    size.width = width;
    size.height = height;
    NSImage* rawImage = [[NSImage alloc] initWithCGImage:imageRef size:size];
    
    CGContextRelease(ctx);
    CGImageRelease(imageRef);
    free(pixels);
    return rawImage;
}
#endif

+ (NSString *)platform;
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    
    free(machine);
    
    return platform;
}

+ (NSString *)platformString;
{
    NSString *platform = [self platform];
    
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone5,3"])    return @"iPhone 5c (GSM)";
    if ([platform isEqualToString:@"iPhone5,4"])    return @"iPhone 5c (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone6,1"])    return @"iPhone 5s (GSM)";
    if ([platform isEqualToString:@"iPhone6,2"])    return @"iPhone 5s (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    if ([platform isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone8,1"])    return @"iPhone 6s Plus";
    if ([platform isEqualToString:@"iPhone8,2"])    return @"iPhone 6s";
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([platform isEqualToString:@"iPod7,1"])      return @"iPod Touch 6G";
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini (WiFi)";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini (GSM)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini (CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3 (WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3 (CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3 (GSM)";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad 4 (GSM)";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad 4 (CDMA)";
    if ([platform isEqualToString:@"iPad4,1"])      return @"iPad Air (WiFi)";
    if ([platform isEqualToString:@"iPad4,2"])      return @"iPad Air (GSM)";
    if ([platform isEqualToString:@"iPad4,3"])      return @"iPad Air (CDMA)";
    if ([platform isEqualToString:@"iPad4,4"])      return @"iPad Mini Retina (WiFi)";
    if ([platform isEqualToString:@"iPad4,5"])      return @"iPad Mini Retina (Cellular)";
    if ([platform isEqualToString:@"iPad4,7"])      return @"iPad Mini 3 (WiFi)";
    if ([platform isEqualToString:@"iPad4,8"])      return @"iPad Mini 3 (Cellular)";
    if ([platform isEqualToString:@"iPad4,9"])      return @"iPad Mini 3 (Cellular)";
    if ([platform isEqualToString:@"iPad5,1"])      return @"iPad Mini 4 (WiFi)";
    if ([platform isEqualToString:@"iPad5,2"])      return @"iPad Mini 4 (Cellular)";
    if ([platform isEqualToString:@"iPad5,3"])      return @"iPad Air 2 (WiFi)";
    if ([platform isEqualToString:@"iPad5,4"])      return @"iPad Air 2 (Cellular)";
    if ([platform isEqualToString:@"iPad6,7"])      return @"iPad Pro (WiFi)";
    if ([platform isEqualToString:@"iPad6,8"])      return @"iPad Pro (Cellular)";
    if ([platform isEqualToString:@"i386"])         return @"Simulator x86 32 bit";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator x86 64 bit";
    
    return platform;
}



@end