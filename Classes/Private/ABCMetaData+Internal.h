//
// ABCMetaData+Internal.h
//
// Created by Paul P on 2016/02/09.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCMetaData.h"
#import "ABCContext+Internal.h"

///----------------------------------------------------------
/// @name ABCAccount Delegate callbacks
///----------------------------------------------------------

@protocol ABCMetaDataDelegate <NSObject>

@optional

- (void) abcMetaDataChanged;

@end


@interface ABCMetaData (Internal)

/// Delegate object to handle delegate callbacks
@property (assign)            id<ABCMetaDataDelegate>       delegate;

@end
