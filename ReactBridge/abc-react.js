"use strict"

import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View
} from 'react-native';

import { NativeModules, Platform, NativeAppEventEmitter, DeviceEventEmitter } from 'react-native';

var abc = null
var abcAccount = null

var AirbitzCoreRCT = NativeModules.AirbitzCoreRCT;

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
 * ABCTransaction Class
 */
class ABCTransaction {
  constructor(wallet, obj) {
    this.wallet = wallet
    for (var prop in obj)
      this[prop] = obj[prop];
  }

}

/**
 * ABCCallbacks
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
    abcAccount = this
  }

  static makeABCAccount(username, callbacks) {
    if (username === null) return null
    return new ABCAccount(username, callbacks)
  }

  /**
   * logout
   * @param callback: Callback with argument ABCError object
   */
  logout (callback) {
    AirbitzCoreRCT.logout(() => {
      callback()
    })
  }

  /**
   * passwordSet
   *
   * Set password for current ABCAccount
   *
   * @param password
   * @param callback: Callback with argument ABCError object
   */
  passwordSet(password, callback) {
    AirbitzCoreRCT.passwordSet(password, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * pinSet
   *
   * Set PIN for current ABCAccount
   *
   * @param pin
   * @param callback: Callback with argument ABCError object
   */
  pinSet(pin, callback) {
    AirbitzCoreRCT.pinSet(pin, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * passwordOk
   *
   * Checks if the given password is correct for the current ABCAccount
   *
   * @param password
   * @param callback: Callback with argument ABCError object
   *     ABCError: Error object
   *     bool passwordCorrect: TRUE if supplied password is correct
   */
  passwordOk(password, callback) {
    AirbitzCoreRCT.passwordOk(password, (rcterror, passwordCorrect) => {
      callback(ABCError.makeABCError(rcterror), passwordCorrect)
    })
  }

  /**
   * pinLoginEnable
   *
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
  pinLoginEnable(enable, callback) {
    AirbitzCoreRCT.pinLoginEnable(enable, (rcterror) => {
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
  otpKeySet(key, callback) {
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
  otpLocalKeyGet(callback) {
    AirbitzCoreRCT.otpLocalKeyGet((rcterror, otpKey) => {
      callback(ABCError.makeABCError(rcterror), otpKey)
    })
  }

  /**
   * otpDetailsGet
   *
   * @param callback: Callback with arguments
   *     ABCError: Error object
   *     bool otpEnabled: TRUE if OTP is enabled on this account
   *     long timeout: Number of seconds required after a reset is requested before OTP is disabled
   * @param error
   */
  otpDetailsGet(callback) {
    AirbitzCoreRCT.otpDetailsGet((rcterror, otpEnabled, timeout) => {
      callback(ABCError.makeABCError(rcterror), otpEnabled, timeout);
    })
  }

  /**
   * otpEnable
   *
   * Sets up OTP authentication on the server for currently logged in user
   * This will generate a new token if the username doesn't already have one.
   *
   * @param timeout: Number of seconds required after calling ABCContext.otpRequestReset before
   *     OTP is disabled
   * @param callback: Callback with arguments ABCError
   */
  otpEnable(timeout, callback) {
    AirbitzCoreRCT.otpEnable(timeout, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * otpDisable
   * Removes the OTP authentication requirement from the server for the
   * currently logged in user. Also removes local key from device
   * @param callback
   */
  otpDisable(callback) {
    AirbitzCoreRCT.otpDisable((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * otpResetRequestCancel
   *
   * Removes the OTP reset request from the server for the
   * currently logged in user
   *
   * @param callback
   */
  otpResetRequestCancel(callback) {
    AirbitzCoreRCT.otpResetRequestCancel((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  /**
   * bitidSign
   *
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

  bitidSign(uri, message, callback) {
    AirbitzCoreRCT.bitidSign(uri, message, (rcterror, address, signature) => {
      callback(ABCError.makeABCError(rcterror), address, signature)
    })
  }

  callbacksSet(callbacks) {
    this.callbacks = callbacks
  }
}

/**
 * makeABCContext
 *
 * Initialize an create an ABCContext object. Required for functionality of ABC SDK.
 *
 * @param apikey: get an API Key from https://developer.airbitz.co
 * @param hbits: Set to "" for now
 * @param callback
 */
function makeABCContext (apikey, hbits, callback) {
  AirbitzCoreRCT.init(apikey, hbits, (rcterror) => {
    if (rcterror) {
      callback(ABCError.makeABCError(rcterror), null)
    } else {
      callback(null, new ABCContext())
    }
  })
}

/**
 * ABCContext class
 */
class ABCContext {

  /**
   * accountCreate
   *
   * Create an Airbitz account with specified username, password, and PIN
   *
   * @param username
   * @param password
   * @param pin: 4 Digit PIN
   * @param callbacks: (Set to NULL for now)
   * @param callback: Callback with arguments (ABCError, ABCAccount)
   */
  accountCreate (username, password, pin, callbacks, callback) {
    AirbitzCoreRCT.accountCreate(username, password, pin, (rcterror, response) => {
      callback(ABCError.makeABCError(rcterror),
        ABCAccount.makeABCAccount(response, callbacks))
    })
  }

  /**
   * passwordLogin
   *
   * Login to an Airbitz account using username and password
   *
   * @param username
   * @param password
   * @param otp: otpKey if this account has OTP enabled
   * @param callbacks: (Set to NULL for now)
   * @param callback: Callback with arguments (ABCError, ABCAccount)
   */
  passwordLogin(username, password, otp, callbacks, callback) {
    AirbitzCoreRCT.passwordLogin(username, password, otp, (rcterror, response) => {
      callback(ABCError.makeABCError(rcterror),
        ABCAccount.makeABCAccount(response, callbacks))
    })
  }

  /**
   * pinLogin
   *
   * Sign In to an Airbitz account with PIN. Used to sign into devices that have previously
   * been logged into using a full username & password
   *
   * @param username
   * @param pin
   * @param callbacks: (Set to NULL for now)
   * @param callback: Callback with arguments (ABCError, ABCAccount)
   */
  pinLogin(username, pin, callbacks, callback) {
    AirbitzCoreRCT.pinLogin(username, pin, (rcterror, response) => {
      callback(ABCError.makeABCError(rcterror),
        ABCAccount.makeABCAccount(response, callbacks))
    })
  }

  /**
   * accountHasPassword
   *
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

  localAccountDelete(username, callback) {
    AirbitzCoreRCT.deleteLocalAccount(username, (rcterror) => {
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

module.exports.makeABCContext = makeABCContext
module.exports.ABCContext = ABCContext
module.exports.ABCAccount = ABCAccount
module.exports.ABCCallbacks = ABCCallbacks
module.exports.ABCConditionCode = abcc