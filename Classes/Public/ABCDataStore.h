//
// ABCDataStore.h
//
// Created by Paul P on 2016/02/27.
// Copyright (c) 2016 Airbitz. All rights reserved.
//

#import "AirbitzCore.h"

/**
 * The ABCDataStore object implements the Airbitz auto-encrypted, auto-backed up, and auto 
 * synchronized Edge Security data storage. ABCDataStore is end-to-end encrypted with no access to the
 * data by Airbitz, other users, or developers. Data is encrypted<br>
 * <br>
 * Data is saved as key/value pairs in named folders. Usage is as simple as calling
 * dataWrite to write data to this ABCDataStore using a unique folderID. Then calling
 * dataRead to read back the data.<br>
 * <br>
 * Note: Data written using the same folderID and same key may generate conflicts when multiple devices
 * write to the same DataStore. In such a case, automatic
 * conflict resolution will chose the most likely newer update to the data. Writing
 * to different folderIDs or keys will not cause conflicts.<br>
 * <br>
 * ABCDataStore will automatically
 * backup all data and synchronize between all user's devices as long as the devices are
 * online. If devices are offline, the data will sync as soon as the device comes back online
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
