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
        static let currencyLabel = NSLocalizedString("USD \u{25BC}", comment: "Currency Button label")

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
        static let title = NSLocalizedString("Update PIN", comment: "Update Pin title")
        static let enterCurrent = NSLocalizedString("Enter your current PIN.", comment: "Enter current pin instruction")
        static let enterNew = NSLocalizedString("Enter your new PIN.", comment: "Enter new pin instruction")
        static let reEnterNew = NSLocalizedString("Re-Enter your new PIN", comment: "Re-Enter new pin instruction")
        static let caption = NSLocalizedString("Write down your PIN and store it in a place you can access even if your phone is broken or lost.", comment: "Update pin caption text")
    }
}
