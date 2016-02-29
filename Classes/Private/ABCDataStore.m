//
// ABCDataStore.m
//
// Created by Paul Puey on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore+Internal.h"

@interface ABCDataStore ()
{
}

@property                           ABCAccount          *account;

@end

@implementation ABCDataStore

#pragma Data Methods

- (NSError *)dataGet:(NSString *)folder withKey:(NSString *)key data:(NSMutableString *)data;
{
    [data setString:@""];
    tABC_Error error;
    char *szData = NULL;
    ABC_PluginDataGet([self.account.name UTF8String],
                      [self.account.password UTF8String],
                      [folder UTF8String], [key UTF8String],
                      &szData, &error);
    NSError *nserror = [ABCError makeNSError:error];
    if (!nserror) {
        [data setString:[NSString stringWithUTF8String:szData]];
    }
    if (szData != NULL) {
        free(szData);
    }
    return nserror;
}

- (NSError *)dataSet:(NSString *)folder withKey:(NSString *)key withValue:(NSString *)value;
{
    tABC_Error error;
    ABC_PluginDataSet([self.account.name UTF8String],
                      [self.account.password UTF8String],
                      [folder UTF8String],
                      [key UTF8String],
                      [value UTF8String],
                      &error);
    return [ABCError makeNSError:error];
}

- (NSError *)dataRemoveKey:(NSString *)folder withKey:(NSString *)key;
{
    tABC_Error error;
    ABC_PluginDataRemove([self.account.name UTF8String],
                         [self.account.password UTF8String],
                         [folder UTF8String], [key UTF8String], &error);
    return [ABCError makeNSError:error];
}

- (NSError *)dataRemoveFolder:(NSString *)folder;
{
    tABC_Error error;
    ABC_PluginDataClear([self.account.name UTF8String],
                        [self.account.password UTF8String],
                        [folder UTF8String], &error);
    return [ABCError makeNSError:error];
}



@end