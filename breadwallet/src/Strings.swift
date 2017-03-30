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
        static let cameraUnavailableMessage = NSLocalizedString("Allow camera access in Settings->Privacy->Camera->Bread", comment: "Camera not allowed message")
    }

    enum Account {
        static let loadingMessage = NSLocalizedString("Loading Wallet", comment: "Loading Wallet Message")
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
        static let description = NSLocalizedString("Your wallet name only appears in your account transaction history and cannot be seen by anyone you pay or receive money from.\n\nYou created your wallet on", comment: "Manage wallet description text")
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
}
