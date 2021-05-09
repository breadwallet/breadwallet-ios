[![Bread](/images/top-logo.png)](https://itunes.apple.com/app/breadwallet/id885251393)

## BRD is the simple and secure wallet for bitcoin, ethereum, and other digital assets. Today, BRD is one of the largest non-custodial mobile wallets used by over 6 million users and protects an estimated nearly $7B USD.

BRD is the best way to get started with bitcoin. Our simple, streamlined design is easy for beginners, yet powerful enough for experienced users.

### Fastsync
[Fastsync](https://brd.com/blog/fastsync-explained) is a new feature in the BRD app that makes Bitcoin wallets sync in seconds, while also keeping BRD technology ahead of the curve as SPV slowly phases out. When Fastsync is enabled the BRD wallet uses our server technology, [Blockset](https://docs.blockset.com/) to sync, send and receive instantly!

### Your Decentralized Bitcoin Wallet

Unlike other iOS bitcoin wallets, **BRD** users have the option to disable Fastsync converting the wallet into a standalone bitcoin client. It connects directly to the bitcoin network using [SPV](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients) mode, and doesn't rely on servers that can be hacked or disabled. If BRD the company disappears, your private key can still be derived from the recovery phrase to recover your funds since your funds exist on the blockchain.

### Cutting-edge security

**BRD** utilizes the latest iOS security features to protect users from malware, browser security holes, and even physical theft. The user’s private key is stored in the device keychain, secured by Secure Enclave, inaccessible to anyone other than the user. Users are also able to backup their wallet using iCloud Keychain to store an encrypted backup of their recovery phrase.  The backup is encrypted with the BRD app PIN.

### Designed with New Users in Mind

Simplicity and ease-of-use is **BRD**'s core design principle. A simple recovery phrase (which we call a recovery key) is all that is needed to restore the user's wallet if they ever lose or replace their device. **BRD** is [deterministic](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki), which means the user's balance and transaction history can be recovered just from the recovery key.

![screenshots](/images/brd-hero-mockup.png)

### Features

- Supports wallets for Bitcoin, Bitcoin Cash, Ethereum and ERC-20 tokens, Ripple, Hedera, Tezos
- Single recovery key is all that's needed to backup your wallet
- Private keys never leave your device and are end-to-end encrypted when using iCloud backup
- Save a memo for each transaction (off-chain)

### Bitcoin Specific Features
- Supports importing [password protected](https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki) paper wallets
- Supports [JSON payment protocol](https://bitpay.com/docs/payment-protocol)
- Supports SegWit and bech32 addresses

### Localization

**BRD** is available in the following languages:

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

## Development Setup

1. Clone the repo: `git clone git@github.com:breadwallet/breadwallet-ios.git`
2  Update submodules `git submodule update --recursive`
3. Install imagemagick and ghostscript `brew install imagemagick' && 'brew install ghostscript`
4. Open the `breadwallet.xcworkspace` file

## Advanced Setup

### Blockset Client Token

Add your [Blockset client token](https://docs.blockset.com/getting-started/authenticationhttps://blockset.com/docs/v1/tools/authentication) to your app’s public CloudKit database with a record id of: `BlockchainDBClientID` 

### WARNING:

***Installation on jailbroken devices is strongly discouraged.***

Any jailbreak app can grant itself access to every other app's keychain data. This means it can access your wallet and steal your bitcoin by self-signing as described [here](http://www.saurik.com/id/8) and including `<key>application-identifier</key><string>*</string>` in its .entitlements file.

---

**BRD** is open source and available under the terms of the MIT license.

Source code is available at https://github.com/breadwallet
