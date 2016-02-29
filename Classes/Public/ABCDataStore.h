//
// ABCDataStore.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

/**
 * The ABCDataStore object implements the Airbitz auto-encrypted, auto-backed up, and auto 
 * synchronized secure data storage.<br>
 * <br>
 * Data is saved as key/value pairs in named folders.
 */

@interface ABCDataStore : NSObject

/**
 * Writes a key value pair into the data store.
 * @param folder NSString* folder name to write data
 * @param key NSString* key of data
 * @param value NSString* value of data to write
 * @return NSError* Error object. Nil if success
 */
- (NSError *)dataWrite:(NSString *)folder withKey:(NSString *)key withValue:(NSString *)value;

/**
 * Reads a key value pair from the data store.
 * @param folder NSString* folder name to read data
 * @param key NSString* key of data
 * @param data Initialized & allocated NSMutableString* to receive data
 * @return NSError* Error object. Nil if success
 */
- (NSError *)dataRead:(NSString *)folder withKey:(NSString *)key data:(NSMutableString *)data;

/**
 * Removes key value pair from the data store.
 * @param folder NSString* folder name to read data
 * @param key NSString* key of data
 * @return NSError* Error object. Nil if success
 */
- (NSError *)dataRemoveKey:(NSString *)folder withKey:(NSString *)key;

/**
 * Removes all key value pairs from the specified folder in the data store.
 * @param folder NSString* folder name to read data
 * @return NSError* Error object. Nil if success
 */
- (NSError *)dataRemoveFolder:(NSString *)folder;

@end
