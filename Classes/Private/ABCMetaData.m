//
//  ABCKeychain.m
//  Airbitz
//
//  Created by Paul Puey on 2016-03-01.
//  Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCMetaData+Internal.h"
#import "AirbitzCore.h"

@interface ABCMetaData ()

/// Delegate object to handle delegate callbacks
@property (assign)            id<ABCMetaDataDelegate>       delegate;

@end

@implementation ABCMetaData
{
    
}

- (void)setPayeeName:(NSString *)payeeName
{
    _payeeName = payeeName;
    [self sendDataChanged];
}

- (void)setCategory:(NSString *)category
{
    _category = category;
    [self sendDataChanged];
}

- (void)setAmountFiat:(double)amountFiat
{
    _amountFiat = amountFiat;
    [self sendDataChanged];
}

- (void)setNotes:(NSString *)notes
{
    _notes = notes;
    [self sendDataChanged];
}

- (void)setBizId:(unsigned int)bizId
{
    _bizId = bizId;
    [self sendDataChanged];
}

- (void)sendDataChanged
{
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(abcMetaDataChanged)]) {
            [self.delegate abcMetaDataChanged];
        }
    }
}

@end