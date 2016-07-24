
import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View
} from 'react-native';

import { NativeModules } from 'react-native';
import { NativeAppEventEmitter } from 'react-native';

var abc = null
var abcAccount = null

var accountWalletLoadedSubscription = NativeAppEventEmitter.addListener(
  'abcAccountWalletLoaded', (wallet) => {
    walletLoaded(wallet.uuid)
  }
);

function walletLoaded(uuid) {
  if (abcAccount) {
    if (abcAccount.callbacks.abcAccountWalletLoaded) {
      for (w in abcAccount.getWallets()) {
        if (w.uuid == uuid) {
          abcAccount.callbacks.abcAccountWalletLoaded(w)
        }
      }
    }
  }
}

var accountAccountChangedSubscription = NativeAppEventEmitter.addListener(
  'abcAccountAccountChanged', (response) => {
    accountChanged(response.name)
  }
);

function accountChanged (name) {
  console.log(name)
  if (abcAccount && abcAccount.name == name) {
    if (abcAccount.callbacks.abcAccountAccountChanged) {
      abcAccount.callbacks.abcAccountAccountChanged(abcAccount)
    }
  }
}

var AirbitzCoreRCT = NativeModules.AirbitzCoreRCT;

class ABCError {
  constructor(message) {
    var obj = JSON.parse(message);
    for (var prop in obj)
      this[prop] = obj[prop];
    console.log("ABCError:" + this.code + ": " + this.description)
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

  getTransactions(complete, error) {
    AirbitzCoreRCT.getTransactions((rtcerror, transactions) => {
      var txs = JSON.parse(transactions);

      for (i = 0; i < txs.length; i++) {
        txsReturn[i] = new ABCTransaction(this, txs[i])
      }

      complete(txsReturn)
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }
}

/**
 * ABCCallbacks
 */
class ABCCallbacks {
  constructor() {
    this.abcAccountAccountChanged = function() {}
    this.abcAccountWalletLoaded = function() {}
  }
}

/**
 * ABCAccount Class
 */
class ABCAccount {
  constructor(name, callbacks) {
    this.name = name
    this.callbacks = callbacks
    abcAccount = this
  }

  /**
   * logout
   * @param complete
   */
  logout (complete) {
    AirbitzCoreRCT.logout(() => {
      complete()
    })
  }

  /**
   * changePassword
   * @param password
   * @param complete
   * @param error
   */
  changePassword(password, complete, error) {
    AirbitzCoreRCT.changePassword(password, (rtcerror, response) => {
      complete()
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * changePIN
   * @param pin
   * @param complete
   * @param error
   */
  changePIN(pin, complete, error) {
    AirbitzCoreRCT.changePIN(pin, (rtcerror, response) => {
      complete()
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * checkPassword
   * @param password
   * @param complete
   * @param error
   */
  checkPassword(password, complete, error) {
    AirbitzCoreRCT.checkPassword(password, (error, response) => {
      complete(response)
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * pinLoginSetup
   * @param enable
   * @param complete
   * @param error
   */
  pinLoginSetup(enable, complete, error) {
    AirbitzCoreRCT.pinLoginSetup(enable, (rtcerror, response) => {
      complete(response)
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

  setCallbacks(callbacks) {
    this.callbacks = callbacks
  }

  getWallets(complete, error) {
    AirbitzCoreRCT.getWallets((rtcerror, response) => {
      var ws = JSON.parse(response)

      for (i = 0; i < ws.length; i++) {
        walletsReturn[i] = new ABCWallet(this, ws[i])
      }
      complete(walletsReturn)
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

}

/**
 * AirbitzCore class
 */
class AirbitzCore {

  /**
   * init
   *
   * @param apikey
   * @param hbits
   * @param complete
   * @param error
   */
  init (apikey, hbits, complete, error) {
    AirbitzCoreRCT.init(apikey, hbits, (error, response) => {
      console.log("ABC Initialized")
      abc  = this
      complete()
    }, (rcterror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * createAccount
   *
   * @param username
   * @param password
   * @param pin
   * @param complete
   * @param error
   */
  createAccount (username, password, pin, callbacks, complete, error) {
    AirbitzCoreRCT.createAccount(username, password, pin, (rcterror, response) => {
      console.log("account created")
      complete(new ABCAccount(response, callbacks))
    }, (rcterror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * passwordLogin
   *
   * @param username
   * @param password
   * @param otp
   * @param complete
   * @param error
   */
  passwordLogin(username, password, otp, callbacks, complete, error) {
    AirbitzCoreRCT.passwordLogin(username, password, otp, (rcterror, response) => {
      complete(new ABCAccount(response, callbacks))
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * pinLogin
   *
   * @param username
   * @param pin
   * @param complete
   * @param error
   */
  pinLogin(username, pin, callbacks, complete, error) {
    AirbitzCoreRCT.pinLogin(username, pin, (rcterror, response) => {
      complete(new ABCAccount(response, callbacks))
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }

  /**
   * accountHasPassword
   * @param accountName
   * @param complete
   * @param error
   */
  accountHasPassword(accountName, complete, error) {
    AirbitzCoreRCT.accountHasPassword(accountName, (rtcerror, response) => {
      complete(response)
    }, (rtcerror, response) => {
      error(new ABCError(response))
    })
  }


}


module.exports.AirbitzCore = AirbitzCore
module.exports.ABCCallbacks = ABCCallbacks