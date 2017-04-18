//
//  Strings.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-14.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

enum S {

    enum Symbols {
        static let bits = "ƀ"
        static let narrowSpace = "\u{2009}"
    }

    enum Button {
        static let ok = NSLocalizedString("OK", comment: "OK button label")
        static let cancel = NSLocalizedString("Cancel", comment: "Cancel button label")
        static let settings = NSLocalizedString("Settings", comment: "Settings button label")
        static let submit = NSLocalizedString("Submit", comment: "Settings button label")
    }

    enum Scanner {
        static let flashButtonLabel = NSLocalizedString("Camera Flash", comment: "Scan bitcoin address camera flash toggle")
    }

    enum Send {
        static let toLabel = NSLocalizedString("To", comment: "Send money to label")
        static let amountLabel = NSLocalizedString("Amount", comment: "Send money amount label")
        static let descriptionLabel = NSLocalizedString("What's this for?", comment: "Description for sending money label")
        static let sendLabel = NSLocalizedString("Send", comment: "Send button label")
        static let pasteLabel = NSLocalizedString("Paste", comment: "Paste button label")
        static let scanLabel = NSLocalizedString("Scan", comment: "Scan button label")
        static let defaultCurrencyLabel = NSLocalizedString("BTC (\(S.Symbols.bits))", comment: "Currency Button label")
        static let invalidAddressTitle = NSLocalizedString("Invalid Address", comment: "Invalid address alert title")
        static let invalidAddressMessage = NSLocalizedString("Your clipboard does not have a valid bitcoin address.", comment: "Invalid address alert message")

        static let cameraUnavailableTitle = NSLocalizedString("Bread is not allowed to access the camera", comment: "Camera not allowed alert title")
        static let cameraUnavailableMessage = NSLocalizedString("Go to Settings to Allow camera access.", comment: "Camera not allowed message")
    }

    enum Receive {
        static let title = NSLocalizedString("Receive", comment: "Receive modal title")
        static let emailButton = NSLocalizedString("Email", comment: "Share via email button label")
        static let textButton = NSLocalizedString("Text Message", comment: "Share via text message label")
        static let copied = NSLocalizedString("Copied to Clipboard.", comment: "Address copied message.")
        static let share = NSLocalizedString("Share", comment: "Share button label")
        static let request = NSLocalizedString("Request an Amount", comment: "Request button label")
    }

    enum Account {
        static let loadingMessage = NSLocalizedString("Loading Wallet", comment: "Loading Wallet Message")
    }

    enum JailbreakWarnings {
        static let title = NSLocalizedString("WARNING", comment: "Jailbreak warning title")
        static let messageWithBalance = NSLocalizedString("DEVICE SECURITY COMPROMISED\n Any 'jailbreak' app can access any other app's keychain data (and steal your bitcoins). Wipe this wallet immediately and restore on a secure device.", comment: "Jailbreak warning message")
        static let messageWithoutBalance = NSLocalizedString("DEVICE SECURITY COMPROMISED\n Any 'jailbreak' app can access any other app's keychain data (and steal your bitcoins).", comment: "Jailbreak warning message")
        static let ignore = NSLocalizedString("Ignore", comment: "Ignore jailbreak warning button")
        static let wipe = NSLocalizedString("Wipe", comment: "Wipe wallet button")
        static let close = NSLocalizedString("Close", comment: "Close app button")
    }

    enum ErrorMessages {
        static let emailUnavailableTitle = NSLocalizedString("Email unavailable", comment: "Email unavailable alert title")
        static let emailUnavailableMessage = NSLocalizedString("This device isn't configured to send email with the iOS mail app.", comment: "Email unavailable alert title")
        static let messagingUnavailableTitle = NSLocalizedString("Messaging unavailable", comment: "Messaging unavailable alert title")
        static let messagingUnavailableMessage = NSLocalizedString("This device isn't configured to send messages.", comment: "Messaging unavailable alert title")
    }

    enum LoginScreen {
        static let myAddress = NSLocalizedString("My Address", comment: "My Address button title")
        static let scan = NSLocalizedString("Scan", comment: "Scan button title")
        static let touchIdText = NSLocalizedString("Login With TouchID", comment: "Login with TouchID accessibility label")
        static let touchIdPrompt = NSLocalizedString("Unlock your Breadwallet", comment: "TouchID prompt text")
        static let header = NSLocalizedString("bread", comment: "Login Screen header")
        static let subheader = NSLocalizedString("Enter Pin", comment: "Login Screen sub-header")
        static let unlocked = NSLocalizedString("Wallet Unlocked", comment: "Wallet unlocked message")
    }

    enum Transaction {
        static let justNow = NSLocalizedString("just now", comment: "Timestamp label for event that just happened")
        static let invalid = NSLocalizedString("INVALID", comment: "Invalid transaction")
        static let complete = NSLocalizedString("Complete", comment: "Transaction complete label")
        static let waiting = NSLocalizedString("Waiting to be confirmed. Some merchants require confirmation to complete a transaction. Estimated time: 1-2 hours.", comment: "Waiting to be confirmed string")
    }

    enum TransactionDetails {
        static let title = NSLocalizedString("Transaction Details", comment: "Transaction Details Title")
        static let statusHeader = NSLocalizedString("Status", comment: "Status section header")
        static let commentsHeader = NSLocalizedString("Comments", comment: "Comment section header")
        static let amountHeader = NSLocalizedString("Amount", comment: "Amount section header")
        static let emptyMessage = NSLocalizedString("Your transactions will appear here.", comment: "Empty transaction list message.")
    }

    enum SecurityCenter {
        static let title = NSLocalizedString("Security Center", comment: "Security Center Title")
        static let info = NSLocalizedString("Breadwallet provides security features for protecting your money. Click each feature below to learn more.", comment: "Security Center Info")
        enum Cells {
            static let pinTitle = NSLocalizedString("6-Digit PIN", comment: "Pin cell title")
            static let pinDescription = NSLocalizedString("Unlocks your Bread, authorizes send money.", comment: "Pin cell description")
            static let touchIdTitle = NSLocalizedString("Touch ID", comment: "Touch ID cell title")
            static let touchIdDescription = NSLocalizedString("Unlocks your Bread, authorizes send money to set limit.", comment: "Touch ID cell description")
            static let paperKeyTitle = NSLocalizedString("Paper Key", comment: "Paper Key cell title")
            static let paperKeyDescription = NSLocalizedString("Restores your Bread on new devices and after software updates.", comment: "Paper Key cell description")
        }
    }

    enum UpdatePin {
        static let updateTitle = NSLocalizedString("Update PIN", comment: "Update Pin title")
        static let createTitle = NSLocalizedString("Set PIN", comment: "Update Pin title")
        static let createTitleConfirm = NSLocalizedString("Re-Enter PIN", comment: "Update Pin title")
        static let createInstruction = NSLocalizedString("Your PIN will be used to unlock your Bread and send money.", comment: "Pin creation info.")
        static let enterCurrent = NSLocalizedString("Enter your current PIN.", comment: "Enter current pin instruction")
        static let enterNew = NSLocalizedString("Enter your new PIN.", comment: "Enter new pin instruction")
        static let reEnterNew = NSLocalizedString("Re-Enter your new PIN", comment: "Re-Enter new pin instruction")
        static let caption = NSLocalizedString("Write down your PIN and store it in a place you can access even if your phone is broken or lost.", comment: "Update pin caption text")
        static let setPinErrorTitle = NSLocalizedString("Set Pin Error", comment: "Update pin failure alert view title")
        static let setPinError = NSLocalizedString("Sorry, could not update pin.", comment: "Update pin failure error message.")
    }

    enum RecoverWallet {
        static let next = NSLocalizedString("Next", comment: "Next button label")
        static let intro = NSLocalizedString("Recover your Breadwallet with your recovery phrase.", comment: "Recover wallet intro")
        static let leftArrow = NSLocalizedString("Left Arrow", comment: "Previous button label")
        static let rightArrow = NSLocalizedString("Right Arrow", comment: "Next button label")
        static let done = NSLocalizedString("Done", comment: "Done buttohn text")
        static let instruction = NSLocalizedString("Enter Recovery Phrase", comment: "Enter recovery phrase instruction")
        static let header = NSLocalizedString("Recover Wallet", comment: "Recover wallet header")
        static let subheader = NSLocalizedString("Enter the recovery phrase associated with the wallet you want to recover.", comment: "Recover wallet sub-header")
        static let invalid = NSLocalizedString("The phrase you entered is invalid. Please double-check each word and try again.", comment: "Invalid phrase message")
    }

    enum ManageWallet {
        static let title = NSLocalizedString("Manage Wallet", comment: "Manage wallet modal title[")
        static let textFieldLabel = NSLocalizedString("Wallet Name", comment: "Change Wallet name textfield label")
        static let description = NSLocalizedString("Your wallet name only appears in your account transaction history and cannot be seen by anyone you pay or receive money from.", comment: "Manage wallet description text")
        static let creationDatePrefix = NSLocalizedString("You created your wallet on", comment: "Wallet creation date prefix")
    }

    enum AccountHeader {
        static let defaultWalletName = NSLocalizedString("My Bread", comment: "Default wallet name")
        static let manageButtonName = NSLocalizedString("MANAGE", comment: "Manage wallet button title")
    }

    enum VerifyPin {
        static let title = NSLocalizedString("PIN Required", comment: "Verify Pin view title")
        static let body = NSLocalizedString("Please enter your PIN to authorize this transaction.", comment: "Verify pin view body")
    }

    enum TouchIdSettings {
        static let title = NSLocalizedString("Touch ID", comment: "Touch ID settings view title")
        static let label = NSLocalizedString("Login to your Bread wallet and send money using just your finger print to a set limit.", comment: "Touch Id screen label")
        static let switchLabel = NSLocalizedString("Enable Touch ID for Bread", comment: "Touch id switch label.")
        static let spendingLimitLabel = NSLocalizedString("Spending Limit: 1btc = $678.93 USD \n You can customize your Touch ID Spending Limit from the Touch ID Spending Limit Screen", comment: "Touch ID spending limit label")
        static let unavailableAlertTitle = NSLocalizedString("Touch ID Not Setup", comment: "Touch ID unavailable alert title")
        static let unavailableAlertMessage = NSLocalizedString("You have not setup Touch ID on this device. Go to Settings->Touch ID & Passcode to set it up now.", comment: "Touch ID unavailable alert message")
    }

    enum TouchIdSpendingLimit {
        static let title = NSLocalizedString("Touch ID Limit", comment: "Touch Id spending limit screen title")
        static let body = NSLocalizedString("You will be asked to enter you 6-Digit PIN for any send transaction over your Spending Limit, and every 48 hours since the last time you entered your 6-Digit PIN.", comment: "Touch ID spending limit screen body")
    }

    enum Settings {
        static let title = NSLocalizedString("Settings", comment: "Settings title")
        static let importTile = NSLocalizedString("Import Wallet", comment: "Import wallet label")
        static let notifications = NSLocalizedString("Notifications", comment: "Notifications label")
        static let touchIdLimit = NSLocalizedString("Touch ID Spending Limit", comment: "Touch ID spending limit label")
        static let currency = NSLocalizedString("Default Currency", comment: "Default currency label")
        static let sync = NSLocalizedString("Sync Blockchain", comment: "Sync blockchain label")
        static let shareData = NSLocalizedString("Share Anonymous Data", comment: "Share anonymous data label")
        static let earlyAccess = NSLocalizedString("Join Early Access", comment: "Join Early access label")
        static let about = NSLocalizedString("About", comment: "About label")
    }

    enum About {
        static let title = NSLocalizedString("About", comment: "About screen title")
        static let blog = NSLocalizedString("Blog", comment: "About screen blog label")
        static let twitter = NSLocalizedString("Twitter", comment: "About screen twitter label")
        static let reddit = NSLocalizedString("Reddit", comment: "About screen reddit label")
        static let terms = NSLocalizedString("Terms of Use", comment: "Terms of Use button label")
        static let privacy = NSLocalizedString("Privacy Policy", comment: "Privay Policy button label")
        static let footer = NSLocalizedString("Made in North America. Version ", comment: "About screen footer")
    }

    enum PushNotifications {
        static let title = NSLocalizedString("Notifications", comment: "Push notifications settings view title label")
        static let body = NSLocalizedString("Get notified when money you’ve received is available for spending.", comment: "Push notifications settings view body")
        static let label = NSLocalizedString("Push Notifications", comment: "Push notifications toggle switch label")
    }

    enum DefaultCurrency {
        static let title = NSLocalizedString("Default Currency", comment: "Default currency view title")
        static let rateLabel = NSLocalizedString("Exchange Rate", comment: "Exchange rate label")
    }

    enum SyncingView {
        static let header = NSLocalizedString("Syncing", comment: "Syncing view header text")
        static let retry = NSLocalizedString("Retry", comment: "Retry button label")
    }

    enum ReScan {
        static let header = NSLocalizedString("Sync Blockchain", comment: "Sync Blockchain view header")
        static let subheader1 = NSLocalizedString("Estimated time\n", comment: "Subheader label")
        static let subheader2 = NSLocalizedString("When to Sync?\n", comment: "Subheader label")
        static let body1 = NSLocalizedString("5-30 minutes\n\n", comment: "extimated time")
        static let body2 = NSLocalizedString("If a transaction is taking much longer than its estimated time to complete.\n\nIf you believe a transaction is missing from your account history.", comment: "Syncing explanation\n")
        static let buttonTitle = NSLocalizedString("Start Sync", comment: "Start Sync button label")
        static let footer = NSLocalizedString("You will not be able to send money while syncing with the blockchain.", comment: "Sync blockchain view footer")
        static let alertTitle = NSLocalizedString("Sync with Blockchain?", comment: "Alert message title")
        static let alertMessage = NSLocalizedString("You will not be able to send money while syncing.", comment: "Alert message body")
        static let alertAction = NSLocalizedString("Sync", comment: "Alert action button label")
    }

    enum ShareData {
        static let header = NSLocalizedString("Share Data?", comment: "Share data header")
        static let body = NSLocalizedString("Help improve Bread by sharing your annoymous data with us. This does not include any financial information. We respect your financial privacy.", comment: "Share data view body")
        static let toggleLabel = NSLocalizedString("Share Anonymous Data?", comment: "Share data switch label.")
    }

    enum ConfirmPaperPhrase {
        static let word = NSLocalizedString("Word", comment: "Word label eg. Word 1, Word 2")
        static let label = NSLocalizedString("Prove you wrote down your paper key by answering the following questions.", comment: "Confirm paper phrase view label.")
    }

    enum StartPaperPhrase {
        static let body = NSLocalizedString("Protect your wallet against theft and ensure you can recover your wallet after replacing your phone or updating its software. ", comment: "Paper key explanation text.")
        static let buttonTitle = NSLocalizedString("Write Down Paper Key", comment: "button label")
        static let againButtonTitle = NSLocalizedString("Write Down Paper Key Again", comment: "button label")
        static let datePrefix = NSLocalizedString("You last wrote down your paper key on", comment: "Date prefix")
    }
}
