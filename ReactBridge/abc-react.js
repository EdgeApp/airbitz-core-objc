"use strict"

import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View
} from 'react-native';

import { NativeModules, Platform, NativeAppEventEmitter, DeviceEventEmitter } from 'react-native';

var abcContext = null
var abcAccount = null

var AirbitzCoreRCT = NativeModules.AirbitzCoreRCT;

/**
 * ABCError
 *
 * Error structure returned in all ABC callbacks
 *   code: ABCConditionCode
 *   message: Error message
 *   message2 (optional):
 *   message3 (optional):
 */
class ABCError {
  constructor (message) {
    this.code = 0
    this.message = ""

    var obj = JSON.parse(message);
    console.log("ABCError: Generated")
    for (var prop in obj) {
      this[prop] = obj[prop];
      console.log("ABCError:" + prop + ": " + obj[prop])
    }
  }

  static makeABCError(message) {
    if (message === null) return null
    return new ABCError(message)
  }
}

/**
 * ABCTransaction Class (do not use)
 */
class ABCTransaction {
  constructor(wallet, obj) {
    this.wallet = wallet
    for (var prop in obj)
      this[prop] = obj[prop];
  }

}

/**
 * ABCCallbacks (do not use)
 */
class ABCCallbacks {
  constructor() {
    this.abcAccountAccountChanged = function(account) {}
    this.abcAccountWalletsLoaded = function(account) {}
    this.abcAccountWalletChanged = function(wallet) {}
  }
}

/**
 * ABCAccount Class
 *
 * Not to be constructed directly from API. This is returned by accountCreate, passwordLogin,
 * pinLogin, etc.
 */
class ABCAccount {
  constructor(username, callbacks) {
    console.log("ABCAccount created: " + username)
    this.username = username
    this.callbacks = callbacks
    this.dataStore = new ABCDataStore()
    abcAccount = this
  }

  static makeABCAccount(username, callbacks) {
    if (username === null) return null
    return new ABCAccount(username, callbacks)
  }

  /**
   * Logout current user
   *
   * @param callback: Callback with argument ABCError object
   */
  logout (callback) {
    AirbitzCoreRCT.logout(() => {
      callback()
    })
  }

  /**
   * Set password for current ABCAccount
   *
   * @param password
   * @param callback: Callback with argument ABCError object
   */
  setPassword(password, callback) {
    AirbitzCoreRCT.setPassword(password, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Set PIN for current ABCAccount
   *
   * @param pin
   * @param callback: Callback with argument ABCError object
   */
  setPIN(pin, callback) {
    AirbitzCoreRCT.setPIN(pin, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Checks if the given password is correct for the current ABCAccount
   *
   * @param password
   * @param callback: Callback with argument ABCError object
   *     ABCError: Error object
   *     bool passwordCorrect: TRUE if supplied password is correct
   */
  checkPassword(password, callback) {
    AirbitzCoreRCT.checkPassword(password, (rcterror, passwordCorrect) => {
      callback(ABCError.makeABCError(rcterror), passwordCorrect)
    })
  }

  /**
   * Enable or disable PIN login on this account. Set enable = true to allow
   * PIN login. Enabling PIN login creates a local account decryption key that
   * is split with one half in local device storage and the other half on Airbitz
   * servers. When using pinLogin() the PIN is sent to Airbitz servers
   * to authenticate the user. If the PIN is correct, the second half of the decryption
   * key is sent back to the device. Combined with the locally saved key, the two
   * are then used to decrypt the local account thereby logging in the user.
   *
   * @param Bool enable: TRUE to allow PIN logins
   * @param callback: Callback with argument ABCError object
   *     ABCError: Error object
   */
  enablePINLogin(enable, callback) {
    AirbitzCoreRCT.enablePINLogin(enable, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Set the OTP key for the currently logged in account
   *
   * Associates an OTP key with the account. An OTP key can be retrieved from
   * a previously logged in account using otpLocalKeyGet. The account
   * must have had OTP enabled by using otpEnable()
   *
   * @param key
   * @param callback: Callback with argument ABCError object
   *     ABCError: Error object
   */
  setupOTPKey(key, callback) {
    AirbitzCoreRCT.otpKeySet(key, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Gets the locally saved OTP key for the current user
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     otpKey: String
   */
  getOTPLocalKey(callback) {
    AirbitzCoreRCT.getOTPLocalKey((rcterror, otpKey) => {
      callback(ABCError.makeABCError(rcterror), otpKey)
    })
  }

  /**
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     bool otpEnabled: TRUE if OTP is enabled on this account
   *     long timeout: Number of seconds required after a reset is requested before OTP is disabled
   * @param error
   */
  getOTPDetails(callback) {
    AirbitzCoreRCT.getOTPDetails((rcterror, otpEnabled, timeout) => {
      callback(ABCError.makeABCError(rcterror), otpEnabled, timeout);
    })
  }

  /**
   * Sets up OTP authentication on the server for currently logged in user
   * This will generate a new token if the username doesn't already have one.
   *
   * @param timeout: Number of seconds required after calling ABCContext.otpRequestReset before
   *     OTP is disabled
   * @param callback: Callback with arguments ABCError
   */
  enableOTP(timeout, callback) {
    AirbitzCoreRCT.enableOTP(timeout, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Removes the OTP authentication requirement from the server for the
   * currently logged in user. Also removes local key from device
   * @param callback
   */
  disableOTP(callback) {
    AirbitzCoreRCT.disableOTP((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Removes the OTP reset request from the server for the
   * currently logged in user
   *
   * @param callback
   */
  cancelOTPResetRequest(callback) {
    AirbitzCoreRCT.cancelOTPResetRequest((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Sign an arbitrary message with a BitID URI. The URI determines the key derivation
   * used to sign the message.
   *
   * @param uri: Server URI in the form "bitid://server.com/bitid"
   * @param message:
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     String address: public address used to sign message. Derived from 'uri'
   *     String signature: Signature of 'message' signed with private key corresponding
   *                       to public address returned above. Private key is derived from
   *                       master private key and 'uri'
   */
  signBitIDRequest(uri, message, callback) {
    AirbitzCoreRCT.signBitIDRequest(uri, message, (rcterror, address, signature) => {
      callback(ABCError.makeABCError(rcterror), address, signature)
    })
  }

  callbacksSet(callbacks) {
    this.callbacks = callbacks
  }
}

/**
 * ABCContext class
 *
 * Starting point of Airbitz Core SDK. Used for operations that do not require a logged in
 * ABCAccount
 */
class ABCContext {

  /**
   * Initialize and create an ABCContext object. Required for functionality of ABC SDK.
   *
   * @param {string} apikey Get an API Key from https://developer.airbitz.co
   * @param {string} hbits Set to null for now
   */
  static makeABCContext (apikey, hbits, callback) {
    if (abcContext)
      callback(null, abcContext)
    else {
      AirbitzCoreRCT.init(apikey, hbits, (rcterror) => {
        var abcError = ABCError.makeABCError(rcterror)
        if (abcError && (abcError.code != abcc.ABCConditionCodeReinitialization)) {
          callback(abcError, null)
        } else {
          abcContext = new ABCContext()
          callback(null, abcContext)
        }
      })
    }
  }


  /**
   * Create an Airbitz account with specified username, password, and PIN
   *
   * @param username
   * @param password
   * @param pin: 4 Digit PIN
   * @param callbacks: (Set to NULL for now)
   * @param callback: Callback with arguments (ABCError, ABCAccount)
   */
  createAccount (username, password, pin, callbacks, callback) {
    AirbitzCoreRCT.createAccount(username, password, pin, (rcterror, response) => {
      callback(ABCError.makeABCError(rcterror),
        ABCAccount.makeABCAccount(response, callbacks))
    })
  }

  /**
   * Login to an Airbitz account using username and password
   *
   * @param username
   * @param password
   * @param otp: otpKey if this account has OTP enabled
   * @param callbacks: (Set to NULL for now)
   * @param callback: Callback with arguments (ABCError, ABCAccount)
   */
  loginWithPassword(username, password, otp, callbacks, callback) {
    AirbitzCoreRCT.loginWithPassword(username, password, otp, (rcterror, response) => {
      callback(ABCError.makeABCError(rcterror),
        ABCAccount.makeABCAccount(response, callbacks))
    })
  }

  /**
   * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
   * been logged into using a full username & password
   *
   * @param username
   * @param pin
   * @param callbacks: (Set to NULL for now)
   * @param callback: Callback with arguments (ABCError, ABCAccount)
   */
  loginWithPIN(username, pin, callbacks, callback) {
    AirbitzCoreRCT.loginWithPIN(username, pin, (rcterror, response) => {
      callback(ABCError.makeABCError(rcterror),
        ABCAccount.makeABCAccount(response, callbacks))
    })
  }

  /**
   * Check if the given username has a password on the account or if it is
   * a PIN-only account.
   *
   * @param username
   * @param callback: Callback with arguments (ABCError, Boolean hasPassword)
   */
  accountHasPassword(username, callback) {
    AirbitzCoreRCT.accountHasPassword(username, (rcterror, hasPassword) => {
      callback(ABCError.makeABCError(rcterror), hasPassword)
    })
  }

  /**
   * Deletes named account from local device. Account is recoverable if it contains a password.
   * Use ABCContext.accountHasPassword to determine if account has a password. Recommend warning
   * user before executing deleteLocalAccount if accountHasPassword returns FALSE.
   *
   * @param username
   * @param callback: Callback with arguments (ABCError)
   */
  deleteLocalAccount(username, callback) {
    AirbitzCoreRCT.deleteLocalAccount(username, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Get a list of previously logged in usernames on this device
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     Array usernames: usernames logged into this device
   */
  listUsernames(callback) {
    AirbitzCoreRCT.listUsernames((rcterror, usernames) => {
      callback(ABCError.makeABCError(rcterror), usernames)
    })
  }

  /**
   * Checks if username is available on the global Airbitz username space. This requires
   * network connectivity to function.
   * @param username String username to check
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     Boolean available: TRUE if username is available
   */
  usernameAvailable(username, callback) {
    AirbitzCoreRCT.usernameAvailable(username, (rcterror, available) => {
      callback(ABCError.makeABCError(rcterror), available)
    })
  }

  /**
   * Checks if PIN login is possible for the given username. This checks if
   * there is a local PIN package on the device from a prior login. Will always return false
   * if user never logged into this device
   * @param username String username to check
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     Boolean enabled: TRUE if username allows PIN login
   */
  pinLoginEnabled(username, callback) {
    AirbitzCoreRCT.pinLoginEnabled(username, (rcterror, enabled) => {
      callback(ABCError.makeABCError(rcterror), enabled)
    })
  }
}

class ABCDataStore {
  constructor() {

  }

  /**
   * Writes a key value pair into the data store.
   * 
   * @param folder String folder name to write data
   * @param key String key of data
   * @param value String value of data to write
   * @param callback: Callback with arguments (ABCError)
   */
  writeData(folder, key, value, callback) {
    AirbitzCoreRCT.writeData(folder, key, value, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Reads a key value pair from the data store
   *
   * @param folder String folder name to read data
   * @param key String key of data
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     String data: Data value from corresponding key
   */
  readData(folder, key, callback) {
    AirbitzCoreRCT.readData(folder, key, (rcterror, data) => {
      callback(ABCError.makeABCError(rcterror), data)
    })
  }

  /**
   * Removes key value pair from the data store.
   * @param folder String folder name to read data
   * @param key String key of data
   * @param callback: Callback with arguments (ABCError)
   */
  removeDataKey(folder, key, callback) {
    AirbitzCoreRCT.removeDataKey(folder, key, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * Lists all the keys in a folder of the dataStore.
   * @param folder String folder name to read data
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     Array keys: Array of String with key names
   */
  listDataKeys(folder, callback) {
    AirbitzCoreRCT.listDataKeys(folder, (rcterror, keys) => {
      callback(ABCError.makeABCError(rcterror), keys)
    })
  }

  /**
   * Removes all key value pairs from the specified folder in the data store.
   * @param folder String folder name to read data
   * @param callback: Callback with arguments (ABCError)
   */
  removeDataFolder(folder, callback) {
    AirbitzCoreRCT.removeDataFolder(folder, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }
}

/**
 * ABCConditionCode
 * Error codes for ABCError object
 */
class ABCConditionCode {
  constructor() {
    this.ABCConditionCodeOk = 0
    this.ABCConditionCodeError = 1
    this.ABCConditionCodeNULLPtr = 2
    this.ABCConditionCodeNoAvailAccountSpace = 3
    this.ABCConditionCodeDirReadError = 4
    this.ABCConditionCodeFileOpenError = 5
    this.ABCConditionCodeFileReadError = 6
    this.ABCConditionCodeFileWriteError = 7
    this.ABCConditionCodeFileDoesNotExist = 8
    this.ABCConditionCodeUnknownCryptoType = 9
    this.ABCConditionCodeInvalidCryptoType = 10
    this.ABCConditionCodeDecryptError = 11
    this.ABCConditionCodeDecryptFailure = 12
    this.ABCConditionCodeEncryptError = 13
    this.ABCConditionCodeScryptError = 14
    this.ABCConditionCodeAccountAlreadyExists = 15
    this.ABCConditionCodeAccountDoesNotExist = 16
    this.ABCConditionCodeJSONError = 17
    this.ABCConditionCodeBadPassword = 18
    this.ABCConditionCodeWalletAlreadyExists = 19
    this.ABCConditionCodeURLError = 20
    this.ABCConditionCodeSysError = 21
    this.ABCConditionCodeNotInitialized = 22
    this.ABCConditionCodeReinitialization = 23
    this.ABCConditionCodeServerError = 24
    this.ABCConditionCodeNoRecoveryQuestions = 25
    this.ABCConditionCodeNotSupported = 26
    this.ABCConditionCodeMutexError = 27
    this.ABCConditionCodeNoTransaction = 28
    this.ABCConditionCodeEmpty_Wallet = 28
    this.ABCConditionCodeParseError = 29
    this.ABCConditionCodeInvalidWalletID = 30
    this.ABCConditionCodeNoRequest = 31
    this.ABCConditionCodeInsufficientFunds = 32
    this.ABCConditionCodeSynchronizing = 33
    this.ABCConditionCodeNonNumericPin = 34
    this.ABCConditionCodeNoAvailableAddress = 35
    this.ABCConditionCodeInvalidPinWait = 36
    this.ABCConditionCodePinExpired = 36
    this.ABCConditionCodeInvalidOTP = 37
    this.ABCConditionCodeSpendDust = 38
    this.ABCConditionCodeObsolete = 1000
  }
}
var abcc = new ABCConditionCode()

module.exports.ABCContext = ABCContext
module.exports.ABCAccount = ABCAccount
module.exports.ABCCallbacks = ABCCallbacks
module.exports.ABCConditionCode = abcc