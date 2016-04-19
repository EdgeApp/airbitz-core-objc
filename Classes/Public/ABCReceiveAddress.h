//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
#import "AirbitzCore.h"

@class AirbitzCore;
@class ABCAccount;
@class ABCMetaData;
@class ABCWallet;

/**
 * ABCReceiveAddress is returned by ABCWallet routine createNewReceiveAddress and
 * getReceiveAddress. The properties amountSatoshi and metaData can be modified by
 * the caller.<br>
 * <br>
 * Subsequent reads of the properties uri, address, and qrCode will
 * automatically encompass the changes written to amountSatoshi and metaData. The
 * values written to metaData will be written to the ABCTransaction for funds received
 * on this address.
 */
@interface ABCReceiveAddress : NSObject

///--------------------------------------------------------------------
/// @name The following properties are passed into ABCReceiveAddress as details for the request
///--------------------------------------------------------------------

/// Amount of satoshis to request. Optional. Set to zero if not needed
@property (nonatomic)               int64_t                 amountSatoshi;

/// Optional meta to add to this request. Once money is received into this request
/// address, the transaction will be tagged with this metadata such as payeeName
/// category, and notes
@property (nonatomic, strong)       ABCMetaData             *metaData;

/// ------------------------------------------------------
/// @name The following properties are returned by ABC
/// ------------------------------------------------------

/// Full request URI ie. "bitcoin:12kjhg9834gkjh4tjr1jhgSADG4GASf?amount=.2123&label=Airbitz&notes=Hello"
@property (nonatomic, copy)         NSString                *uri;

/// Bitcoin public address for request
@property (nonatomic, copy)         NSString                *address;

#if TARGET_OS_IPHONE

/// QRCode of request in UIImage format (iOS Only)
@property (nonatomic, copy)         UIImage                 *qrCode;
#else

/// QRCode of request in NSImage format (OSX Only)
@property (nonatomic, copy)         NSImage                 *qrCode;
#endif


/// ------------------------------------------------------
/// @name Instance Methods
/// ------------------------------------------------------

/**
 * Finalizes the request so the address cannot be used by future requests. Forces address
 * rotation so the next request gets a different address
 * @return NSError
 */
- (NSError *)finalizeRequest;

/**
 * Modify a request based on the values in the ABCReceiveAddress structure. Normally the
 * request would require that one of the parameters address, qrCode, or uri are readback
 * before the metaData is saved with the address in ABC.
 * @return NSError
 */
- (NSError *)modifyRequestWithDetails;


/**
 * Tell ABC to constantly query this address to help ensure timely detection of
 * funds on this address. Great to use when there is a QR code showing on screen.
 * @param enable BOOL Set to YES to prioritize this address. Set to NO to disable
 * priority
 */
- (void)prioritizeAddress:(BOOL)enable;


@end

