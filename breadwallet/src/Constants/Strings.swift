//
//  Strings.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-14.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation

enum S {

    enum Symbols {
        static let bits = "ƀ"
        static let eth = "Ξ"
        static let btc = "₿"
        static let narrowSpace = "\u{2009}"
        static let lock = "\u{1F512}"
        static let redX = "\u{274C}"
    }

    enum Button {
        static let ok = NSLocalizedString("Button.ok", value:"OK", comment: "OK button label")
        static let cancel = NSLocalizedString("Button.cancel", value:"Cancel", comment: "Cancel button label")
        static let settings = NSLocalizedString("Button.settings", value:"Settings", comment: "Settings button label")
        static let openSettings = NSLocalizedString("Button.openSettings", value: "Open Settings", comment: "Open settings button label")
        static let submit = NSLocalizedString("Button.submit", value:"Submit", comment: "Settings button label")
        static let ignore = NSLocalizedString("Button.ignore", value:"Ignore", comment: "Ignore button label")
        static let yes = NSLocalizedString("Button.yes", value: "Yes", comment: "Yes button")
        static let no = NSLocalizedString("Button.no", value: "No", comment: "No button")
        static let send = NSLocalizedString("Button.send", value: "Send", comment: "send button")
        static let receive = NSLocalizedString("Button.receive", value: "Receive", comment: "receive button")
        static let buy = NSLocalizedString("Button.buy", value: "Buy", comment: "buy button")
        static let sell = NSLocalizedString("Button.sell", value: "Sell", comment: "sell button")
        static let continueAction = NSLocalizedString("Button.continueAction", value: "Continue", comment: "prompt continue button")
        static let dismiss = NSLocalizedString("Button.dismiss", value: "Dismiss", comment: "prompt dismiss button")
        static let home = NSLocalizedString("Button.home", value: "Home", comment: "prompt home button")
        static let moreInfo = NSLocalizedString("Button.moreInfo", value: "More info", comment: "More information button")
        static let maybeLater = NSLocalizedString("Button.maybeLater", value: "Maybe Later", comment: "Maybe later button")
        static let doneAction = NSLocalizedString("Button.done", value: "Done", comment: "Done button title")
        static let skip = NSLocalizedString("Button.skip", value: "Skip", comment: "Skip button title")
        static let confirm = NSLocalizedString("Button.confirm", value: "Confirm", comment: "Confirm button title")
    }

    enum Alert {
        static let warning = NSLocalizedString("Alert.warning", value: "Warning", comment: "Warning alert title")
        static let error = NSLocalizedString("Alert.error", value: "Error", comment: "Error alert title")
        static let noInternet = NSLocalizedString("Alert.noInternet", value: "No internet connection found. Check your connection and try again.", comment: "No internet alert message")
        static let timedOut = NSLocalizedString("Alert.timedOut", value: "Request timed out. Check your connection and try again.", comment: "Request timed out error message")
        static let somethingWentWrong = NSLocalizedString("Alert.somethingWentWrong", value: "Something went wrong. Please try again.", comment: "General error message with 'Try again'")
    }

    enum Scanner {
        static let flashButtonLabel = NSLocalizedString("Scanner.flashButtonLabel", value:"Camera Flash", comment: "Scan bitcoin address camera flash toggle")
        static let paymentPrompTitle = NSLocalizedString("Scanner.paymentPromptTitle", value:"Send Payment", comment: "alert dialog title")
        static let paymentPromptMessage = NSLocalizedString("Scanner.paymentPromptMessage", value:"Would you like to send a %1$@ payment to this address?", comment: "(alert dialog message) Would you like to send a [Bitcoin / Bitcoin Cash / Ethereum] payment to this address?")
    }

    enum Send {
        static let title = NSLocalizedString("Send.title", value:"Send", comment: "Send modal title")
        static let toLabel = NSLocalizedString("Send.toLabel", value:"To", comment: "Send money to label")
        static let amountLabel = NSLocalizedString("Send.amountLabel", value:"Amount", comment: "Send money amount label")
        static let descriptionLabel = NSLocalizedString("Send.descriptionLabel", value:"Memo", comment: "Description for sending money label")
        static let sendLabel = NSLocalizedString("Send.sendLabel", value:"Send", comment: "Send button label")
        static let pasteLabel = NSLocalizedString("Send.pasteLabel", value:"Paste", comment: "Paste button label")
        static let scanLabel = NSLocalizedString("Send.scanLabel", value:"Scan", comment: "Scan button label")
        static let invalidAddressTitle = NSLocalizedString("Send.invalidAddressTitle", value:"Invalid Address", comment: "Invalid address alert title")
        static let invalidAddressMessage = NSLocalizedString("Send.invalidAddressMessage", value:"The destination address is not a valid %1$@ address.", comment: "Invalid <currency> address alert message")
        static let invalidAddressOnPasteboard = NSLocalizedString("Send.invalidAddressOnPasteboard", value: "Pasteboard does not contain a valid %1$@ address.", comment: "Invalid <currency> address on pasteboard message")
        static let emptyPasteboard = NSLocalizedString("Send.emptyPasteboard", value: "Pasteboard is empty", comment: "Empty pasteboard error message")
        static let cameraUnavailableTitle = NSLocalizedString("Send.cameraUnavailableTitle", value:"Fabriik is not allowed to access the camera", comment: "Camera not allowed alert title")
        static let cameraUnavailableMessage = NSLocalizedString("Send.cameraunavailableMessage", value:"Go to Settings to allow camera access.", comment: "Camera not allowed message")
        static let balanceString = NSLocalizedString("Send.balanceString", value:"Balance: ", comment: "Balance: $4.00")
        static let sendingMax = NSLocalizedString("Send.sendingMax", value:"Sending Max: ", comment: "Sending Max: $4.00")
        static let fee = NSLocalizedString("Send.fee", value:"Network Fee: %1$@", comment: "Network Fee: $0.01")
        static let containsAddress = NSLocalizedString("Send.containsAddress", value: "The destination is your own address. You cannot send to yourself.", comment: "Warning when sending to self.")
        enum UsedAddress {
            static let title = NSLocalizedString("Send.UsedAddress.title", value: "Address Already Used", comment: "Adress already used alert title")
            static let firstLine = NSLocalizedString("Send.UsedAddress.firstLine", value: "Bitcoin addresses are intended for single use only.", comment: "Adress already used alert message - first part")
            static let secondLine = NSLocalizedString("Send.UsedAddress.secondLIne", value: "Re-use reduces privacy for both you and the recipient and can result in loss if the recipient doesn't directly control the address.", comment: "Adress already used alert message - second part")
        }
        static let identityNotCertified = NSLocalizedString("Send.identityNotCertified", value: "Payee identity isn't certified.", comment: "Payee identity not certified alert title.")
        static let createTransactionError = NSLocalizedString("Send.creatTransactionError", value: "Could not create transaction.", comment: "Could not create transaction alert title")
        static let publicTransactionError = NSLocalizedString("Send.publishTransactionError", value: "Could not publish transaction.", comment: "Could not publish transaction alert title")
        static let noAddress = NSLocalizedString("Send.noAddress", value: "Please enter the recipient's address.", comment: "Empty address alert message")
        static let noAmount = NSLocalizedString("Send.noAmount", value: "Please enter an amount to send.", comment: "Emtpy amount alert message")
        //TODO:CRYPTO remove
        static let isRescanning = NSLocalizedString("Send.isRescanning", value: "Sending is disabled during a full rescan.", comment: "Is rescanning error message")
        static let remoteRequestError = NSLocalizedString("Send.remoteRequestError", value: "Could not load payment request", comment: "Could not load remote request error message")
        static let loadingRequest = NSLocalizedString("Send.loadingRequest", value: "Loading Request", comment: "Loading request activity view message")
        static let insufficientFunds = NSLocalizedString("Send.insufficientFunds", value: "Insufficient Funds", comment: "Insufficient funds error")
        static let ethSendSelf = NSLocalizedString("Send.ethSendSelf", value: "Can't send to self.", comment: "Can't send to self erorr message")
        static let noFeesError = NSLocalizedString("Send.noFeesError", value: "Network Fee conditions are being downloaded. Please try again.", comment: "No Fees error")
        static let legacyAddressWarning = NSLocalizedString("Send.legacyAddressWarning", value: "Warning: this is a legacy bitcoin address. Are you sure you want to send Bitcoin Cash to it?", comment: "Attempting to send to ")
        static let insufficientGasTitle = NSLocalizedString("Send.insufficientGasTitle", value: "Insufficient Ethereum Balance", comment: "Insufficient gas alert title")
        static let insufficientGasMessage = NSLocalizedString("Send.insufficientGasMessage", value: "You must have at least %1$@ in your wallet in order to transfer this type of token. Would you like to go to your Ethereum wallet now?", comment: "Insufficient gas alert message")
        static let destinationTagLabel = NSLocalizedString("Send.destinationTag_optional", value: "Destination Tag (Optional)", comment: "Destination Tag Label")
        static let memoTagLabelOptional = NSLocalizedString("Send.memoTag_optional", value: "Hedera Memo (Optional)", comment: "Hedera Memo Tag Label")
        enum Error {
            static let authenticationError = NSLocalizedString("Send.Error.authenticationError", value: "Authentication Error", comment: "Sending error message")
            static let notConnected = NSLocalizedString("Send.Error.notConnected", value: "Network not connected", comment: "Sending error message")
            static let maxError = NSLocalizedString("Send.Error.maxError", value: "Could not calculate maximum", comment: "Error calculating maximum.")
        }
    }

    enum Receive {
        static let title = NSLocalizedString("Receive.title", value:"Receive", comment: "Receive modal title")
        static let emailButton = NSLocalizedString("Receive.emailButton", value:"Email", comment: "Share via email button label")
        static let textButton = NSLocalizedString("Receive.textButton", value:"Text Message", comment: "Share via text message (SMS)")
        static let copied = NSLocalizedString("Receive.copied", value:"Copied to clipboard.", comment: "Address copied message.")
        static let share = NSLocalizedString("Receive.share", value:"Share", comment: "Share button label")
        static let request = NSLocalizedString("Receive.request", value:"Request an Amount", comment: "Request button label")
    }

    enum Account {
        static let balance = NSLocalizedString("Account.balance", value:"Balance", comment: "Account header balance label")
        static let delistedToken = NSLocalizedString("Account.delistedToken", value: "This token has been delisted. \n\nYou may still be able to send these tokens to another platform. For more details, visit our support page.", comment: "Delisted token alert banner message")
    }
    
    enum AccountCreation {
        static let title = NSLocalizedString("AccountCreation.title", value:"Confirm Account Creation", comment: "Confirm Account Creation Title")
        static let body = NSLocalizedString("AccountCreation.body", value:"Only create a Hedera account if you intend on storing HBAR in your wallet.", comment: "Confirm Account Creation mesage body")
        static let notNow = NSLocalizedString("AccountCreation.notNow", value:"Not Now", comment: "Not Now button label.")
        static let create = NSLocalizedString("AccountCreation.create", value:"Create Account", comment: "Create Account button label")
        static let creating = NSLocalizedString("AccountCreation.creating", value:"Creating Account", comment: "Creating Account progress Label")
        static let error = NSLocalizedString("AccountCreation.error", value:"An error occured during account creation. Please try again later.", comment: "Creating Account progress Label")
        static let timeout = NSLocalizedString("AccountCreation.timeout", value:"The Request timed out. Please try again later.", comment: "Creating Account progress Label")
    }

    enum JailbreakWarnings {
        static let title = NSLocalizedString("JailbreakWarnings.title", value:"WARNING", comment: "Jailbreak warning title")
        static let messageWithBalance = NSLocalizedString("JailbreakWarnings.messageWithBalance", value:"DEVICE SECURITY COMPROMISED\n Any 'jailbreak' app can access Fabriik's keychain data and steal your bitcoin! Wipe this wallet immediately and restore on a secure device.", comment: "Jailbreak warning message")
        static let ignore = NSLocalizedString("JailbreakWarnings.ignore", value:"Ignore", comment: "Ignore jailbreak warning button")
        static let wipe = NSLocalizedString("JailbreakWarnings.wipe", value:"Wipe", comment: "Wipe wallet button")
        static let close = NSLocalizedString("JailbreakWarnings.close", value:"Close", comment: "Close app button")
    }

    enum ErrorMessages {
        static let emailUnavailableTitle = NSLocalizedString("ErrorMessages.emailUnavailableTitle", value:"Email Unavailable", comment: "Email unavailable alert title")
        static let emailUnavailableMessage = NSLocalizedString("ErrorMessages.emailUnavailableMessage", value:"This device isn't configured to send email with the iOS mail app.", comment: "Email unavailable alert title")
        static let messagingUnavailableTitle = NSLocalizedString("ErrorMessages.messagingUnavailableTitle", value:"Messaging Unavailable", comment: "Messaging unavailable alert title")
        static let messagingUnavailableMessage = NSLocalizedString("ErrorMessages.messagingUnavailableMessage", value:"This device isn't configured to send messages.", comment: "Messaging unavailable alert title")
        static let noLogsFound = NSLocalizedString("Settings.noLogsFound", value: "No Log files found. Please try again later.", comment: "No log files found error message")
    }

    enum UnlockScreen {
        static let myAddress = NSLocalizedString("UnlockScreen.myAddress", value:"My Address", comment: "My Address button title")
        static let scan = NSLocalizedString("UnlockScreen.scan", value:"Scan", comment: "Scan button title")
        static let touchIdText = NSLocalizedString("UnlockScreen.touchIdText", value:"Unlock with TouchID", comment: "Unlock with TouchID accessibility label")
        static let touchIdPrompt = NSLocalizedString("UnlockScreen.touchIdPrompt", value:"Unlock your Fabriik.", comment: "TouchID/FaceID prompt text")
        static let disabled = NSLocalizedString("UnlockScreen.disabled", value:"Disabled until: %1$@", comment: "Disabled until date")
        static let resetPin = NSLocalizedString("UnlockScreen.resetPin", value:"Reset PIN", comment: "Reset PIN with Paper Key button label.")
        static let faceIdText = NSLocalizedString("UnlockScreen.faceIdText", value:"Unlock with FaceID", comment: "Unlock with FaceID accessibility label")
        static let wipePrompt = NSLocalizedString("UnlockScreen.wipePrompt", value:"Are you sure you would like to wipe this wallet?", comment: "Wipe wallet prompt")
    }

    enum Transaction {
        static let justNow = NSLocalizedString("Transaction.justNow", value:"just now", comment: "Timestamp label for event that just happened")
        static let invalid = NSLocalizedString("Transaction.invalid", value:"Failed", comment: "Invalid transaction")
        static let complete = NSLocalizedString("Transaction.complete", value:"Complete", comment: "Transaction complete label")
        static let waiting = NSLocalizedString("Transaction.waiting", value:"Waiting to be confirmed. Some merchants require confirmation to complete a transaction. Estimated time: 1-2 hours.", comment: "Waiting to be confirmed string")
        static let pending = NSLocalizedString("Transaction.pending", value: "Pending", comment: "Transaction is pending status text")
        static let confirming = NSLocalizedString("Transaction.confirming", value: "In Progress", comment: "Transaction is confirming status text")
        static let failed = NSLocalizedString("Transaction.failed", value: "failed", comment: "Transaction failed status text")
        static let sentTo = NSLocalizedString("Transaction.sentTo", value:"sent to %1$@", comment: "sent to <address>")
        static let receivedVia = NSLocalizedString("TransactionDetails.receivedVia", value:"received via %1$@", comment: "received via <address>")
        static let receivedFrom = NSLocalizedString("TransactionDetails.receivedFrom", value:"received from %1$@", comment: "received from <address>")
        static let sendingTo = NSLocalizedString("Transaction.sendingTo", value:"sending to %1$@", comment: "sending to <address>")
        static let receivingVia = NSLocalizedString("TransactionDetails.receivingVia", value:"receiving via %1$@", comment: "receiving via <address>")
        static let receivingFrom = NSLocalizedString("TransactionDetails.receivingFrom", value:"receiving from %1$@", comment: "receiving from <address>")
        static let tokenTransfer = NSLocalizedString("Transaction.tokenTransfer", value:"Fee for token transfer: %1$@", comment: "Fee for token transfer: Fabriik")
    }

    enum TransactionDetails {
        static let titleSent = NSLocalizedString("TransactionDetails.titleSent", value:"Sent", comment: "Transaction Details Title - Sent")
        static let titleSending = NSLocalizedString("TransactionDetails.titleSending", value:"Sending", comment: "Transaction Details Title - Sending")
        static let titleReceived = NSLocalizedString("TransactionDetails.titleReceived", value:"Received", comment: "Transaction Details Title - Received")
        static let titleReceiving = NSLocalizedString("TransactionDetails.titleReceiving", value:"Receiving", comment: "Transaction Details Title - Receiving")
        static let titleInternal = NSLocalizedString("TransactionDetails.titleInternal", value:"Internal", comment: "Transaction Details Title - Internal")
        static let titleFailed = NSLocalizedString("TransactionDetails.titleFailed", value:"Failed", comment: "Transaction Details Title - Failed")
        
        static let showDetails = NSLocalizedString("TransactionDetails.showDetails", value:"Show Details", comment: "Show Details button")
        static let hideDetails = NSLocalizedString("TransactionDetails.hideDetails", value:"Hide Details", comment: "Hide Details button")
        
        static let statusHeader = NSLocalizedString("TransactionDetails.statusHeader", value:"Status", comment: "Status section header")
        static let commentsHeader = NSLocalizedString("TransactionDetails.commentsHeader", value:"Memo", comment: "Memo section header")
        static let commentsPlaceholder = NSLocalizedString("TransactionDetails.commentsPlaceholder", value:"Add memo...", comment: "Memo field placeholder")
        static let amountHeader = NSLocalizedString("TransactionDetails.amountHeader", value:"Amount", comment: "Amount section header")
        static let txHashHeader = NSLocalizedString("TransactionDetails.txHashHeader", value:"Transaction ID", comment: "Transaction ID header")
        
        static let exchangeRateHeader = NSLocalizedString("TransactionDetails.exchangeRateHeader", value:"Exchange Rate", comment: "Exchange rate section header")
        
        static let amountWhenReceived = NSLocalizedString("TransactionDetails.amountWhenReceived", value: "%1$@ when received %2$@ now", comment: "$100 when received $200 now")
        static let amountWhenSent = NSLocalizedString("TransactionDetails.amountWhenSent", value: "%1$@ when sent %2$@ now", comment: "$100 when sent $200 now")
        
        static let emptyMessage = NSLocalizedString("TransactionDetails.emptyMessage", value:"Your transactions will appear here.", comment: "Empty transaction list message.")
        static let sent = NSLocalizedString("TransactionDetails.sent", value:"Sent %1$@", comment: "Sent $5.00 (sent title 1/2)")
        static let received = NSLocalizedString("TransactionDetails.received", value:"Received %1$@", comment: "Received $5.00 (received title 1/2)")
        static let moved = NSLocalizedString("TransactionDetails.moved", value:"Moved %1$@", comment: "Moved $5.00")
        static let blockHeightLabel = NSLocalizedString("TransactionDetails.blockHeightLabel", value: "Confirmed in Block", comment: "Block height label")
        static let confirmationsLabel = NSLocalizedString("TransactionDetails.confirmationsLabel", value: "Confirmations", comment: "Confirmations label")
        static let notConfirmedBlockHeightLabel = NSLocalizedString("TransactionDetails.notConfirmedBlockHeightLabel", value: "Not Confirmed", comment: "eg. Confirmed in Block: Not Confirmed")
        
        static let initializedTimestampHeader = NSLocalizedString("TransactionDetails.initializedTimestampHeader", value:"Initialized", comment: "Timestamp section header for incomplete tx")
        static let completeTimestampHeader = NSLocalizedString("TransactionDetails.completeTimestampHeader", value:"Complete", comment: "Timestamp section header for complete tx")
        static let addressToHeader = NSLocalizedString("TransactionDetails.addressToHeader", value:"To", comment: "Address sent to header")
        static let addressViaHeader = NSLocalizedString("TransactionDetails.addressViaHeader", value:"Via", comment: "Address received at header")
        static let addressFromHeader = NSLocalizedString("TransactionDetails.addressFromHeader", value:"From", comment: "Address received from header")
        
        static let totalHeader = NSLocalizedString("TransactionDetails.totalHeader", value:"Total", comment: "Tx detail field header")
        static let feeHeader = NSLocalizedString("TransactionDetails.feeHeader", value:"Total Fee", comment: "Tx detail field header")
        static let gasPriceHeader = NSLocalizedString("TransactionDetails.gasPriceHeader", value:"Gas Price", comment: "Tx detail field header")
        static let gasLimitHeader = NSLocalizedString("TransactionDetails.gasLimitHeader", value:"Gas Limit", comment: "Tx detail field header")
        static let destinationTagHeader = NSLocalizedString("TransactionDetails.destinationTagHeader", value:"Destination Tag", comment: "Destination Tag Header")
        static let memoTagHeader = NSLocalizedString("TransactionDetails.memoTagHeader", value:"Hedera Memo", comment: "Hedera Memo Tag Header")
    }

    enum SecurityCenter {
        enum Cells {
            static let pinTitle = NSLocalizedString("SecurityCenter.pinTitle", value:"6-Digit PIN", comment: "PIN button title")
            static let pinDescription = NSLocalizedString("SecurityCenter.pinDescription", value:"Protects your Fabriik from unauthorized users.", comment: "PIN button description")
            static let touchIdTitle = NSLocalizedString("SecurityCenter.touchIdTitle", value:"Touch ID", comment: "Touch ID button title")
            static let touchIdDescription = NSLocalizedString("SecurityCenter.touchIdDescription", value:"Conveniently unlock your Fabriik and send money up to a set limit.", comment: "Touch ID/FaceID button description")
            static let paperKeyTitle = NSLocalizedString("SecurityCenter.paperKeyTitle", value:"Recovery Phrase", comment: "Recovery Phrase button title")
            static let paperKeyDescription = NSLocalizedString("SecurityCenter.paperKeyDescription", value:"The only way to access your bitcoin if you lose or upgrade your phone.", comment: "Paper Key button description")
            static let faceIdTitle = NSLocalizedString("SecurityCenter.faceIdTitle", value:"Face ID", comment: "Face ID button title")
        }
    }

    enum UpdatePin {
        static let updateTitle = NSLocalizedString("UpdatePin.updateTitle", value:"Update PIN", comment: "Update PIN title")
        static let createTitle = NSLocalizedString("UpdatePin.createTitle", value:"Set PIN", comment: "Update PIN title")
        static let createTitleConfirm = NSLocalizedString("UpdatePin.createTitleConfirm", value:"Re-Enter PIN", comment: "Update PIN title")
        static let createInstruction = NSLocalizedString("UpdatePin.createInstruction", value:"Your PIN will be used to unlock your Fabriik and send money.", comment: "PIN creation info.")
        static let enterCurrent = NSLocalizedString("UpdatePin.enterCurrent", value:"Enter your current PIN.", comment: "Enter current PIN instruction")
        static let enterNew = NSLocalizedString("UpdatePin.enterNew", value:"Enter your new PIN.", comment: "Enter new PIN instruction")
        static let reEnterNew = NSLocalizedString("UpdatePin.reEnterNew", value:"Re-Enter your new PIN.", comment: "Re-Enter new PIN instruction")
        static let caption = NSLocalizedString("UpdatePin.caption", value:"Remember this PIN. If you forget it, you won't be able to access your bitcoin.", comment: "Update PIN caption text")
        static let setPinErrorTitle = NSLocalizedString("UpdatePin.setPinErrorTitle", value:"Update PIN Error", comment: "Update PIN failure alert view title")
        static let setPinError = NSLocalizedString("UpdatePin.setPinError", value:"Sorry, could not update PIN.", comment: "Update PIN failure error message.")
    }

    enum RecoverWallet {
        static let next = NSLocalizedString("RecoverWallet.next", value:"Next", comment: "Next button label")
        static let intro = NSLocalizedString("RecoverWallet.intro", value:"Recover your Fabriik with your paper key.", comment: "Recover wallet intro")
        static let leftArrow = NSLocalizedString("RecoverWallet.leftArrow", value:"Left Arrow", comment: "Previous button accessibility label")
        static let rightArrow = NSLocalizedString("RecoverWallet.rightArrow", value:"Right Arrow", comment: "Next button accessibility label")
        static let done = NSLocalizedString("RecoverWallet.done", value:"Done", comment: "Done button text")
        static let instruction = NSLocalizedString("RecoverWallet.instruction", value:"Enter Paper Key", comment: "Enter paper key instruction")
        static let header = NSLocalizedString("RecoverWallet.header", value:"Recover Wallet", comment: "Recover wallet header")
        static let subheader = NSLocalizedString("RecoverWallet.subheader", value:"Enter the paper key for the wallet you want to recover.", comment: "Recover wallet sub-header")

        static let headerResetPin = NSLocalizedString("RecoverWallet.header_reset_pin", value:"Reset PIN", comment: "Reset PIN with paper key: header")
        static let subheaderResetPin = NSLocalizedString("RecoverWallet.subheader_reset_pin", value:"To reset your PIN, enter the words from your paper key into the boxes below.", comment: "Reset PIN with paper key: sub-header")
        static let resetPinInfo = NSLocalizedString("RecoverWallet.reset_pin_more_info", value:"Tap here for more information.", comment: "Reset PIN with paper key: more information button.")
        static let invalid = NSLocalizedString("RecoverWallet.invalid", value:"The paper key you entered is invalid. Please double-check each word and try again.", comment: "Invalid paper key message")
    }

    enum ManageWallet {
        static let title = NSLocalizedString("ManageWallet.title", value:"Manage Wallet", comment: "Manage wallet modal title")
        static let textFieldLabel = NSLocalizedString("ManageWallet.textFeildLabel", value:"Wallet Name", comment: "Change Wallet name textfield label")
        static let description = NSLocalizedString("ManageWallet.description", value:"Your wallet name only appears in your account transaction history and cannot be seen by anyone else.", comment: "Manage wallet description text")
        static let creationDatePrefix = NSLocalizedString("ManageWallet.creationDatePrefix", value:"You created your wallet on %1$@", comment: "Wallet creation date prefix")
    }

    enum AccountHeader {
        static let defaultWalletName = NSLocalizedString("AccountHeader.defaultWalletName", value:"My Fabriik", comment: "Default wallet name")
        static let equals = NSLocalizedString("AccountHeader.equals", value:"=", comment: "Equals symbol")
        static let exchangeRate = NSLocalizedString("Account.exchangeRate", value:"%1$@ per %2$@", comment: "$10000 per BTC")
    }

    enum VerifyPin {
        static let title = NSLocalizedString("VerifyPin.title", value:"PIN Required", comment: "Verify PIN view title")
        static let continueBody = NSLocalizedString("VerifyPin.continueBody", value:"Please enter your PIN to continue.", comment: "Verify PIN view body")
        static let authorize = NSLocalizedString("VerifyPin.authorize", value: "Please enter your PIN to authorize this transaction.", comment: "Verify PIN for transaction view body")
        static let touchIdMessage = NSLocalizedString("VerifyPin.touchIdMessage", value: "Authorize this transaction", comment: "Authorize transaction with touch id message")
    }

    enum TouchIdSettings {
        static let title = NSLocalizedString("TouchIdSettings.title", value:"Touch ID", comment: "Touch ID settings view title")
        static let explanatoryText = NSLocalizedString("TouchIdSettings.explanatoryText", value: "Use Touch ID to unlock your Fabriik app and send money.", comment: "Explanation for Touch ID settings")
        static let switchLabel = NSLocalizedString("TouchIdSettings.switchLabel", value:"Enable Touch ID for Fabriik", comment: "Touch id switch label.")
        static let unavailableAlertTitle = NSLocalizedString("TouchIdSettings.unavailableAlertTitle", value:"Touch ID Not Set Up", comment: "Touch ID unavailable alert title")
        static let transactionsTitleText = NSLocalizedString("TouchIdSettings.transactionsTitleText", value: "Enable Touch ID to send money", comment: "Title for Touch ID transactions toggle")
        static let unavailableAlertMessage = NSLocalizedString("TouchIdSettings.unavailableAlertMessage", value:"You have not set up Touch ID on this device. Go to Settings->Touch ID & Passcode to set it up now.", comment: "Touch ID unavailable alert message")
        static let unlockTitleText = NSLocalizedString("TouchIdSettings.unlockTitleText", value: "Enable Touch ID to unlock Fabriik", comment: "Touch ID unlock toggle title")
    }
    
    enum FaceIDSettings {
        static let title = NSLocalizedString("FaceIDSettings.title", value:"Face ID", comment: "Face ID settings view title")
        static let explanatoryText = NSLocalizedString("FaceIDSettings.explanatoryText", value: "Use Face ID to unlock your Fabriik app and send money.", comment: "Explanation for Face ID settings")
        static let switchLabel = NSLocalizedString("FaceIDSettings.switchLabel", value:"Enable Face ID for Fabriik", comment: "Face id switch label.")
        static let unavailableAlertTitle = NSLocalizedString("FaceIDSettings.unavailableAlertTitle", value:"Face ID Not Set Up", comment: "Face ID unavailable alert title")
        static let transactionsTitleText = NSLocalizedString("FaceIDSettings.transactionsTitleText", value: "Enable Face ID to send money", comment: "Title for Face ID transactions toggle")
        static let unavailableAlertMessage = NSLocalizedString("FaceIDSettings.unavailableAlertMessage", value:"You have not set up Face ID on this device. Go to Settings->Face ID & Passcode to set it up now.", comment: "Face ID unavailable alert message")
        static let unlockTitleText = NSLocalizedString("FaceIDSettings.unlockTitleText", value: "Enable Face ID to unlock Fabriik", comment: "Face ID unlock toggle title")
    }
    
    enum Settings {
        static let title = NSLocalizedString("Settings.title", value:"Menu", comment: "Settings title")
        static let wallet = NSLocalizedString("Settings.wallet", value: "Wallets", comment: "Wallet Settings section header")
        static let preferences = NSLocalizedString("Settings.preferences", value: "Preferences", comment: "Preferences settings section header")
        static let currencySettings = NSLocalizedString("Settings.currencySettings", value: "Currency Settings", comment: "Currency settings section header")
        static let other = NSLocalizedString("Settings.other", value: "Other", comment: "Other settings section header")
        static let advanced = NSLocalizedString("Settings.advanced", value: "Advanced", comment: "Advanced settings header")
        static let currencyPageTitle = NSLocalizedString("Settings.currencyPageTitle", value: "%1$@ Settings", comment: "Bitcoin Settings page title")
        static let importTile = NSLocalizedString("Settings.importTitle", value:"Redeem Private Key", comment: "Import wallet label")
        static let notifications = NSLocalizedString("Settings.notifications", value:"Notifications", comment: "Notifications label")
        static let currency = NSLocalizedString("Settings.currency", value:"Display Currency", comment: "Default currency label")
        static let sync = NSLocalizedString("Settings.sync", value:"Sync Blockchain", comment: "Sync blockchain label")
        static let shareData = NSLocalizedString("Settings.shareData", value:"Share Anonymous Data", comment: "Share anonymous data label")
        static let earlyAccess = NSLocalizedString("Settings.earlyAccess", value:"Join Early Access", comment: "Join Early access label")
        static let about = NSLocalizedString("Settings.about", value:"About", comment: "About label")
        static let review = NSLocalizedString("Settings.review", value: "Leave us a Review", comment: "Leave review button label")
        static let rewards = NSLocalizedString("Settings.rewards", value: "Rewards", comment: "Rewards menu item text")
        static let enjoying = NSLocalizedString("Settings.enjoying", value: "Are you enjoying Fabriik?", comment: "Are you enjoying Fabriik alert message body")
        static let wipe = NSLocalizedString("Settings.wipe", value: "Unlink from this device", comment: "Unlink wallet menu label.")
        static let advancedTitle = NSLocalizedString("Settings.advancedTitle", value: "Advanced Settings", comment: "Advanced Settings title")
        static let sendLogs = NSLocalizedString("Settings.sendLogs", value: "Send Logs", comment: "Send Logs option")
        static let resetCurrencies = NSLocalizedString("Settings.resetCurrencies", value: "Reset to Default Currencies", comment: "Reset currencies button")
        static let viewLegacyAddress = NSLocalizedString("Settings.ViewLegacyAddress", value: "View Legacy Receive Address", comment: "")
        static let enableSegwit = NSLocalizedString("Settings.EnableSegwit", value: "Enable Segwit", comment: "")
        static let atmMapMenuItemTitle = NSLocalizedString("Settings.atmMapMenuItemTitle", value: "Crypto ATM Map", comment: "ATM map menu item title")
        static let atmMapMenuItemSubtitle = NSLocalizedString("Settings.atmMapMenuItemSubtitle", value: "Available in the USA only", comment: "ATM map menu item title explaining that it's a feature only available in the USA")
    }

    enum About {
        static let title = NSLocalizedString("About.title", value:"About", comment: "About screen title")
        static let blog = NSLocalizedString("About.blog", value:"Blog", comment: "About screen blog label")
        static let twitter = NSLocalizedString("About.twitter", value:"Twitter", comment: "About screen twitter label")
        static let reddit = NSLocalizedString("About.reddit", value:"Reddit", comment: "About screen reddit label")
        static let privacy = NSLocalizedString("About.privacy", value:"Privacy Policy", comment: "Privay Policy button label")
        static let walletID = NSLocalizedString("About.walletID", value:"Fabriik Rewards ID", comment: "About screen wallet ID label")
        static let footer = NSLocalizedString("About.footer", value:"Made by the global Fabriik team. Version %1$@ Build %2$@", comment: "About screen footer")
        static let telephone = NSLocalizedString("About.telephone", value:"Telephone", comment: "About screen telephone label")
        static let email = NSLocalizedString("About.email", value:"Email", comment: "About screen email label")
    }

    enum PushNotifications {
        static let title = NSLocalizedString("PushNotifications.title", value:"Stay in the Loop", comment: "Push notifications settings view title label")
        static let body = NSLocalizedString("PushNotifications.body", value:"Turn on push notifications and be the first to hear about new features and special offers.", comment: "Push notifications settings view body")
        static let enabledBody = NSLocalizedString("PushNotifications.enabledBody", value:"You’re receiving special offers and updates from Fabriik.", comment: "Push notifications settings view body when the toggle is enabled.")
        static let disabledBody = NSLocalizedString("PushNotifications.disabledBody", value:"Turn on notifications to receive special offers and updates from Fabriik.", comment: "Push notifications settings view body when the toggle is disabled.")
        static let enableInstructions = NSLocalizedString("PushNotifications.enableInstructions", value: "Looks like notifications are turned off. Please go to Settings to enable notifications from Fabriik.", comment: "Instructions for enabling push notifications in Settings")
        static let maybeLater = NSLocalizedString("PushNotifications.maybeLater", value: "Maybe Later", comment: "Button title for the 'Maybe Later' option")
        static let label = NSLocalizedString("PushNotifications.label", value:"Receive Push Notifications", comment: "Push notifications toggle switch label")
        static let on = NSLocalizedString("PushNotifications.on", value: "On", comment: "Push notifications are on label")
        static let off = NSLocalizedString("PushNotifications.off", value: "Off", comment: "Push notifications are off label")
        static let disabled = NSLocalizedString("PushNotifications.disabled", value: "Notifications Disabled", comment: "Push notifications are disabled alert title")
    }

    enum DefaultCurrency {
        static let rateLabel = NSLocalizedString("DefaultCurrency.rateLabel", value:"Exchange Rate", comment: "Exchange rate label")
        static let bitcoinLabel = NSLocalizedString("DefaultCurrency.bitcoinLabel", value: "Bitcoin Display Unit", comment: "Bitcoin denomination picker label")
    }

    enum SyncingView {
        static let syncing = NSLocalizedString("SyncingView.syncing", value:"Syncing", comment: "Syncing view syncing state header text")
        static let connecting = NSLocalizedString("SyncingView.connecting", value:"Connecting", comment: "Syncing view connectiong state header text")
        static let syncedThrough = NSLocalizedString("SyncingView.syncedThrough", value: "Synced through %1$@", comment: "eg. Synced through <Jan 12, 2015>")
        static let failed = NSLocalizedString("SyncingView.failed", value: "Sync Failed", comment: "Sync failed label")
        static let activity = NSLocalizedString("SyncingView.activity", value: "Activity", comment: "Activity label")
    }

    enum ReScan {
        static let header = NSLocalizedString("ReScan.header", value:"Sync Blockchain", comment: "Sync Blockchain view header")
        static let subheader1 = NSLocalizedString("ReScan.subheader1", value:"Estimated time", comment: "Subheader label")
        static let subheader2 = NSLocalizedString("ReScan.subheader2", value:"When to Sync?", comment: "Subheader label")
        static let body1 = NSLocalizedString("ReScan.body1", value:"20-45 minutes", comment: "extimated time")
        static let body2 = NSLocalizedString("ReScan.body2", value:"If a transaction shows as completed on the network but not in your Fabriik.", comment: "Syncing explanation")
        static let body3 = NSLocalizedString("ReScan.body3", value:"You repeatedly get an error saying your transaction was rejected.", comment: "Syncing explanation")
        static let buttonTitle = NSLocalizedString("ReScan.buttonTitle", value:"Start Sync", comment: "Start Sync button label")
        static let footer = NSLocalizedString("ReScan.footer", value:"You will not be able to send money while syncing with the blockchain.", comment: "Sync blockchain view footer")
        static let alertTitle = NSLocalizedString("ReScan.alertTitle", value:"Sync with Blockchain?", comment: "Alert message title")
        static let alertMessage = NSLocalizedString("ReScan.alertMessage", value:"You will not be able to send money while syncing.", comment: "Alert message body")
        static let alertAction = NSLocalizedString("ReScan.alertAction", value:"Sync", comment: "Alert action button label")
    }

    enum ShareData {
        static let header = NSLocalizedString("ShareData.header", value:"Share Data?", comment: "Share data header")
        static let body = NSLocalizedString("ShareData.body", value:"Help improve Fabriik by sharing your anonymous data with us. This does not include any financial information. We respect your financial privacy.", comment: "Share data view body")
        static let toggleLabel = NSLocalizedString("ShareData.toggleLabel", value:"Share Anonymous Data?", comment: "Share data switch label.")
    }

    enum WalletConnectionSettings {
        static let menuTitle = NSLocalizedString("WalletConnectionSettings.menuTitle", value:"Connection Mode", comment: "Wallet connection settings menu item title.")
        static let viewTitle = NSLocalizedString("WalletConnectionSettings.viewTitle", value:"Fastsync", comment: "Wallet connection settings view title")
        static let header = NSLocalizedString("WalletConnectionSettings.header", value:"Fastsync (pilot)", comment: "Wallet connection settings view title")
        static let explanatoryText = NSLocalizedString("WalletConnectionSettings.explanatoryText", value: "Make syncing your bitcoin wallet practically instant. Learn more about how it works here.", comment: "Explanation for wallet connection setting")
        static let link = NSLocalizedString("WalletConnectionSettings.link", value: "here", comment: "Link text in explanatoryText")
        static let footerTitle = NSLocalizedString("WalletConnectionSettings.footerTitle", value:"Powered by", comment: "Connection mode switch label.")
        static let confirmation = NSLocalizedString("WalletConnectionSettings.confirmation", value:"Are you sure you want to turn off Fast Sync?", comment: "Turn off fast sync confirmation question")
        static let turnOff = NSLocalizedString("WalletConnectionSettings.turnOff", value:"Turn Off", comment: "Turn off fast sync button label")
    }

    enum ConfirmPaperPhrase {
        static let word = NSLocalizedString("ConfirmPaperPhrase.word", value:"Word #%1$@", comment: "Word label eg. Word #1, Word #2")
        static let label = NSLocalizedString("ConfirmPaperPhrase.label", value:"To make sure everything was written down correctly, please enter the following words from your paper key.", comment: "Confirm paper phrase view label.")
        static let error = NSLocalizedString("ConfirmPaperPhrase.error", value: "The words entered do not match your paper key. Please try again.", comment: "Confirm paper phrase error message")
    }

    enum StartPaperPhrase {
        static let date = NSLocalizedString("StartPaperPhrase.date", value:"Last written down on\n %1$@", comment: "Argument is date")
    }

    enum RequestAnAmount {
        static let title = NSLocalizedString("RequestAnAmount.title", value:"Request an Amount", comment: "Request a specific amount of bitcoin")
        static let noAmount = NSLocalizedString("RequestAnAmount.noAmount", value: "Please enter an amount first.", comment: "No amount entered error message.")
    }

    enum Alerts {
        static let pinSet = NSLocalizedString("Alerts.pinSet", value:"PIN Set", comment: "Alert Header label (the PIN was set)")
        static let paperKeySet = NSLocalizedString("Alerts.paperKeySet", value:"Paper Key Set", comment: "Alert Header Label (the paper key was set)")
        static let sendSuccess = NSLocalizedString("Alerts.sendSuccess", value:"Send Confirmation", comment: "Send success alert header label (confirmation that the send happened)")
        static let sendFailure = NSLocalizedString("Alerts.sendFailure", value:"Send failed", comment: "Send failure alert header label (the send failed to happen)")
        static let paperKeySetSubheader = NSLocalizedString("Alerts.paperKeySetSubheader", value:"Awesome!", comment: "Alert Subheader label (playfully positive)")
        static let sendSuccessSubheader = NSLocalizedString("Alerts.sendSuccessSubheader", value:"Money Sent!", comment: "Send success alert subheader label (e.g. the money was sent)")
        static let copiedAddressesHeader = NSLocalizedString("Alerts.copiedAddressesHeader", value:"Addresses Copied", comment: "'the addresses were copied'' Alert title")
        static let copiedAddressesSubheader = NSLocalizedString("Alerts.copiedAddressesSubheader", value:"All wallet addresses successfully copied.", comment: "Addresses Copied Alert sub header")
    }

    enum MenuButton {
        static let security = NSLocalizedString("MenuButton.security", value:"Security Settings", comment: "Menu button title")
        static let support = NSLocalizedString("MenuButton.support", value:"Support", comment: "Menu button title")
        static let settings = NSLocalizedString("MenuButton.settings", value:"Settings", comment: "Menu button title")
        static let lock = NSLocalizedString("MenuButton.lock", value:"Lock Wallet", comment: "Menu button title")
        static let addWallet = NSLocalizedString("MenuButton.addWallet", value: "Add Wallet", comment: "Menu button title")
        static let manageWallets = NSLocalizedString("MenuButton.manageWallets", value: "Manage Wallets", comment: "Menu button title")
        static let scan = NSLocalizedString("MenuButton.scan", value: "Scan QR Code", comment: "Menu button title")
    }
    
    enum HomeScreen {
        static let totalAssets = NSLocalizedString("HomeScreen.totalAssets", value: "Total Assets", comment: "header")
        static let portfolio = NSLocalizedString("HomeScreen.portfolio", value: "Wallets", comment: "Section header")
        static let admin = NSLocalizedString("HomeScreen.admin", value: "Admin", comment: "Section header")
        static let buy = NSLocalizedString("HomeScreen.buy", value: "Buy", comment: "home screen toolbar button")
        static let buyAndSell = NSLocalizedString("HomeScreen.buyAndSell", value: "Buy & Sell", comment: "home screen Buy & Sell button")
        static let trade = NSLocalizedString("HomeScreen.trade", value: "Trade", comment: "home screen toolbar button")
        static let menu = NSLocalizedString("Button.menu", value: "Menu", comment: "home screen toolbar button")
    }

    enum OnboardingScreen {
        static let browseFirst = NSLocalizedString("Onboarding.browseFirst", value: "Setup Wallet", comment: "Button that allows the user to browse the app after completing onboarding")
        static let buyCoin = NSLocalizedString("Onboarding.buyCoin", value: "Buy some coin", comment: "Button that allows the user to go directly to buying cryptocurrency after completing onboarding.")
        static let getStarted = NSLocalizedString("Onboarding.getStarted", value: "Get started", comment: "Button that launches the onboarding flow to create a new crypto wallet")
        static let next = NSLocalizedString("Onboarding.next", value: "Next", comment: "Button that navigates to the next page in the onboarding flow.")
        static let restoreWallet = NSLocalizedString("Onboarding.restoreWallet", value: "Restore wallet", comment: "Button that allows the user to restore an existing crypto wallet")
        static let skip = NSLocalizedString("Onboarding.skip", value: "Skip", comment: "Button that allows the user to skip to the end of the onboarding flow.")
        static let pageOneTitle = NSLocalizedString("OnboardingPageOne.title", value: "Welcome to your ATM enabled virtual currency wallet.!", comment: "Title displayed on the first page of the onboarding flow.")
        static let pageTwoTitle = NSLocalizedString("OnboardingPageTwo.title", value: "Join millions of people around the world who trust Fabriik.", comment: "Title displayed on the second page of the onboarding flow.")
        static let pageTwoSubtitle = NSLocalizedString("OnboardingPageTwo.subtitle", value: "Join the 1.5 million people around the world who trust Fabriik.", comment: "Subtitle displayed on the second page of the onboarding flow.")
        static let pageThreeTitle = NSLocalizedString("OnboardingPageThree.title", value: "Buy and trade bitcoin, tokens, and other digital currencies.", comment: "Title displayed on the third page of the onboarding flow.")
        static let pageThreeSubtitle = NSLocalizedString("OnboardingPageThree.subtitle", value: "Invest and diversify with Fabriik, easily and securely.", comment: "Subtitle displayed on the third page of the onboarding flow.")
    }
    
    enum AccessibilityLabels {
        static let close = NSLocalizedString("AccessibilityLabels.close", value:"Close", comment: "Close modal button accessibility label")
        static let faq = NSLocalizedString("AccessibilityLabels.faq", value: "Support Center", comment: "Support center accessibiliy label")
    }

    enum Watch {
        static let noWalletWarning = NSLocalizedString("Watch.noWalletWarning", value: "Open the Fabriik iPhone app to set up your wallet.", comment: "'No wallet' warning for watch app")
    }

    enum Search {
        static let sent = NSLocalizedString("Search.sent", value: "sent", comment: "Sent filter label")
        static let received = NSLocalizedString("Search.received", value: "received", comment: "Received filter label")
        static let pending = NSLocalizedString("Search.pending", value: "pending", comment: "Pending filter label")
        static let complete = NSLocalizedString("Search.complete", value: "complete", comment: "Complete filter label")
        static let search = NSLocalizedString("Search.search", value: "Search", comment: "Search bar placeholder text")
    }

    enum Prompts {
        enum TouchId {
            static let title = NSLocalizedString("Prompts.TouchId.title", value: "Enable Touch ID", comment: "Enable touch ID prompt title")
            static let body = NSLocalizedString("Prompts.TouchId.body", value: "Tap Continue to enable Touch ID", comment: "Enable touch ID prompt body")
        }
        enum PaperKey {
            static let title = NSLocalizedString("Prompts.PaperKey.title", value: "Action Required", comment: "An action is required (You must do this action).")
            static let body = NSLocalizedString("Prompts.PaperKey.body", value: "Your recovery phrase must be saved in case you lose or change your phone.", comment: "Warning about recovery phrase.")
        }
        enum UpgradePin {
            static let title = NSLocalizedString("Prompts.UpgradePin.title", value: "Upgrade PIN", comment: "Upgrade PIN prompt title.")
            static let body = NSLocalizedString("Prompts.UpgradePin.body", value: "Fabriik has upgraded to using a 6-digit PIN. Tap Continue to upgrade.", comment: "Upgrade PIN prompt body.")
        }
        enum NoPasscode {
            static let title = NSLocalizedString("Prompts.NoPasscode.title", value: "Turn device passcode on", comment: "No Passcode set warning title")
            static let body = NSLocalizedString("Prompts.NoPasscode.body", value: "A device passcode is needed to safeguard your wallet. Go to settings and turn passcode on.", comment: "No passcode set warning body")
        }
        enum FaceId {
            static let title = NSLocalizedString("Prompts.FaceId.title", value: "Enable Face ID", comment: "Enable face ID prompt title")
            static let body = NSLocalizedString("Prompts.FaceId.body", value: "Tap Continue to enable Face ID", comment: "Enable face ID prompt body")
        }
        enum Email {
            static let title = NSLocalizedString("Prompts.Email.title", value: "Get in the loop", comment: "Get user email address prompt title")
            static let body = NSLocalizedString("Prompts.Email.body", 
                                                value: "Be the first to receive important support and product updates",
                                                comment: "Get user email address prompt body")
            static let emailPlaceholder = NSLocalizedString("Prompts.Email.placeholder", value: "enter your email", comment: "user email input placeholder")
            static let successTitle = NSLocalizedString("Prompts.Email.successTitle", 
                                                        value: "Thank you!", 
                                                        comment: "Get user email address prompt title upon success")
            static let successBody = NSLocalizedString("Prompts.Email.successBody", 
                                                        value: "You have successfully subscribed to receive updates", 
                                                        comment: "body text show after the user successfully submits an email address for updates")
            static let successFootnote = NSLocalizedString("Prompts.Email.successFootnote", 
                                                           value: "We appreciate your continued support", 
                                                           comment: "shown after the user successfully submits an email address for updates")
        }
    }

    enum PaymentProtocol {
        enum Errors {
            static let untrustedCertificate = NSLocalizedString("PaymentProtocol.Errors.untrustedCertificate", value: "untrusted certificate", comment: "Untrusted certificate payment protocol error message")
            static let missingCertificate = NSLocalizedString("PaymentProtocol.Errors.missingCertificate", value: "missing certificate", comment: "Missing certificate payment protocol error message")
            static let unsupportedSignatureType = NSLocalizedString("PaymentProtocol.Errors.unsupportedSignatureType", value: "unsupported signature type", comment: "Unsupported signature type payment protocol error message")
            static let requestExpired = NSLocalizedString("PaymentProtocol.Errors.requestExpired", value: "request expired", comment: "Request expired payment protocol error message")
            static let badPaymentRequest = NSLocalizedString("PaymentProtocol.Errors.badPaymentRequest", value: "Bad Payment Request", comment: "Bad Payment request alert title")
            static let smallOutputErrorTitle = NSLocalizedString("PaymentProtocol.Errors.smallOutputError", value: "Couldn't make payment", comment: "Payment too small alert title")
            static let smallPayment = NSLocalizedString("PaymentProtocol.Errors.smallPayment", value: "Payment can’t be less than %1$@. Transaction fees are more than the amount of this transaction. Please increase the amount and try again.", comment: "Amount too small error message")
            static let smallTransaction = NSLocalizedString("PaymentProtocol.Errors.smallTransaction", value: "Bitcoin transaction outputs can't be less than %1$@.", comment: "Output too small error message.")
            static let corruptedDocument = NSLocalizedString("PaymentProtocol.Errors.corruptedDocument", value: "Unsupported or corrupted document", comment: "Error opening payment protocol file message")
        }
    }

    enum URLHandling {
        static let copy = NSLocalizedString("URLHandling.copy", value: "Copy", comment: "Copy wallet addresses alert button label")
    }

    enum ApiClient {
        static let notReady = NSLocalizedString("ApiClient.notReady", value: "Wallet not ready", comment: "Wallet not ready error message")
        static let jsonError = NSLocalizedString("ApiClient.jsonError", value: "JSON Serialization Error", comment: "JSON Serialization error message")
        static let tokenError = NSLocalizedString("ApiClient.tokenError", value: "Unable to retrieve API token", comment: "API Token error message")
    }

    enum CameraPlugin {
        static let centerInstruction = NSLocalizedString("CameraPlugin.centerInstruction", value: "Center your ID in the box", comment: "Camera plugin instruction")
    }

    enum LocationPlugin {
        static let disabled = NSLocalizedString("LocationPlugin.disabled", value: "Location services are disabled.", comment: "Location services disabled error")
        static let notAuthorized = NSLocalizedString("LocationPlugin.notAuthorized", value: "Fabriik does not have permission to access location services.", comment: "No permissions for location services")
    }

    enum Webview {
        static let updating = NSLocalizedString("Webview.updating", value: "Updating...", comment: "Updating webview message")
        static let errorMessage = NSLocalizedString("Webview.errorMessage", value: "There was an error loading the content. Please try again.", comment: "Webview loading error message")
        static let dismiss = NSLocalizedString("Webview.dismiss", value: "Dismiss", comment: "Dismiss button label")

    }

    enum TimeSince {
        static let seconds = NSLocalizedString("TimeSince.seconds", value: "%1$@ s", comment: "6 s (6 seconds)")
        static let minutes = NSLocalizedString("TimeSince.minutes", value: "%1$@ m", comment: "6 m (6 minutes)")
        static let hours = NSLocalizedString("TimeSince.hours", value: "%1$@ h", comment: "6 h (6 hours)")
        static let days = NSLocalizedString("TimeSince.days", value:"%1$@ d", comment: "6 d (6 days)")
    }

    enum Import {
        static let leftCaption = NSLocalizedString("Import.leftCaption", value: "Wallet to be imported", comment: "Caption for graphics")
        static let rightCaption = NSLocalizedString("Import.rightCaption", value: "Your Fabriik Wallet", comment: "Caption for graphics")
        static let importMessage = NSLocalizedString("Import.message", value: "Importing a wallet transfers all the money from your other wallet into your Fabriik wallet using a single transaction.", comment: "Import wallet intro screen message")
        static let importWarning = NSLocalizedString("Import.warning", value: "Importing a wallet does not include transaction history or other details.", comment: "Import wallet intro warning message")
        static let scan = NSLocalizedString("Import.scan", value: "Scan Private Key", comment: "Scan Private key button label")
        static let title = NSLocalizedString("Import.title", value: "Import Wallet", comment: "Import Wallet screen title")
        static let importing = NSLocalizedString("Import.importing", value: "Importing Wallet", comment: "Importing wallet progress view label")
        static let confirm = NSLocalizedString("Import.confirm", value: "Send %1$@ from this private key into your wallet? The bitcoin network will receive a fee of %2$@.", comment: "Sweep private key confirmation message")
        static let checking = NSLocalizedString("Import.checking", value: "Checking private key balance...", comment: "Checking private key balance progress view text")
        static let password = NSLocalizedString("Import.password", value: "This private key is password protected.", comment: "Enter password alert view title")
        static let passwordPlaceholder = NSLocalizedString("Import.passwordPlaceholder", value: "password", comment: "password textfield placeholder")
        static let unlockingActivity = NSLocalizedString("Import.unlockingActivity", value: "Unlocking Key", comment: "Unlocking Private key activity view message.")
        static let importButton = NSLocalizedString("Import.importButton", value: "Import", comment: "Import button label")
        static let success = NSLocalizedString("Import.success", value: "Success", comment: "Import wallet success alert title")
        static let successBody = NSLocalizedString("Import.SuccessBody", value: "Successfully imported wallet.", comment: "Successfully imported wallet message body")
        static let wrongPassword = NSLocalizedString("Import.wrongPassword", value: "Wrong password, please try again.", comment: "Wrong password alert message")
        enum Error {
            static let notValid = NSLocalizedString("Import.Error.notValid", value: "Not a valid private key", comment: "Not a valid private key error message")
            static let duplicate = NSLocalizedString("Import.Error.duplicate", value: "This private key is already in your wallet.", comment: "Duplicate key error message")
            static let empty = NSLocalizedString("Import.Error.empty", value: "This private key is empty.", comment: "empty private key error message")
            static let failedSubmit = NSLocalizedString("Import.Error.failedSubmit", value: "Failed to submit transaction.", comment: "Failed to submit transaction error message")
            static let unsupportedCurrency = NSLocalizedString("Import.Error.unsupportedCurrency", value: "Unsupported Currency", comment: "Unsupported currencye error message")
            static let sweepError = NSLocalizedString("Import.Error.sweepError", value: "Unable to sweep wallet", comment: "Unable to sweep wallet error message")
            static let serviceError = NSLocalizedString("Import.Error.serviceError", value: "Service Error", comment: "Service error error message")
            static let serviceUnavailable = NSLocalizedString("Import.Error.serviceUnavailable", value: "Service Unavailable", comment: "Service Unavailable error message")
        }
    }

    enum BitID {
        static let title = NSLocalizedString("BitID.title", value: "BitID Authentication Request", comment: "BitID Authentication Request alert view title")
        static let authenticationRequest = NSLocalizedString("BitID.authenticationRequest", value: "%1$@ is requesting authentication using your bitcoin wallet", comment: "<sitename> is requesting authentication using your bitcoin wallet")
        static let deny = NSLocalizedString("BitID.deny", value: "Deny", comment: "Deny button label")
        static let approve = NSLocalizedString("BitID.approve", value: "Approve", comment: "Approve button label")
        static let success = NSLocalizedString("BitID.success", value: "Successfully Authenticated", comment: "BitID success alert title")
        static let error = NSLocalizedString("BitID.error", value: "Authentication Error", comment: "BitID error alert title")
        static let errorMessage = NSLocalizedString("BitID.errorMessage", value: "Please check with the service. You may need to try again.", comment: "BitID error alert messaage")
        
    }

    enum WipeWallet {
        static let title = NSLocalizedString("WipeWallet.title", value: "Unlink from this device", comment: "Wipe wallet navigation item title.")
        static let alertTitle = NSLocalizedString("WipeWallet.alertTitle", value: "Wipe Wallet?", comment: "Wipe wallet alert title")
        static let alertMessage = NSLocalizedString("WipeWallet.alertMessage", value: "Are you sure you want to delete this wallet?", comment: "Wipe wallet alert message")
        static let wipe = NSLocalizedString("WipeWallet.wipe", value: "Wipe", comment: "Wipe wallet button title")
        static let wiping = NSLocalizedString("WipeWallet.wiping", value: "Wiping...", comment: "Wiping activity message")
        static let failedTitle = NSLocalizedString("WipeWallet.failedTitle", value: "Failed", comment: "Failed wipe wallet alert title")
        static let failedMessage = NSLocalizedString("WipeWallet.failedMessage", value: "Failed to wipe wallet.", comment: "Failed wipe wallet alert message")
        static let instruction = NSLocalizedString("WipeWallet.instruction", value: "To start a new wallet or restore an existing wallet, you must first erase the wallet that is currently installed. To continue, enter the current wallet's Paper Key.", comment: "Enter key to wipe wallet instruction.")
        static let startMessage = NSLocalizedString("WipeWallet.startMessage", value: "Starting or recovering another wallet allows you to access and manage a different Fabriik wallet on this device.", comment: "Start wipe wallet view message")
        static let startWarning = NSLocalizedString("WipeWallet.startWarning", value: "Your current wallet will be removed from this device. If you wish to restore it in the future, you will need to enter your Paper Key.", comment: "Start wipe wallet view warning")
    }

    enum FeeSelector {
        static let title = NSLocalizedString("FeeSelector.title", value: "Processing Speed", comment: "Fee Selector title")
        static let estimatedDelivery = NSLocalizedString("FeeSelector.estimatedDeliver", value: "Estimated Delivery: %1$@", comment: "Fee Selector regular fee description")
        static let economyWarning = NSLocalizedString("FeeSelector.economyWarning", value: "This option is not recommended for time-sensitive transactions.", comment: "Warning message for economy fee")
        static let regular = NSLocalizedString("FeeSelector.regular", value: "Regular", comment: "Regular fee")
        static let economy = NSLocalizedString("FeeSelector.economy", value: "Economy", comment: "Economy fee")
        static let priority = NSLocalizedString("FeeSelector.priority", value: "Priority", comment: "Priority fee")
        static let economyTime = NSLocalizedString("FeeSelector.economyTime", value: "1-24 hours", comment: "E.g. [This transaction is predicted to complete in] 1-24 hours")
        static let regularTime = NSLocalizedString("FeeSelector.regularTime", value: "10-60 minutes", comment: "E.g. [This transaction is predicted to complete in] 10-60 minutes")
        static let priorityTime = NSLocalizedString("FeeSelector.priorityTime", value: "10-30 minutes", comment: "E.g. [This transaction is predicted to complete in] 10-30 minutes")
        static let ethTime = NSLocalizedString("FeeSelector.ethTime", value: "2-5 minutes", comment: "E.g. [This transaction is predicted to complete in] 2-5 minutes")
        static let lessThanMinutes = NSLocalizedString("FeeSelector.lessThanMinutes", value: "&lt;%1$d minutes", comment: "")
    }

    enum Confirmation {
        static let title = NSLocalizedString("Confirmation.title", value: "Confirmation", comment: "Confirmation Screen title")
        static let send = NSLocalizedString("Confirmation.send", value: "Send", comment: "Send: (amount)")
        static let to = NSLocalizedString("Confirmation.to", value: "To", comment: "To: (address)")
        static let processingTime = NSLocalizedString("Confirmation.processingTime", value: "Processing time: This transaction is predicted to complete in %1$@.", comment: "E.g. Processing time: This transaction is predicted to complete in [10-60 minutes].")
        static let amountLabel = NSLocalizedString("Confirmation.amountLabel", value: "Amount to Send:", comment: "Amount to Send: ($1.00)")
        static let feeLabel = NSLocalizedString("Confirmation.feeLabel", value: "Network Fee:", comment: "Network Fee: ($1.00)")
        static let feeLabelETH = NSLocalizedString("Confirmation.feeLabelETH", value: "Network Fee (ETH):", comment: "Network Fee (ETH). 'ETH' should not be translated")
        static let totalLabel = NSLocalizedString("Confirmation.totalLabel", value: "Total Cost:", comment: "Total Cost: ($5.00)")
    }

    enum NodeSelector {
        static let manualButton = NSLocalizedString("NodeSelector.manualButton", value: "Switch to Manual Mode", comment: "Switch to manual mode button label")
        static let automaticButton = NSLocalizedString("NodeSelector.automaticButton", value: "Switch to Automatic Mode", comment: "Switch to automatic mode button label")
        static let automaticLabel = NSLocalizedString("NodeSelector.automaticLabel", value: "Automatic", comment: "Automatic mode label")
        static let title = NSLocalizedString("NodeSelector.title", value: "Bitcoin Nodes", comment: "Node Selector view title")
        static let nodeLabel = NSLocalizedString("NodeSelector.nodeLabel", value: "Current Primary Node", comment: "Node address label")
        static let statusLabel = NSLocalizedString("NodeSelector.statusLabel", value: "Node Connection Status", comment: "Node status label")
        static let connected = NSLocalizedString("NodeSelector.connected", value: "Connected", comment: "Node is connected label")
        static let notConnected = NSLocalizedString("NodeSelector.notConnected", value: "Not Connected", comment: "Node is not connected label")
        static let connecting = NSLocalizedString("NodeSelector.connecting", value: "Connecting", comment: "Node is connecting label")
        static let enterTitle = NSLocalizedString("NodeSelector.enterTitle", value: "Enter Node", comment: "Enter Node ip address view title")
        static let enterBody = NSLocalizedString("NodeSelector.enterBody", value: "Enter Node IP address and port (optional)", comment: "Enter node ip address view body")
    }

    enum Welcome {
        static let title = NSLocalizedString("Welcome.title", value: "Fabriik now supports Ethereum!", comment: "Welcome view title")
        static let body = NSLocalizedString("Welcome.body", value: "Any ETH in your wallet can be accessed through the home screen.", comment: "Welcome view body text")
    }

    enum TokenList {
        static let addTitle = NSLocalizedString("TokenList.addTitle", value: "Add Wallets", comment: "Add Wallet view title")
        static let add = NSLocalizedString("TokenList.add", value: "Add", comment: "Add currency button label")
        static let show = NSLocalizedString("TokenList.show", value: "Show", comment: "Show currency button label")
        static let remove = NSLocalizedString("TokenList.remove", value: "Remove", comment: "Remove currency button label")
        static let hide = NSLocalizedString("TokenList.hide", value: "Hide", comment: "Hide currency button label")
        static let manageTitle = NSLocalizedString("TokenList.manageTitle", value: "Manage Wallets", comment: "Manage Wallets view title")
    }

    enum LinkWallet {
        static let approve = NSLocalizedString("LinkWallet.approve", value: "Approve", comment: "Approve link wallet button label")
        static let decline = NSLocalizedString("LinkWallet.decline", value: "Decline", comment: "Decline link wallet button label")
        static let title = NSLocalizedString("LinkWallet.title", value: "Link Wallet", comment: "Link Wallet view title")
        static let domainTitle = NSLocalizedString("LinkWallet.domainTitle", value: "Note: ONLY interact with this app when on one of the following domains", comment: "Link Wallet view title above domain list")
        static let permissionsTitle = NSLocalizedString("LinkWallet.permissionsTitle", value: "This app will be able to:", comment: "Link Wallet view title above permissions list")
        static let disclaimer = NSLocalizedString("LinkWallet.disclaimer", value: "External apps cannot send money without approval from this device", comment: "Link Wallet view dislaimer footer")
        static let logoFooter = NSLocalizedString("LinkWallet.logoFooter", value: "Secure Checkout", comment: "Link wallet logo footer text")
    }

    enum PaymentConfirmation {
        static let title = NSLocalizedString("PaymentConfirmation.title", value: "Confirmation", comment: "Payment confirmation view title")
        static let amountText = NSLocalizedString("PaymentConfirmation.amountText", value: "Send %1$@ to purchase %2$@", comment: "Eg. Send 1.0Eth to purchase CCC")
    }
    
    enum EME {
        enum permissions {
            static let accountRequest = NSLocalizedString("EME.permissions.accountRequest", value: "Request %1$@ account information", comment: "Service capabilities description")
            static let paymentRequest = NSLocalizedString("EME.permissions.paymentRequest", value: "Request %1$@ payment", comment: "Service capabilities description")
            static let callRequest = NSLocalizedString("EME.permissions.callRequest", value: "Request %1$@ smart contract call", comment: "Service capabilities description")
        }
    }

    enum Segwit {
        static let confirmChoiceLayout = NSLocalizedString("Segwit.ConfirmChoiceLayout", value: "Enabling SegWit is an irreversible feature. Are you sure you want to continue?", comment: "")
        static let confirmationConfirmationTitle = NSLocalizedString("Segwit.ConfirmationConfirmationTitle", value: "You have enabled SegWit!", comment: "")
        static let confirmationInstructionsDescription = NSLocalizedString("Segwit.ConfirmationInstructionsDescription", value: "Thank you for helping move bitcoin forward.", comment: "")
        static let confirmationInstructionsInstructions = NSLocalizedString("Segwit.ConfirmationInstructionsInstructions" , value: "SegWit support is still a beta feature.\n\nOnce SegWit is enabled, it will not be possible to disable it. You will be able to find the legacy address under Settings. \n\nSome third-party services, including crypto trading, may be unavailable to users who have enabled SegWit. In case of emergency, you will be able to generate a legacy address from Preferences > Bitcoin Settings. \n\nSegWit will automatically be enabled for all users in a future update.", comment: "")
        static let homeButton = NSLocalizedString("Segwit.HomeButton", value: "To the Moon", comment: "")
        static let enable = NSLocalizedString("Segwit.Enable", value: "Enable", comment: "")
    }

    enum RewardsView {
        static let normalTitle = NSLocalizedString("RewardsView.normalTitle", value: "Rewards", comment: "Rewards view normal title")
        static let expandedTitle = NSLocalizedString("RewardsView.expandedTitle", value: "Introducing Fabriik\nRewards.", comment: "Rewards view expanded title")
        static let expandedBody = NSLocalizedString("RewardsView.expandedBody", value: "Learn how you can save on trading fees and unlock future rewards", comment: "Rewards view expanded body")
    }
    
    enum RecoverKeyFlow {
        static let generateKey = NSLocalizedString("RecoveryKeyFlow.generateKeyTitle",
                                                   value: "Generate your private recovery phrase",
                                                   comment: "Default title for the recovery phrase landing page.")
        
        static let writeKeyAgain = NSLocalizedString("RecoveryKeyFlow.writeKeyAgain",
                                                   value: "Write down your recovery phrase again",
                                                   comment: "Title for the recovery phrase landing page if the key has already been generated.")
        
        static let generateKeyExplanation = NSLocalizedString("RecoveryKeyFlow.generateKeyExplanation",
                                                     value: "This key is required to recover your money if you upgrade or lose your phone.",
                                                     comment: "Subtext for the recovery phrase landing page.")

        static let howItWorksStepLabel = NSLocalizedString("RecoveryKeyFlow.howItWorksStep",
                                                           value: "How it works - Step %1$@",
                                                           comment: "Hint text for recovery phrase intro page, e.g., Step 2")

        static let writeItDown = NSLocalizedString("RecoveryKeyFlow.writeItDown",
                                                           value: "Write down your key",
                                                           comment: "Title for recovery phrase intro page")

        static let keepSecure = NSLocalizedString("RecoveryKeyFlow.keepSecure",
                                                    value: "Keep it secure",
                                                    comment: "Title for recovery phrase intro page")

        static let relaxBuyTrade = NSLocalizedString("RecoveryKeyFlow.relaxBuyTrade",
                                                     value: "Relax, buy, and trade",
                                                     comment: "Title for recovery phrase intro page")
        
        static let noScreenshotsRecommendation = NSLocalizedString("RecoveryKeyFlow.noScreenshotsRecommendation",
                                                                   value: "Write down your key on paper & confirm it. Screenshots are not recommended for security reasons.",
                                                                   comment: "Recommends that the user avoids capturing the paper key with a screenshot")
        
        static let storeSecurelyRecommendation = NSLocalizedString("RecoveryKeyFlow.storeSecurelyRecommendation",
                                                                   value: "Store your key in a secure location. This is the only way to recover your wallet. Fabriik does not keep a copy.",
                                                                   comment: "Recommends that the user stores the recovery phrase in a secure location")
        
        static let securityAssurance = NSLocalizedString("RecoveryKeyFlow.securityAssurance",
                                                         value: "Buy and trade knowing that your funds are protected by the best security and privacy in the business.",
                                                         comment: "Assures the user that Fabriik will keep the user's funds secure.")
        
        static let generateKeyButton = NSLocalizedString("RecoveryKeyFlow.generateKeyButton",
                                                         value: "Generate Recovery Phrase",
                                                         comment: "Button text for the 'Generate Recovery Phrase' button")
        
        static let keyUseInfoHint = NSLocalizedString("RecoveryKeyFlow.keyUseHint",
                                                      value: "Your key is only needed for recovery, not for everyday wallet access.",
                                                      comment: "Informs the user that the recovery is only required for recovering a wallet.")
        
        static let writeKeyScreenTitle = NSLocalizedString("RecoveryKeyFlow.writeKeyScreenTitle",
                                                           value: "Your Recovery Phrase",
                                                           comment: "Title for the write recovery phrase screen")
        
        static let writeKeyScreenSubtitle = NSLocalizedString("RecoveryKeyFlow.writeKeyScreenSubtitle",
                                                              value: "Write down the following words in order.",
                                                              comment: "Subtitle for the write recovery phrase screen")

        static let writeKeyStepTitle = NSLocalizedString("RecoveryKeyFlow.writeKeyStepTitle",
                                                         value: "%1$@ of %2$@",
                                                         comment: "Title for the write recovery phrase screen")
        
        static let noScreenshotsOrEmailReminder = NSLocalizedString("RecoveryKeyFlow.noScreenshotsOrEmailWarning",
                                                                    value: "For security purposes, do not screenshot or email these words",
                                                                    comment: "Reminds the user not to take screenshots or email the recovery phrase words")

        static let rememberToWriteDownReminder = NSLocalizedString("RecoveryKeyFlow.rememberToWriteDownReminder",
                                                                   value: "Remember to write these words down. Swipe back if you forgot.",
                                                                   comment: "Reminds the user to write down the recovery phrase words.")
        
        static let confirmRecoveryKeyTitle = NSLocalizedString("RecoveryKeyFlow.confirmRecoveryKeyTitle",
                                                               value: "Confirm Recovery Phrase",
                                                               comment: "Title for the confirmation step of the recovery phrase flow.")
        
        static let confirmRecoveryKeySubtitle = NSLocalizedString("RecoveryKeyFlow.confirmRecoveryKeySubtitle",
                                                               value: "Almost done! Enter the following words from your recovery phrase.",
                                                               comment: "Instructs the user to enter words from the set of recovery phrase words.")
        static let confirmRecoveryInputError = NSLocalizedString("RecoveryKeyFlow.confirmRecoveryInputError",
                                                                  value: "The word you entered is incorrect. Please try again.",
                                                                  comment: "Instructs the user to enter words from the set of recovery phrase words.")
        
        static let goToWalletButtonTitle = NSLocalizedString("RecoveryKeyFlow.goToWalletButtonTitle",
                                                             value: "Go to Wallet",
                                                             comment: "Title for a button that takes the user to the wallet after setting up the recovery phrase.")
        
        static let successHeading = NSLocalizedString("RecoveryKeyFlow.successHeading",
                                                             value: "Congratulations! You completed your recovery phrase setup.",
                                                             comment: "Title for the success page after the recovery phrase has been set up.")

        static let successSubheading = NSLocalizedString("RecoveryKeyFlow.successSubheading",
                                                         value: "You're all set to deposit, trade, and buy crypto from your Fabriik wallet.",
                                                         comment: "Subtitle for the success page after the recovery phrase has been set up.")
        
        static let invalidPhrase = NSLocalizedString("RecoveryKeyFlow.invalidPhrase",
                                                     value: "Some of the words you entered do not match your recovery phrase. Please try again.",
                                                     comment: "Error text displayed when the user enters an incorrect recovery phrase.")
        
        static let unlinkWallet = NSLocalizedString("RecoveryKeyFlow.unlinkWallet",
                                                     value: "Unlink your wallet from this device.",
                                                     comment: "Title displayed to the user on the intro screen when unlinking a wallet.")
        
        static let unlinkWalletSubtitle = NSLocalizedString("RecoveryKeyFlow.unlinkWalletSubtext",
                                                            value: "Start a new wallet by unlinking your device from the currently installed wallet.",
                                                            comment: "Subtitle displayed to the user on the intro screen when unlinking a wallet.")

        static let recoverYourWallet = NSLocalizedString("RecoveryKeyFlow.recoveryYourWallet",
                                                            value: "Recover Your Wallet",
                                                            comment: "Title displayed when the user starts the process of recovering a wallet.")

        static let recoverYourWalletSubtitle = NSLocalizedString("RecoveryKeyFlow.recoveryYourWalletSubtitle",
                                                                 value: "Please enter the recovery phrase of the wallet you want to recover.",
                                                                 comment: "Subtitle displayed when the user starts the process of recovering a wallet.")

        static let enterRecoveryKey = NSLocalizedString("RecoveryKeyFlow.enterRecoveryKey",
                                                         value: "Enter Recovery Phrase",
                                                         comment: "Title displayed when the user starts the process of entering a recovery phrase.")

        static let enterRecoveryKeySubtitle = NSLocalizedString("RecoveryKeyFlow.enterRecoveryKeySubtitle",
                                                        value: "Please enter your recovery phrase to unlink this wallet from your device.",
                                                        comment: "Subtitle displayed when the user starts the process of entering a recovery phrase.")
        
        static let unlinkWalletWarning = NSLocalizedString("RecoveryKeyFlow.unlinkWalletWarning",
                                                           value: "Wallet must be recovered to regain access.",
                                                           comment: "Warning displayed when the user starts the process of unlinking a wallet.")

        static let resetPINInstruction = NSLocalizedString("RecoveryKeyFlow.resetPINInstruction",
                                                           value: "Please enter your recovery phrase to reset your PIN.",
                                                           comment: "Instruction displayed when the user is resetting the PIN, which requires the recovery phrase to be entered.")
        
        static let exitRecoveryKeyPromptTitle = NSLocalizedString("RecoveryKeyFlow.exitRecoveryKeyPromptTitle",
                                                                  value: "Set Up Later",
                                                                  comment: "Title for an alert dialog asking the user whether to set up the recovery phrase later.")

        static let exitRecoveryKeyPromptBody = NSLocalizedString("RecoveryKeyFlow.exitRecoveryKeyPromptBody",
                                                                  value: "Are you sure you want to set up your recovery phrase later?",
                                                                  comment: "Body text for an alert dialog asking the user whether to set up the recovery phrase later.")
    }
    
    enum PayId {
        static let invalidPayID = NSLocalizedString("Send.payId_invalid",
                                                    value: "Invalid PayId",
                                                    comment: "Error message for invalid PayID")
        static let noAddress = NSLocalizedString("Send.payId_noAddress",
                                                 value: "There is no %1$s address associated with this PayID.",
                                                 comment: "Error message for no address associated with a PayID for a given currency")
        static let retrievalError = NSLocalizedString("Send.payId_retrievalError",
                                                value: "There was an error retrieving the address for this PayID. Please try again later.",
                                                comment: "Error message for error in retrieving the address from the PayID endpoint")
    }
    
    enum FIO {
        static let invalid = NSLocalizedString("Send.fio_invalid",
                                               value: "Invalid FIO address.",
                                               comment: "")
        static let noAddress = NSLocalizedString("Send.fio_noAddress",
                                               value: "There is no %1$s address associated with this FIO address.",
                                               comment: "")
        static let retrievalError = NSLocalizedString("Send.fio_retrievalError",
                                               value: "There was an error retrieving the address for this FIO address. Please try again later.",
                                               comment: "")
    }
    
    enum CloudBackup {
        static let mainBody = NSLocalizedString("CloudBackup.mainBody",
                                                value:"Please note, iCloud backup is only as secure as your iCloud account. We still recommend writing down your recovery phrase in the following step and keeping it secure. The recovery phrase is the only way to recover your wallet if you can no longer access iCloud.",
                                                comment: "")
        static let mainTitle = NSLocalizedString("CloudBackup.mainTitle",
                                                 value: "iCloud Recovery Backup", comment: "")
        static let mainWarning = NSLocalizedString("CloudBackup.mainWarning",
                                                   value: "iCloud Keychain must be turned on in the iOS Settings app for this feature to work", comment: "")
        static let mainToggleTitle = NSLocalizedString("CloudBackup.mainTitle",
                                                   value: "Enable iCloud Recovery Backup", comment: "")
        static let mainWarningConfirmation = NSLocalizedString("CloudBackup.mainWarningConfirmation",
                                                               value: "Are you sure you want to disable iCloud Backup? This will delete your backup from all devices.",
                                                               comment: "")
        static let selectTitle = NSLocalizedString("CloudBackup.selectTitle",
                                                   value: "Choose Backup",
                                                   comment: "")
        static let enableTitle = NSLocalizedString("CloudBackup.enableTitle",
                                                   value: "Enable Keychain",
                                                   comment: "")
        static let enableButton = NSLocalizedString("CloudBackup.enableButton",
                                                   value: "I have turned on iCloud Keychain",
                                                   comment: "")
        static let enableBody1 = NSLocalizedString("CloudBackup.enableBody1",
                                                   value: "iCloud Keychain must be turned on for this feature to work.", comment: "")
        static let enableBody2 = NSLocalizedString("CloudBackup.enableBody2",
                                                   value: "It should look like the following:", comment: "")
        static let step1 = NSLocalizedString("CloudBackup.step1",
                                                   value: "Launch the Settings app.", comment: "")
        static let step2 = NSLocalizedString("CloudBackup.step2",
                                                   value: "Tap your Apple ID name.", comment: "")
        static let step3 = NSLocalizedString("CloudBackup.step3",
                                                   value: "Tap iCloud.", comment: "")
        static let step4 = NSLocalizedString("CloudBackup.step4",
                                                   value: "Verify that iCloud Keychain is ON", comment: "")
        static let understandText = NSLocalizedString("CloudBackup.understandText",
                                                   value: "I understand that this feature will not work unless iCloud Keychain is enabled.", comment: "")
        
        static let recoverHeader = NSLocalizedString("CloudBackup.recoverHeader",
                                                     value: "Enter PIN to unlock iCloud backup", comment: "")
        
        static let pinAttempts = NSLocalizedString("CloudBackup.pinAttempts",
                                                   value: "Attempts remaining before erasing backup: %1$@", comment: "")
        static let warningBody = NSLocalizedString("CloudBackup.warningBody",
                                                   value: "Your iCloud backup will be erased after %1$@ more incorrect PIN attempts.", comment: "")
        static let backupDeleted = NSLocalizedString("CloudBackup.backupDeleted",
                                                     value: "Backup Erased", comment: "")
        static let backupDeletedMessage = NSLocalizedString("CloudBackup.backupDeletedMessage",
                                                            value: "Your iCloud backup has been erased after too many failed PIN attempts. The app will now restart.", comment: "")
        static let encryptBackupMessage = NSLocalizedString("CloudBackup.encryptBackupMessage", value: "Enter pin to encrypt backup", comment: "")
        static let createWarning = NSLocalizedString("CloudBackup.createWarning", value: "A previously backed up wallet has been detected. Using this backup is recommended. Are you sure you want to proceeed with creating a new wallet?", comment: "")
        static let createButton = NSLocalizedString("CloudBackup.createButton", value: "Create new wallet", comment: "")
        static let recoverButton = NSLocalizedString("CloudBackup.recoverButton", value: "Restore from Recovery Phrase", comment: "")
        static let recoverWarning = NSLocalizedString("CloudBackup.createWarning", value: "A previously backed up wallet has been detected. Using this backup is recommended. Are you sure you want to proceeed with restoring from a recovery phrase?", comment: "")
        static let restoreButton = NSLocalizedString("CloudBackup.restoreButton", value: "Restore from iCloud Backup", comment: "")
        static let backupMenuTitle = NSLocalizedString("CloudBackup.backupMenuTitle", value: "iCloud Backup", comment: "")
    }
    
    enum MarketData {
        static let high24h = NSLocalizedString("MarketData.high24h", value: "24h high", comment: "")
        static let low24h = NSLocalizedString("MarketData.low24h", value: "24h low", comment: "")
        static let marketCap = NSLocalizedString("MarketData.marketCap", value: "Market Cap", comment: "")
        static let volume = NSLocalizedString("MarketData.volume", value: "Trading Volume", comment: "")
    }
    
    enum Staking {
        static let stakingTitle = NSLocalizedString("Staking.stakingTitle", value: "Staking", comment: "")
    }
    
    enum JustCash {
        // Menu Screen
        static let findAtmButton = NSLocalizedString("JustCash.findAtm_button", value: "Find an ATM", comment: "Menu Screen find ATM button")
        static let transactionsTitle = NSLocalizedString("JustCash.transactions_title", value: "Transactions", comment: "Menu Screen transactions title")
        static let atmCashRedemptionTitle = NSLocalizedString("JustCash.atmCashRedemption_title", value:"ATM Cash Redemption", comment: "Menu Screen title")
        
        // Map
        static let mapTitle = NSLocalizedString("JustCash.map_title", value: "ATM Cash Locations Map", comment: "ATM MapView title")
        static let searchPlaceholder = NSLocalizedString("JustCash.search_placeholder", value:"Search Atm Locations", comment: "Map Search placeholder")
        static let toggleListButton = NSLocalizedString("JustCash.list_toggle_button", value:"List", comment: "Map List button")
        static let toggleMapButton = NSLocalizedString("JustCash.map_toggle_button", value:"Map", comment: "Map toggle button")
        
        // Redeem Flow - Get ATM Code Screen
        static let amountToWithdrawPlaceholder = NSLocalizedString("JustCash.amountToWithdraw_placeholder", value:"Amount to withdraw", comment: "Redeem flow amount textfield placeholder")
        static let phoneNumberPlaceholder = NSLocalizedString("JustCash.phoneNumber_placeholder", value:"Phone Number", comment: "Redeem flow phone number textfield placeholder")
        static let firstNamePlaceholder = NSLocalizedString("JustCash.firstName_placeholder", value:"First Name", comment: "Redeem flow first name textfield placeholder")
        static let lastNamePlaceholder = NSLocalizedString("JustCash.lastName_placeholder", value:"Last Name", comment: "Redeem flow last name textfield placeholder")
        static let getAtmCodeButton = NSLocalizedString("JustCash.getAtmCode_button", value:"Get ATM Code", comment: "Redeem flow get atm code button text")
        static let amountToWithdrawLegend = NSLocalizedString("JustCash.amountToWithdraw_legend_label", value:"Min %1$@, Max %1$@, Multiple Of %1$@", comment: "Redeem flow amount to withdraw legend text")
        static let smsAgreementLabel = NSLocalizedString("JustCash.smsAgreement_label", value:"I agree to receive text messages specific to this transaction. Standard messaging rates may apply", comment: "Redeem flow sms agreement legend")
        static let amountToWithdrawError = NSLocalizedString("JustCash.amountToWithdraw_error", value:"Amount should be between %1$@ and %1$@", comment: "Redeem flow amount to withdraw error message")
        static let phoneNumberError = NSLocalizedString("JustCash.phoneNumber_error", value:"Phone number should be 10 digits long", comment: "Redeem flow phone number error message")
        static let fieldRequiredError = NSLocalizedString("JustCash.fieldRequired", value:"This field is required", comment: "Redeem flow field required error message")
        
        // Redeem Flow - Confirm Code Screen
        static let smsConfirmationViaSMSLabel = NSLocalizedString("JustCash.smsConfirmation_label", value:"We've sent a confirmation code to your phone by SMS.", comment: "Redeem flow confirmation code via SMS sent legend")
        static let checkSMSLabel = NSLocalizedString("JustCash.checkSMS_label", value:"check your phone SMS for the confirmation code we sent you. It may take a couple of minutes.", comment: "Redeem flow confirmation code check your phone legend")
        static let confirmButton = NSLocalizedString("JustCash.confirm_button", value:"Confirm", comment: "Redeem flow confirm button text")
        
        // Redeem Flow - Withdrawal Requested Prompt
        static let withdrawalRequestedTitle = NSLocalizedString("JustCash.withdrawalRequested_title", value:"Withdrawal Requested", comment: "Redeem flow withdrawal requested text")
        static let withdrawalRequestedBody = NSLocalizedString("JustCash.withdrawalRequested_body", value:"Please send the amount of %1$@ BTC to the ATM", comment: "Redeem flow withdrawal requested body text")
        static let sendButton = NSLocalizedString("JustCash.send_button", value:"Send", comment: "Redeem flow send button")
        
        // Transactions
        static let new = NSLocalizedString("JustCash.new", value:"New", comment: "Transactions new text")
        static let pending = NSLocalizedString("JustCash.pending", value:"Pending", comment: "Transactions pending text")
        static let transactionSent = NSLocalizedString("JustCash.transactionSent", value:"Transaction Send", comment: "Transactions transaction sent text")
        static let unconfirmed = NSLocalizedString("JustCash.unconfirmed", value:"Unconfirmed", comment: "Transactions unconfirmed text")
        static let funded = NSLocalizedString("JustCash.funded", value:"Funded", comment: "Transactions funded text")
        static let used = NSLocalizedString("JustCash.used", value:"Used", comment: "Transactions used text")
        static let cancelled = NSLocalizedString("JustCash.cancelled", value:"Cancelled", comment: "Transactions cancelled text")
        static let today = NSLocalizedString("JustCash.today", value:"TODAY", comment: "Transactions today text")
        static let yesterday = NSLocalizedString("JustCash.yesterday", value:"YESTERDAY", comment: "Transactions yesterday text")
        static let amount = NSLocalizedString("JustCash.amount", value:"Amount", comment: "Transactions amount text")
        static let amountUSD = NSLocalizedString("JustCash.amountUSD", value:"Amount USD", comment: "Transactions amount USD label")
        static let amountBTC = NSLocalizedString("JustCash.amountBTC", value:"Amount BTC", comment: "Transactions amount BTC label")
        static let address = NSLocalizedString("JustCash.address", value:"Address", comment: "Transactions address label")
        
        // Tab Bar
        static let activity = NSLocalizedString("JustCash.tabBar_activity", value: "Activity", comment: "Home Screen History and Pending transactions toolbar button")
        static let atmCashRedeem = NSLocalizedString("JustCash.tabBar_atmCashRedeem", value: "ATM Cash Redeem", comment: "Home Screen atm cash redeem toolbar button")
        
        // Send View
        static let sendTitle = NSLocalizedString("JustCash.redeem_title", comment: "Send BTC for ATM Cash")
        static let highFeesMessage = NSLocalizedString("JustCash.highFeesMessage", comment: "High Fees Warning Message")
    }
}
