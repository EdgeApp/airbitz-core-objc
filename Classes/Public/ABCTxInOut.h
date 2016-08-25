//
//  ABCTxInOut.h
//  AirBitz
//
//  Created by Timbo on 6/17/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "ABCContext.h"

@interface ABCTxInOut : NSObject

@property (nonatomic, strong)   NSString            *address;
@property (nonatomic)           SInt64              amountSatoshi;
@property (nonatomic)           BOOL                isInput;

@end
