[![Litewallet](/images/header-ios.png)](https://itunes.apple.com/us/app/loafwallet/id1119332592)
======================

[![Release](https://img.shields.io/github/v/release/litecoin-foundation/loafwallet-ios?style=plastic)](https://img.shields.io/github/v/release/litecoin-foundation/loafwallet-ios)
[![GitHub issues](https://img.shields.io/github/issues/litecoin-foundation/loafwallet-ios?style=plastic)](https://github.com/litecoin-foundation/loafwallet-ios/re-frame/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/litecoin-foundation/loafwallet-ios?color=00ff00&style=plastic)](https://github.com/litecoin-foundation/loafwallet-ios/pulls) 
  
### The easy and secure Litecoin wallet

LoafWallet is the best way to get started with Litecoin. Our simple, streamlined design is easy for beginners, yet powerful enough for experienced users.

### Completely decentralized

Unlike other iOS Litecoin wallets, **LoafWallet** is a standalone Litecoin client. It connects directly to the Litecoin network using [SPV](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients) mode, and doesn't rely on servers that can be hacked or disabled. Even if LoafWallet is removed from the App Store, the app will continue to function, allowing users to access their money at any time.

### Cutting-edge security

**LoafWallet** utilizes AES hardware encryption, app sandboxing, and the latest iOS security features to protect users from malware, browser security holes, and even physical theft. Private keys are stored only in the secure enclave of the user's phone, inaccessible to anyone other than the user.

### Desgined with new users in mind

Simplicity and ease-of-use is **LoafWallet**'s core design principle. A simple recovery phrase (which we call a paper key) is all that is needed to restore the user's wallet if they ever lose or replace their device. **LoafWallet** is [deterministic](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki), which means the user's balance and transaction history can be recovered just from the paper key.

![screenshots](/images/screenshots.jpg)

### Features

- [Simplified payment verification](https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki) for fast mobile performance
- No server to get hacked or go down
- Single paper key is all that's needed to backup your wallet
- Private keys never leave your device
- Save a memo for each transaction (off-chain)
- Supports importing [password protected](https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki) paper wallets
- Supports ["Payment protocol"](https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki) payee identity certification

### Localization

**LoafWallet** is available in the following languages:

- Chinese (Simplified and traditional)
- Danish
- Dutch
- English
- French
- German
- Italian
- Japanese
- Korean
- Portuguese
- Russian
- Spanish
- Swedish

### WARNING:

***Installation on jailbroken devices is strongly discouraged.***

Any jailbreak app can grant itself access to every other app's keychain data. This means it can access your wallet and steal your Litecoin by self-signing as described [here](http://www.saurik.com/id/8) and including `<key>application-identifier</key><string>*</string>` in its .entitlements file.

---

**LoafWallet** is open source and available under the terms of the MIT license.

Source code is available at https://github.com/litecoin-foundation
