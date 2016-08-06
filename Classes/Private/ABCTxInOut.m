//
//  ABCTxInOut.m
//  AirBitz
//
//  Created by Timbo on 6/17/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "ABCTxInOut.h"
#import "ABCContext+Internal.h"

@interface ABCTxInOut ()
@end

@implementation ABCTxInOut

#pragma mark - NSObject overrides

- (id)init
{
    self = [super init];
    if (self) 
    {
        self.address = @"";
        self.isInput = false;
        self.amountSatoshi = 0;
    }
    return self;
}

- (void)dealloc 
{
}

@end
