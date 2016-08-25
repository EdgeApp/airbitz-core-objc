//
// ABCDataStore.m
//
// Created by Paul Puey on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "ABCContext+Internal.h"

@interface ABCDataStore ()
{
}

@property                           ABCAccount          *account;

@end

@implementation ABCDataStore

#pragma Data Methods

- (ABCError *)dataRead:(NSString *)folder withKey:(NSString *)key data:(NSMutableString *)data;
{
    [data setString:@""];
    tABC_Error error;
    char *szData = NULL;
    ABC_PluginDataGet([self.account.name UTF8String],
                      [self.account.password UTF8String],
                      [folder UTF8String], [key UTF8String],
                      &szData, &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror) {
        [data setString:[NSString stringWithUTF8String:szData]];
    }
    if (szData != NULL) {
        free(szData);
    }
    return nserror;
}

- (ABCError *)dataWrite:(NSString *)folder withKey:(NSString *)key withValue:(NSString *)value;
{
    tABC_Error error;
    ABC_PluginDataSet([self.account.name UTF8String],
                      [self.account.password UTF8String],
                      [folder UTF8String],
                      [key UTF8String],
                      [value UTF8String],
                      &error);
    
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [self.account dataSyncAccount];
    }
    return nserror;
}

- (ABCError *)dataListKeys:(NSString *)folder keys:(NSMutableArray *)keys;
{
    tABC_Error error;
    char **szKeys = NULL;
    unsigned int count;
    ABC_PluginDataKeys([self.account.name UTF8String],
                      [self.account.password UTF8String],
                      [folder UTF8String],
                      &szKeys, &count, &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            [keys addObject:[NSString stringWithUTF8String:szKeys[i]]];
        }
    }
    if (szKeys != NULL) {
        free(szKeys);
    }
    return nserror;
}



- (ABCError *)dataRemoveKey:(NSString *)folder withKey:(NSString *)key;
{
    tABC_Error error;
    ABC_PluginDataRemove([self.account.name UTF8String],
                         [self.account.password UTF8String],
                         [folder UTF8String], [key UTF8String], &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [self.account dataSyncAccount];
    }
    return nserror;
}

- (ABCError *)dataRemoveFolder:(NSString *)folder;
{
    tABC_Error error;
    ABC_PluginDataClear([self.account.name UTF8String],
                        [self.account.password UTF8String],
                        [folder UTF8String], &error);
    ABCError *nserror = [ABCError makeNSError:error];
    if (!nserror)
    {
        [self.account dataSyncAccount];
    }
    return nserror;
}



@end