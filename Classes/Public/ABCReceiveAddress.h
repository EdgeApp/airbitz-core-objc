//
// Created by Paul P on 1/30/16.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AirbitzCore.h"

@class AirbitzCore;
@class ABCAccount;
@class ABCMetaData;
@class ABCWallet;

/// Object used to pass in address request details
/// Optional fields payeeName, category, notes, and bizId will cause
/// transactions details of incoming transaction to be automatically tagged
/// with the information from this object.

@interface ABCReceiveAddress : NSObject
/// @name The following properties are passed into ABCReceiveAddress as details for the request

/// Amount of satoshis to add to request. Optional
@property (nonatomic)               int64_t                 amountSatoshi;

/// Optional meta to add to this request. Once money is received into this request
/// address, the transaction will be tagged with this metadata
@property (nonatomic, strong)       ABCMetaData             *metaData;

/// ------------------------------------------------------
/// @name The following properties are returned by ABC
/// ------------------------------------------------------

/// Full request URI ie. "bitcoin:12kjhg9834gkjh4tjr1jhgSADG4GASf?amount=.2123&label=Airbitz&notes=Hello"
@property (nonatomic, copy)         NSString                *uri;

/// Bitcoin public address for request
@property (nonatomic, copy)         NSString                *address;

/// QRCode of request.
@property (nonatomic, copy)         UIImage                 *qrCode;



/// @name Instance Methods

/**
 * Finalizes the request so the address cannot be used by future requests. Forces address
 * rotation so the next request gets a different address
 * @return NSError*
 */
- (NSError *)finalizeRequest;

/**
 * Modify a request based on the values in the ABCReceiveAddress structure
 * @return NSError*
 */
- (NSError *)modifyRequestWithDetails;

- (id)init;
@end

