//
// ABCSpend+Internal.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCSpend.h"
#import "AirbitzCore+Internal.h"

@interface ABCPaymentRequest (Internal)
@property                           tABC_PaymentRequest     *pPaymentRequest;
@end

@interface ABCSpend (Internal)

@property (nonatomic)               void                    *pSpend;

- (id)init:(id)abc;
- (void)spendObjectSet:(void *)o;

@end
