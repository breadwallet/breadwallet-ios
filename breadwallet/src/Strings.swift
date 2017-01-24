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
    }
}
