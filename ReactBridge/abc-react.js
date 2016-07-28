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
 * ABCWallet Class
 */
class ABCWallet {
  constructor(account, obj) {
    this.account = account
    for (var prop in obj)
      this[prop] = obj[prop];
  }

  // getTransactions(callback) {
  //   AirbitzCoreRCT.getTransactions((rcterror, transactions) => {
  //     var txs = JSON.parse(transactions);
  //     var txsReturn
  //
  //     for (var i = 0; i < txs.length; i++) {
  //       txsReturn[i] = new ABCTransaction(this, txs[i])
  //     }
  //
  //     callback(txsReturn)
  //   }, (rcterror, response) => {
  //     error(ABCError.makeABCError(response))
  //   })
  // }
}

/**
 * ABCCallbacks
 */
class ABCCallbacks {
  constructor() {
    this.abcAccountAccountChanged = function(account) {}
    this.abcAccountWalletsLoaded = function(account) {}
    this.abcAccountWalletChanged = function(account, wallet) {}
  }
}

/**
 * ABCAccount Class
 */
class ABCAccount {
  constructor(name, callbacks) {
    console.log("ABCAccount created: " + name)
    this.name = name
    this.callbacks = callbacks
    abcAccount = this
  }

  static makeABCAccount(name, callbacks) {
    if (name === null) return null
    return new ABCAccount(name, callbacks)
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
   * @param key
   * @param callback: Callback with argument ABCError object
   *     ABCError: Error object
   */
  otpKeySet(key, callback) {
    AirbitzCoreRCT.otpKeySet(key, (rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

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
   * @param timeout: Number of seconds required after calling AirbitzCore.otpRequestReset before
   *     OTP is disabled
   * @param callback: Callback with arguments ABCError
   */
  otpEnable(timeout, callback) {
    AirbitzCoreRCT.enableOTP((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  otpDisable(callback) {
    AirbitzCoreRCT.disableOTP((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  otpResetRequestCancel(callback) {
    AirbitzCoreRCT.cancelOTPResetRequest((rcterror) => {
      callback(ABCError.makeABCError(rcterror))
    })
  }

  callbacksSet(callbacks) {
    this.callbacks = callbacks
  }

  // getWallets(callback) {
  //   AirbitzCoreRCT.getWallets((rcterror, response) => {
  //     var ws = JSON.parse(response)
  //     var walletsReturn
  //
  //     for (var i = 0; i < ws.length; i++) {
  //       walletsReturn[i] = new ABCWallet(this, ws[i])
  //     }
  //     callback(walletsReturn)
  //   }, (rcterror, response) => {
  //     error(ABCError.makeABCError(response))
  //   })
  // }

}

/**
 * AirbitzCore class
 */
class AirbitzCore {

  /**
   * makeABCContext
   *
   * @param apikey
   * @param hbits: Set to "" for now
   * @param callback
   */
  makeABCContext (apikey, hbits, callback) {
    AirbitzCoreRCT.init(apikey, hbits, (rcterror) => {
      if (rcterror) {
        callback(ABCError.makeABCError(rcterror))
      } else {
        console.log("ABC Initialized")
        abc = this
        callback()
      }
    })
  }

  /**
   * accountCreate
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
   * @param username
   * @param password
   * @param otp
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

/*
 * Event callbacks
 */

// //
// // abcAccountAccountChanged callback
// //
// const accountAccountChangedSubscription = Platform.OS == 'ios' ? NativeAppEventEmitter : DeviceEventEmitter;
// accountAccountChangedSubscription.addListener("abcAccountAccountChanged", (e:Event) => {
//   accountChanged(e.name)
//   console.log(e)
// })
//
// function accountChanged (name) {
//   console.log(name)
//   if (abcAccount && abcAccount.name == name) {
//     if (abcAccount.callbacks.abcAccountAccountChanged) {
//       abcAccount.callbacks.abcAccountAccountChanged(abcAccount)
//     }
//   }
// }
//
// //
// // abcAccountWalletChanged
// //
// const accountWalletChangedSubscription = Platform.OS == 'ios' ? NativeAppEventEmitter : DeviceEventEmitter;
// accountWalletChangedSubscription.addListener("abcAccountWalletChanged", (e:Event) => {
//   if (abcAccount) {
//     abcAccount.getWallets((wallets) => {
//       for (var w in wallets) {
//         if (w.uuid)
//       }
//     }, (error) => {
//
//     })
//   }
//
//   walletChanged(abcAccount, wallet)
//
//
//   }
// );
//
// function walletsLoaded() {
//   if (abcAccount) {
//     if (abcAccount.callbacks.abcAccountWalletsLoaded) {
//       abcAccount.getWallets((response) => {
//         for (var w in response) {
//           if (w.uuid == uuid) {
//             abcAccount.callbacks.abcAccountWalletLoaded(w)
//           }
//         }
//       }, (error) => {})
//     }
//   }
// }
//
//
// //
// // abcAccountWalletsLoaded
// //
// const accountWalletsLoadedSubscription = Platform.OS == 'ios' ? NativeAppEventEmitter : DeviceEventEmitter;
// accountWalletsLoadedSubscription.addListener("abcAccountWalletsLoaded", (e:Event) => {
//     walletsLoaded()
//   }
// );
//
// function walletsLoaded() {
//   if (abcAccount) {
//     if (abcAccount.callbacks.abcAccountWalletsLoaded) {
//       abcAccount.getWallets((response) => {
//         for (var w in response) {
//           if (w.uuid == uuid) {
//             abcAccount.callbacks.abcAccountWalletLoaded(w)
//           }
//         }
//       }, (error) => {})
//     }
//   }
// }
//
//

module.exports.AirbitzCore = AirbitzCore
module.exports.ABCCallbacks = ABCCallbacks