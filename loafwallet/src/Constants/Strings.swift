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
        static let photons = "mł"
        static let lites = "ł"
        static let ltc = "Ł"
        static let narrowSpace = "\u{2009}"
        static let lock = "\u{1F512}"
        static let redX = "\u{274C}"
        static func currencyButtonTitle(maxDigits: Int) -> String {
            switch maxDigits {
            case 2:
                return "photons\(S.Symbols.narrowSpace)(m\(S.Symbols.lites))"
            case 5:
                return "lites\(S.Symbols.narrowSpace)(\(S.Symbols.lites))"
            case 8:
                return "LTC\(S.Symbols.narrowSpace)(\(S.Symbols.ltc))"
            default:
                return "lites\(S.Symbols.narrowSpace)(\(S.Symbols.lites))"
            }
        }
    }
    
    enum Conjuction {
        static let asOf = NSLocalizedString("Conjunction.asOf", value: "**as of**", comment: "as of a time or date")
    }

    enum Button {
        static let ok = NSLocalizedString("Button.ok", value: "**OK**", comment: "OK button label")
        static let cancel = NSLocalizedString("Button.cancel", value: "**Cancel**", comment: "Cancel button label")
        static let settings = NSLocalizedString("Button.settings", value: "**Settings**", comment: "Settings button label")
        static let submit = NSLocalizedString("Button.submit", value: "**Submit**", comment: "Settings button label")
        static let ignore = NSLocalizedString("Button.ignore", value: "**Ignore**", comment: "Ignore button label")
        static let yes = NSLocalizedString("Button.yes", value: "**Yes**", comment: "Yes button")
        static let no = NSLocalizedString("Button.no", value: "**No**", comment: "No button")
        static let send = NSLocalizedString("Button.send", value: "**send**", comment: "send button")
        static let receive = NSLocalizedString("Button.receive", value: "**receive**", comment: "receive button")
        static let menu = NSLocalizedString("Button.menu", value: "**menu**", comment: "menu button")
        static let buy = NSLocalizedString("Button.buy", value: "**buy**", comment: "buy button")

    }

    enum Alert {
        static let warning = NSLocalizedString("Alert.warning", value: "**Warning**", comment: "Warning alert title")
        static let error = NSLocalizedString("Alert.error", value: "**Error**", comment: "Error alert title")
        static let noInternet = NSLocalizedString("Alert.noInternet", value: "**No internet connection found. Check your connection and try again.**", comment: "No internet alert message")
        static let corruptionError = NSLocalizedString("Alert.corruptionError", value: "**Database Corruption Error**", comment: "Corruption Error alert title")
        static let corruptionMessage = NSLocalizedString("Alert.corruptionMessage", value: "**Your local database is corrupted. Go to Settings > Blockchain: Settings > Delete Database to refresh**", comment: "Corruption Error alert title")
        
    }

    enum Scanner {
        static let flashButtonLabel = NSLocalizedString("Scanner.flashButtonLabel", value: "**Camera Flash**", comment: "Scan Litecoin address camera flash toggle")
    }

    enum Send {
        static let title = NSLocalizedString("Send.title", value: "**Send**", comment: "Send modal title")
        static let toLabel = NSLocalizedString("Send.toLabel", value: "**To**", comment: "Send money to label")
        static let amountLabel = NSLocalizedString("Send.amountLabel", value: "**Amount**", comment: "Send money amount label")
        static let descriptionLabel = NSLocalizedString("Send.descriptionLabel", value: "**Memo**", comment: "Description for sending money label")
        static let sendLabel = NSLocalizedString("Send.sendLabel", value: "**Send**", comment: "Send button label")
        static let pasteLabel = NSLocalizedString("Send.pasteLabel", value: "**Paste**", comment: "Paste button label")
        static let scanLabel = NSLocalizedString("Send.scanLabel", value: "**Scan**", comment: "Scan button label")
        static let invalidAddressTitle = NSLocalizedString("Send.invalidAddressTitle", value: "**Invalid Address**", comment: "Invalid address alert title")
        static let invalidAddressMessage = NSLocalizedString("Send.invalidAddressMessage", value: "**The destination address is not a valid Litecoin address.**", comment: "Invalid address alert message")
        static let invalidAddressOnPasteboard = NSLocalizedString("Send.invalidAddressOnPasteboard", value: "**Pasteboard does not contain a valid Litecoin address.**", comment: "Invalid address on pasteboard message")
        static let emptyPasteboard = NSLocalizedString("Send.emptyPasteboard", value: "**Pasteboard is empty**", comment: "Empty pasteboard error message")
        static let cameraUnavailableTitle = NSLocalizedString("Send.cameraUnavailableTitle", value: "**Litewallet is not allowed to access the camera**", comment: "Camera not allowed alert title")
        static let cameraUnavailableMessage = NSLocalizedString("Send.cameraunavailableMessage", value: "**Go to Settings to allow camera access.**", comment: "Camera not allowed message")
        static let balance = NSLocalizedString("Send.balance", value: "**Balance: %1$@**", comment: "Balance: $4.00")
        static let fee = NSLocalizedString("Send.fee", value: "**Network Fee: %1$@**", comment: "Network Fee: $0.01")
        static let containsAddress = NSLocalizedString("Send.containsAddress", value: "**The destination is your own address. You cannot send to yourself.**", comment: "Warning when sending to self.")
        enum UsedAddress {
            static let title = NSLocalizedString("Send.UsedAddress.title", value: "**Address Already Used**", comment: "Adress already used alert title")
            static let firstLine = NSLocalizedString("Send.UsedAddress.firstLine", value: "**Litecoin addresses are intended for single use only.**", comment: "Adress already used alert message - first part")
            static let secondLine = NSLocalizedString("Send.UsedAddress.secondLIne", value: "**Re-use reduces privacy for both you and the recipient and can result in loss if the recipient doesn't directly control the address.**", comment: "Adress already used alert message - second part")
        }
        static let identityNotCertified = NSLocalizedString("Send.identityNotCertified", value: "**Payee identity isn't certified.**", comment: "Payee identity not certified alert title.")
        static let createTransactionError = NSLocalizedString("Send.creatTransactionError", value: "**Could not create transaction.**", comment: "Could not create transaction alert title")
        static let publicTransactionError = NSLocalizedString("Send.publishTransactionError", value: "**Could not publish transaction.**", comment: "Could not publish transaction alert title")
        static let noAddress = NSLocalizedString("Send.noAddress", value: "**Please enter the recipient's address.**", comment: "Empty address alert message")
        static let noAmount = NSLocalizedString("Send.noAmount", value: "**Please enter an amount to send.**", comment: "Emtpy amount alert message")
        static let isRescanning = NSLocalizedString("Send.isRescanning", value: "**Sending is disabled during a full rescan.**", comment: "Is rescanning error message")
        static let remoteRequestError = NSLocalizedString("Send.remoteRequestError", value: "**Could not load payment request**", comment: "Could not load remote request error message")
        static let loadingRequest = NSLocalizedString("Send.loadingRequest", value: "**Loading Request**", comment: "Loading request activity view message")
        static let insufficientFunds = NSLocalizedString("Send.insufficientFunds", value: "**Insufficient Funds**", comment: "Insufficient funds error")
        static let barItemTitle = NSLocalizedString("Send.barItemTitle", value: "**Send**", comment: "Send Bar Item Title")
    }

    enum Receive {
        static let title = NSLocalizedString("Receive.title", value: "**Receive**", comment: "Receive modal title")
        static let emailButton = NSLocalizedString("Receive.emailButton", value: "**Email**", comment: "Share via email button label")
        static let textButton = NSLocalizedString("Receive.textButton", value: "**Text Message**", comment: "Share via text message (SMS)")
        static let copied = NSLocalizedString("Receive.copied", value: "**Copied to clipboard.**", comment: "Address copied message.")
        static let share = NSLocalizedString("Receive.share", value: "**Share**", comment: "Share button label")
        static let request = NSLocalizedString("Receive.request", value: "**Request an Amount**", comment: "Request button label")
        static let barItemTitle = NSLocalizedString("Receive.barItemTitle", value: "**Receive**", comment: "Receive Bar Item Title")
    }
    
    enum Account {
        static let loadingMessage = NSLocalizedString("Account.loadingMessage", value: "**Loading Wallet**", comment: "Loading Wallet Message")
    }
    
    enum History {
        static let barItemTitle = NSLocalizedString("History.barItemTitle", value: "**History**", comment: "History Bar Item Title")
    }

    enum JailbreakWarnings {
        static let title = NSLocalizedString("JailbreakWarnings.title", value: "**WARNING**", comment: "Jailbreak warning title")
        static let messageWithBalance = NSLocalizedString("JailbreakWarnings.messageWithBalance", value: "**DEVICE SECURITY COMPROMISED\n Any 'jailbreak' app can access Litewallet's keychain data and steal your Litecoin! Wipe this wallet immediately and restore on a secure device.**", comment: "Jailbreak warning message")
        static let messageWithoutBalance = NSLocalizedString("JailbreakWarnings.messageWithoutBalance", value: "**DEVICE SECURITY COMPROMISED\n Any 'jailbreak' app can access Litewallet's keychain data and steal your Litecoin. Please only use Litewallet on a non-jailbroken device.**", comment: "Jailbreak warning message")
        static let ignore = NSLocalizedString("JailbreakWarnings.ignore", value: "**Ignore**", comment: "Ignore jailbreak warning button")
        static let wipe = NSLocalizedString("JailbreakWarnings.wipe", value: "**Wipe**", comment: "Wipe wallet button")
        static let close = NSLocalizedString("JailbreakWarnings.close", value: "**Close**", comment: "Close app button")
    }

    enum ErrorMessages {
        static let emailUnavailableTitle = NSLocalizedString("ErrorMessages.emailUnavailableTitle", value: "**Email Unavailable**", comment: "Email unavailable alert title")
        static let emailUnavailableMessage = NSLocalizedString("ErrorMessages.emailUnavailableMessage", value: "**This device isn't configured to send email with the iOS mail app.**", comment: "Email unavailable alert title")
        static let messagingUnavailableTitle = NSLocalizedString("ErrorMessages.messagingUnavailableTitle", value: "**Messaging Unavailable**", comment: "Messaging unavailable alert title")
        static let messagingUnavailableMessage = NSLocalizedString("ErrorMessages.messagingUnavailableMessage", value: "**This device isn't configured to send messages.**", comment: "Messaging unavailable alert title")
    }

    enum UnlockScreen {
        static let myAddress = NSLocalizedString("UnlockScreen.myAddress", value: "**My Address**", comment: "My Address button title")
        static let scan = NSLocalizedString("UnlockScreen.scan", value: "**Scan**", comment: "Scan button title")
        static let touchIdText = NSLocalizedString("UnlockScreen.touchIdText", value: "**Unlock with TouchID**", comment: "Unlock with TouchID accessibility label")
        static let touchIdPrompt = NSLocalizedString("UnlockScreen.touchIdPrompt", value: "**Unlock your LoafWallet.**", comment: "TouchID/FaceID prompt text")
        static let enterPIN = NSLocalizedString("UnlockScreen.enterPin", value: "**Enter PIN**", comment: "Unlock Screen sub-header")
        static let unlocked = NSLocalizedString("UnlockScreen.unlocked", value: "**Wallet Unlocked**", comment: "Wallet unlocked message")
        static let disabled = NSLocalizedString("UnlockScreen.disabled", value: "**Disabled until: %1$@**", comment: "Disabled until date")
        static let resetPin = NSLocalizedString("UnlockScreen.resetPin", value: "**Reset PIN**", comment: "Reset PIN with Paper Key button label.")
        static let faceIdText = NSLocalizedString("UnlockScreen.faceIdText", value: "**Unlock with FaceID**", comment: "Unlock with FaceID accessibility label")
    }
    
    enum Transaction {
        static let justNow = NSLocalizedString("Transaction.justNow", value: "**just now**", comment: "Timestamp label for event that just happened")
        static let invalid = NSLocalizedString("Transaction.invalid", value: "**INVALID**", comment: "Invalid transaction")
        static let complete = NSLocalizedString("Transaction.complete", value: "**Complete**", comment: "Transaction complete label")
        static let waiting = NSLocalizedString("Transaction.waiting", value: "**Waiting to be confirmed. Some merchants require confirmation to complete a transaction. Estimated time: 1-2 hours.**", comment: "Waiting to be confirmed string")
        static let starting = NSLocalizedString("Transaction.starting", value: "**Starting balance: %1$@**", comment: "eg. Starting balance: $50.00")
        static let fee = NSLocalizedString("Transaction.fee", value: "**(%1$@ fee)**", comment: "(b600 fee)")
        static let ending = NSLocalizedString("Transaction.ending", value: "**Ending balance: %1$@**", comment: "eg. Ending balance: $50.00")
        static let exchangeOnDaySent = NSLocalizedString("Transaction.exchangeOnDaySent", value: "**Exchange rate when sent:**", comment: "Exchange rate on date header")
        static let exchangeOnDayReceived = NSLocalizedString("Transaction.exchangeOnDayReceived", value: "**Exchange rate when received:**", comment: "Exchange rate on date header")
        static let receivedStatus = NSLocalizedString("Transaction.receivedStatus", value: "**In progress: %1$@**", comment: "Receive status text: 'In progress: 20%'")
        static let sendingStatus = NSLocalizedString("Transaction.sendingStatus", value: "**In progress: %1$@**", comment: "Send status text: 'In progress: 20%'")
        static let available = NSLocalizedString("Transaction.available", value: "**Available to Spend**", comment: "Availability status text")
        static let txIDLabel = NSLocalizedString("Transaction.txIDLabel", value: "**Transaction txID**", comment: "Static TX iD Label")
        static let amountDetailLabel = NSLocalizedString("Transaction.amountDetailLabel", value: "**Transaction amount detail**", comment: "Static amount Label")
        static let startingAmountDetailLabel = NSLocalizedString("Transaction.startingAmountDetailLabel", value: "**Transaction starting amount detail**", comment: "Static starting amount Label")
        static let endAmountDetailLabel = NSLocalizedString("Transaction.endAmountDetailLabel", value: "**Transaction end amount detail**", comment: "Static end amount Label")
        static let blockHeightLabel = NSLocalizedString("Transaction.blockHeightLabel", value: "**Transaction blockHeightLabel**", comment: "Static blockHeight Label")
        static let commentLabel = NSLocalizedString("Transaction.commentLabel", value: "**Transaction comment label**", comment: "Static comment Label")
    }

    enum TransactionDetails {
        static let title = NSLocalizedString("TransactionDetails.title", value: "**Transaction Details**", comment: "Transaction Details Title")
        static let receiveModaltitle = NSLocalizedString("TransactionDetails.receivedModalTitle", value: "**RECEIVE LTC**", comment: "RECEIVE LTCTitle")
        static let statusHeader = NSLocalizedString("TransactionDetails.statusHeader", value: "**Status**", comment: "Status section header")
        static let commentsHeader = NSLocalizedString("TransactionDetails.commentsHeader", value: "**Memo**", comment: "Memo section header")
        static let amountHeader = NSLocalizedString("TransactionDetails.amountHeader", value: "**Amount**", comment: "Amount section header")
        static let emptyMessage = NSLocalizedString("TransactionDetails.emptyMessage", value: "**Your transactions will appear here.**", comment: "Empty transaction list message.") 
        static let txHashHeader = NSLocalizedString("TransactionDetails.txHashHeader", value: "**Litecoin Transaction ID**", comment: "Transaction ID header")
        static let sentAmountDescription = NSLocalizedString("TransactionDetails.sentAmountDescription", value: "**Sent <b>%1@</b>**", comment: "Sent $5.00")
        static let receivedAmountDescription = NSLocalizedString("TransactionDetails.receivedAmountDescription", value: "**Received <b>%1@</b>**", comment: "Received $5.00")
        static let movedAmountDescription = NSLocalizedString("TransactionDetails.movedAmountDescription", value: "**Moved <b>%1@</b>**", comment: "Moved $5.00")
        static let account = NSLocalizedString("TransactionDetails.account", value: "**account**", comment: "e.g. I received money from an account.")
        static let sent = NSLocalizedString("TransactionDetails.sent", value: "**Sent %1$@**", comment: "Sent $5.00 (sent title 1/2)")
        static let received = NSLocalizedString("TransactionDetails.received", value: "**Received %1$@**", comment: "Received $5.00 (received title 1/2)")
        static let moved = NSLocalizedString("TransactionDetails.moved", value: "**Moved %1$@**", comment: "Moved $5.00")
        static let to = NSLocalizedString("TransactionDetails.to", value: "**to %1$@**", comment: "[sent] to <address> (sent title 2/2)")
        static let from = NSLocalizedString("TransactionDetails.from", value: "**at %1$@**", comment: "[received] at <address> (received title 2/2)")
        static let blockHeightLabel = NSLocalizedString("TransactionDetails.blockHeightLabel", value: "**Confirmed in Block**", comment: "Block height label")
        static let notConfirmedBlockHeightLabel = NSLocalizedString("TransactionDetails.notConfirmedBlockHeightLabel", value: "**Not Confirmed**", comment: "eg. Confirmed in Block: Not Confirmed")
        static let staticTXIDLabel = NSLocalizedString("TransactionDetails.staticTXLabel", value: "**TXID:**", comment: "Label for TXID")
        static let priceTimeStampLabel = NSLocalizedString("TransactionDetails.priceTimeStampPrefix", value: "**as of**", comment: "Prefix for price")
    }
  
    enum BuyCenter {
      static let title = NSLocalizedString("BuyCenter.title", value: "**Buy Litecoin**", comment: "Buy Center Title")
      static let buyModalTitle = NSLocalizedString("BuyCenter.ModalTitle", value: "**Buy Łitecoin**", comment: "Buy Modal Title")
      enum Cells {
        static let simplexTitle = NSLocalizedString("BuyCenter.simplexTitle", value: "**Simplex**", comment: "Simplex Title")
        static let simplexFinancialDetails = NSLocalizedString("BuyCenter.simplexFinancialDetails", value: "**• Get Litecoin in 5 mins!\n• Buy Litecoin via credit card\n• Passport or State ID**", comment: "Simplex buy financial details")
        static let changellyTitle = NSLocalizedString("BuyCenter.changellyTitle", value: "**Changelly**", comment: "Changelly Title")
        static let changellyFinancialDetails = NSLocalizedString("BuyCenter.changellyFinancialDetails", value: "**• Change Litecoin for other cryptos\n• No ID Required\n• Buy via credit card\n• Global coverage**", comment: "Changelly buy financial details")
        static let bitrefillTitle = NSLocalizedString("BuyCenter.BitrefillTitle", value: "**Bitrefill**", comment: "Bitrefill Title")
        static let bitrefillFinancialDetails = NSLocalizedString("BuyCenter.bitrefillFinancialDetails", value: "**• Buy gift cards\n• Refill prepaid phones\n• Steam, Amazon, Hotels.com\n• Works in 170 countries**", comment: "Bitrefill buy financial details")
        }
      static let barItemTitle = NSLocalizedString("BuyCenter.barItemTitle", value: "**Buy**", comment: "Buy Bar Item Title")
        
      static let comingSoon = NSLocalizedString("BuyCenter.comingSoon", value: "**ComingSoon**", comment: "Coming Soon")
    }

    enum SecurityCenter {
        static let title = NSLocalizedString("SecurityCenter.title", value: "**Security Center**", comment: "Security Center Title")
        static let info = NSLocalizedString("SecurityCenter.info", value: "**Enable all security features for maximum protection.**", comment: "Security Center Info")
        enum Cells {
            static let pinTitle = NSLocalizedString("SecurityCenter.pinTitle", value: "**6-Digit PIN**", comment: "PIN button title")
            static let pinDescription = NSLocalizedString("SecurityCenter.pinDescription", value: "**Protects your Litewallet from unauthorized users.**", comment: "PIN button description")
            static let touchIdTitle = NSLocalizedString("SecurityCenter.touchIdTitle", value: "**Touch ID**", comment: "Touch ID button title")
            static let touchIdDescription = NSLocalizedString("SecurityCenter.touchIdDescription", value: "**Conveniently unlock your Litewallet and send money up to a set limit.**", comment: "Touch ID/FaceID button description")
            static let paperKeyTitle = NSLocalizedString("SecurityCenter.paperKeyTitle", value: "**Paper Key**", comment: "Paper Key button title")
            static let paperKeyDescription = NSLocalizedString("SecurityCenter.paperKeyDescription", value: "**The only way to access your Litecoin if you lose or upgrade your phone.**", comment: "Paper Key button description")
            static let faceIdTitle = NSLocalizedString("SecurityCenter.faceIdTitle", value: "**Face ID**", comment: "Face ID button title")
        }
    }

    enum UpdatePin {
        static let updateTitle = NSLocalizedString("UpdatePin.updateTitle", value: "**Update PIN**", comment: "Update PIN title")
        static let createTitle = NSLocalizedString("UpdatePin.createTitle", value: "**Set PIN**", comment: "Update PIN title")
        static let createTitleConfirm = NSLocalizedString("UpdatePin.createTitleConfirm", value: "**Re-Enter PIN**", comment: "Update PIN title")
        static let createInstruction = NSLocalizedString("UpdatePin.createInstruction", value: "**Your PIN will be used to unlock your Litewallet and send money.**", comment: "PIN creation info.")
        static let enterCurrent = NSLocalizedString("UpdatePin.enterCurrent", value: "**Enter your current PIN.**", comment: "Enter current PIN instruction")
        static let enterNew = NSLocalizedString("UpdatePin.enterNew", value: "**Enter your new PIN.**", comment: "Enter new PIN instruction")
        static let reEnterNew = NSLocalizedString("UpdatePin.reEnterNew", value: "**Re-Enter your new PIN.**", comment: "Re-Enter new PIN instruction")
        static let caption = NSLocalizedString("UpdatePin.caption", value: "**Remember this PIN. If you forget it, you won't be able to access your Litecoin.**", comment: "Update PIN caption text")
        static let setPinErrorTitle = NSLocalizedString("UpdatePin.setPinErrorTitle", value: "**Update PIN Error**", comment: "Update PIN failure alert view title")
        static let setPinError = NSLocalizedString("UpdatePin.setPinError", value: "**Sorry, could not update PIN.**", comment: "Update PIN failure error message.")
    }

    enum RecoverWallet {
        static let next = NSLocalizedString("RecoverWallet.next", value: "**Next**", comment: "Next button label")
        static let intro = NSLocalizedString("RecoverWallet.intro", value: "**Recover your Litewallet with your paper key.**", comment: "Recover wallet intro")
        static let leftArrow = NSLocalizedString("RecoverWallet.leftArrow", value: "**Left Arrow**", comment: "Previous button accessibility label")
        static let rightArrow = NSLocalizedString("RecoverWallet.rightArrow", value: "**Right Arrow**", comment: "Next button accessibility label")
        static let done = NSLocalizedString("RecoverWallet.done", value: "**Done**", comment: "Done button text")
        static let instruction = NSLocalizedString("RecoverWallet.instruction", value: "**Enter Paper Key**", comment: "Enter paper key instruction")
        static let header = NSLocalizedString("RecoverWallet.header", value: "**Recover Wallet**", comment: "Recover wallet header")
        static let subheader = NSLocalizedString("RecoverWallet.subheader", value: "**Enter the paper key for the wallet you want to recover.**", comment: "Recover wallet sub-header")

        static let headerResetPin = NSLocalizedString("RecoverWallet.header_reset_pin", value: "**Reset PIN**", comment: "Reset PIN with paper key: header")
        static let subheaderResetPin = NSLocalizedString("RecoverWallet.subheader_reset_pin", value: "**To reset your PIN, enter the words from your paper key into the boxes below.**", comment: "Reset PIN with paper key: sub-header")
        static let resetPinInfo = NSLocalizedString("RecoverWallet.reset_pin_more_info", value: "**Tap here for more information.**", comment: "Reset PIN with paper key: more information button.")
        static let invalid = NSLocalizedString("RecoverWallet.invalid", value: "**The paper key you entered is invalid. Please double-check each word and try again.**", comment: "Invalid paper key message")
    }

    enum ManageWallet {
        static let title = NSLocalizedString("ManageWallet.title", value: "**Manage Wallet**", comment: "Manage wallet modal title")
        static let textFieldLabel = NSLocalizedString("ManageWallet.textFeildLabel", value: "**Wallet Name**", comment: "Change Wallet name textfield label")
        static let description = NSLocalizedString("ManageWallet.description", value: "**Your wallet name only appears in your account transaction history and cannot be seen by anyone else.**", comment: "Manage wallet description text")
        static let creationDatePrefix = NSLocalizedString("ManageWallet.creationDatePrefix", value: "**You created your wallet on %1$@**", comment: "Wallet creation date prefix")
    }

    enum AccountHeader {
        static let defaultWalletName = NSLocalizedString("AccountHeader.defaultWalletName", value: "**My Litewallet**", comment: "Default wallet name")
        static let manageButtonName = NSLocalizedString("AccountHeader.manageButtonName", value: "**MANAGE**", comment: "Manage wallet button title")
    }

    enum VerifyPin {
        static let title = NSLocalizedString("VerifyPin.title", value: "**PIN Required**", comment: "Verify PIN view title")
        static let continueBody = NSLocalizedString("VerifyPin.continueBody", value: "**Please enter your PIN to continue.**", comment: "Verify PIN view body")
        static let authorize = NSLocalizedString("VerifyPin.authorize", value: "**Please enter your PIN to authorize this transaction.**", comment: "Verify PIN for transaction view body")
        static let touchIdMessage = NSLocalizedString("VerifyPin.touchIdMessage", value: "**Authorize this transaction**", comment: "Authorize transaction with touch id message")
    }

    enum TouchIdSettings {
        static let title = NSLocalizedString("TouchIdSettings.title", value: "**Touch ID**", comment: "Touch ID settings view title")
        static let label = NSLocalizedString("TouchIdSettings.label", value: "**Use your fingerprint to unlock your Litewallet and send money up to a set limit.**", comment: "Touch Id screen label")
        static let switchLabel = NSLocalizedString("TouchIdSettings.switchLabel", value: "**Enable Touch ID for Litewallet**", comment: "Touch id switch label.")
        static let unavailableAlertTitle = NSLocalizedString("TouchIdSettings.unavailableAlertTitle", value: "**Touch ID Not Set Up**", comment: "Touch ID unavailable alert title")
        static let unavailableAlertMessage = NSLocalizedString("TouchIdSettings.unavailableAlertMessage", value: "**You have not set up Touch ID on this device. Go to Settings->Touch ID & Passcode to set it up now.**", comment: "Touch ID unavailable alert message")
        static let spendingLimit = NSLocalizedString("TouchIdSettings.spendingLimit", value: "**Spending limit: %1$@ (%2$@)**", comment: "Spending Limit: b100,000 ($100)")
        static let limitValue = NSLocalizedString("TouchIdSettings.limitValue", value: "**%1$@ (%2$@)**", comment: " ł100,000 ($100)")
        static let customizeText = NSLocalizedString("TouchIdSettings.customizeText", value: "**You can customize your Touch ID spending limit from the %1$@.**", comment: "You can customize your Touch ID Spending Limit from the [TouchIdSettings.linkText gets added here as a button]")
        static let linkText = NSLocalizedString("TouchIdSettings.linkText", value: "**Touch ID Spending Limit Screen**", comment: "Link Text (see TouchIdSettings.customizeText)")
    }

    enum FaceIDSettings {
        static let title = NSLocalizedString("FaceIDSettings.title", value: "**Face ID**", comment: "Face ID settings view title")
        static let label = NSLocalizedString("FaceIDSettings.label", value: "**Use your face to unlock your Litewallet and send money up to a set limit.**", comment: "Face ID screen label")
        static let switchLabel = NSLocalizedString("FaceIDSettings.switchLabel", value: "**Enable Face ID for Litewallet**", comment: "Face id switch label.")
        static let unavailableAlertTitle = NSLocalizedString("FaceIDSettings.unavailableAlertTitle", value: "**Face ID Not Set Up**", comment: "Face ID unavailable alert title")
        static let unavailableAlertMessage = NSLocalizedString("FaceIDSettings.unavailableAlertMessage", value: "**You have not set up Face ID on this device. Go to Settings->Face ID & Passcode to set it up now.**", comment: "Face ID unavailable alert message")
        static let customizeText = NSLocalizedString("FaceIDSettings.customizeText", value: "**You can customize your Face ID spending limit from the %1$@.**", comment: "You can customize your Face ID Spending Limit from the [TouchIdSettings.linkText gets added here as a button]")
        static let linkText = NSLocalizedString("FaceIDSettings.linkText", value: "**Face ID Spending Limit Screen**", comment: "Link Text (see TouchIdSettings.customizeText)")
    }
    
    enum SpendingLimit {
        static let titleLabel = NSLocalizedString("SpendingLimit.title", value: "**Current Spending Limit: **", comment: "Current spending limit:")
    }

    enum TouchIdSpendingLimit {
        static let title = NSLocalizedString("TouchIdSpendingLimit.title", value: "**Touch ID Spending Limit**", comment: "Touch Id spending limit screen title")
        static let body = NSLocalizedString("TouchIdSpendingLimit.body", value: "**You will be asked to enter your 6-digit PIN to send any transaction over your spending limit, and every 48 hours since the last time you entered your 6-digit PIN.**", comment: "Touch ID spending limit screen body")
        static let requirePasscode = NSLocalizedString("TouchIdSpendingLimit", value: "**Always require passcode**", comment: "Always require passcode option")
    }

    enum FaceIdSpendingLimit {
        static let title = NSLocalizedString("FaceIDSpendingLimit.title", value: "**Face ID Spending Limit**", comment: "Face Id spending limit screen title")
    }

    enum Settings {
        static let title = NSLocalizedString("Settings.title", value: "**Settings**", comment: "Settings title")
        static let wallet = NSLocalizedString("Settings.wallet", value: "**Wallet**", comment: "Wallet Settings section header")
        static let manage = NSLocalizedString("Settings.manage", value: "**Manage**", comment: "Manage settings section header")
        static let support = NSLocalizedString("Settings.support", value: "**Support**", comment: "Support settings section header")
        static let blockchain = NSLocalizedString("Settings.blockchain", value: "**Blockchain**", comment: "Blockchain settings section header")
        static let importTile = NSLocalizedString("Settings.importTitle", value: "**Import Wallet**", comment: "Import wallet label")
        static let notifications = NSLocalizedString("Settings.notifications", value: "**Notifications**", comment: "Notifications label")
        static let touchIdLimit = NSLocalizedString("Settings.touchIdLimit", value: "**Touch ID Spending Limit**", comment: "Touch ID spending limit label")
        static let currency = NSLocalizedString("Settings.currency", value: "**Display Currency**", comment: "Default currency label")
        static let sync = NSLocalizedString("Settings.sync", value: "**Sync Blockchain**", comment: "Sync blockchain label")
        static let shareData = NSLocalizedString("Settings.shareData", value: "**Share Anonymous Data**", comment: "Share anonymous data label")
        static let earlyAccess = NSLocalizedString("Settings.earlyAccess", value: "**Join Early Access**", comment: "Join Early access label")
        static let about = NSLocalizedString("Settings.about", value: "**About**", comment: "About label")
        static let review = NSLocalizedString("Settings.review", value: "**Leave us a Review**", comment: "Leave review button label")
        static let enjoying = NSLocalizedString("Settings.enjoying", value: "**Are you enjoying Litewallet?**", comment: "Are you enjoying Litewallet alert message body")
        static let wipe = NSLocalizedString("Settings.wipe", value: "**Start/Recover Another Wallet**", comment: "Start or recover another wallet menu label.")
        static let advancedTitle = NSLocalizedString("Settings.advancedTitle", value: "**Advanced Settings**", comment: "Advanced Settings title")
        static let faceIdLimit = NSLocalizedString("Settings.faceIdLimit", value: "**Face ID Spending Limit**", comment: "Face ID spending limit label")
        static let languages = NSLocalizedString("Settings.languages", value: "**Languages**", comment: "Languages label")
        static let litewalletVersion = NSLocalizedString("Settings.litewallet.version", value: "**Litewallet Version:**", comment: "Litewallet version")
        static let litewalletEnvironment = NSLocalizedString("Settings.litewallet.environment", value: "**Litewallet Environment:**", comment: "Litewallet environment")
        static let socialLinks = NSLocalizedString("Settings.socialLinks", value: "**Social Links:**", comment: "Litewallet Social links")
    }

    enum About {
        static let title = NSLocalizedString("About.title", value: "**About**", comment: "About screen title")
        static let blog = NSLocalizedString("About.blog", value: "**Website**", comment: "About screen website label")
        static let twitter = NSLocalizedString("About.twitter", value: "**Twitter**", comment: "About screen twitter label")
        static let reddit = NSLocalizedString("About.reddit", value: "**Reddit**", comment: "About screen reddit label")
        static let privacy = NSLocalizedString("About.privacy", value: "**Privacy Policy**", comment: "Privay Policy button label")
        static let footer = NSLocalizedString("About.footer", value: "**Made by the LiteWallet Team\nof the\nLitecoin Foundation\n%1$@**", comment: "About screen footer")
    }

    enum PushNotifications {
        static let title = NSLocalizedString("PushNotifications.title", value: "**Notifications**", comment: "Push notifications settings view title label")
        static let body = NSLocalizedString("PushNotifications.body", value: "**Turn on notifications to receive special messages from Litewallet in the future.**", comment: "Push notifications settings view body")
        static let label = NSLocalizedString("PushNotifications.label", value: "**Push Notifications**", comment: "Push notifications toggle switch label")
        static let on = NSLocalizedString("PushNotifications.on", value: "**On**", comment: "Push notifications are on label")
        static let off = NSLocalizedString("PushNotifications.off", value: "**Off**", comment: "Push notifications are off label")
    }

    enum DefaultCurrency {
        static let rateLabel = NSLocalizedString("DefaultCurrency.rateLabel", value: "**Exchange Rate**", comment: "Exchange rate label")
        static let bitcoinLabel = NSLocalizedString("DefaultCurrency.bitcoinLabel", value: "**Litecoin Display Unit**", comment: "Litecoin denomination picker label")
        static let chooseFiatLabel = NSLocalizedString("DefaultCurrency.chooseFiatLabel", value: "**Choose Fiat:**", comment: "Label to pick fiat")
    }

    enum SyncingView {
        static let syncing = NSLocalizedString("SyncingView.syncing", value: "**Syncing**", comment: "Syncing view syncing state header text")
        static let connecting = NSLocalizedString("SyncingView.connecting", value: "**Connecting**", comment: "Syncing view connectiong state header text")
    }
    
    enum SyncingHeader {
        static let syncing = NSLocalizedString("SyncingHeader.syncing", value: "**Syncing...**", comment: "Syncing view syncing state header text")
        static let connecting = NSLocalizedString("SyncingHeader.connecting", value: "**Connecting...**", comment: "Syncing view connection state header text")
        static let success = NSLocalizedString("SyncingHeader.success", value: "**Success!**", comment: "Syncing header success state header text")
        static let rescanning = NSLocalizedString("SyncingHeader.rescan", value: "**Rescanning...*", comment: "Rescanning header success state header text")
        
    }

    enum ReScan {
        static let header = NSLocalizedString("ReScan.header", value: "**Sync Blockchain**", comment: "Sync Blockchain view header")
        static let subheader1 = NSLocalizedString("ReScan.subheader1", value: "**Estimated time**", comment: "Subheader label")
        static let subheader2 = NSLocalizedString("ReScan.subheader2", value: "**When to Sync?**", comment: "Subheader label")
        static let body1 = NSLocalizedString("ReScan.body1", value: "**20-45 minutes**", comment: "extimated time")
        static let body2 = NSLocalizedString("ReScan.body2", value: "**If a transaction shows as completed on the Litecoin network but not in your Litewallet.**", comment: "Syncing explanation")
        static let body3 = NSLocalizedString("ReScan.body3", value: "**You repeatedly get an error saying your transaction was rejected.**", comment: "Syncing explanation")
        static let buttonTitle = NSLocalizedString("ReScan.buttonTitle", value: "**Start Sync**", comment: "Start Sync button label")
        static let footer = NSLocalizedString("ReScan.footer", value: "**You will not be able to send money while syncing with the blockchain.**", comment: "Sync blockchain view footer")
        static let alertTitle = NSLocalizedString("ReScan.alertTitle", value: "**Sync with Blockchain?**", comment: "Alert message title")
        static let alertMessage = NSLocalizedString("ReScan.alertMessage", value: "**You will not be able to send money while syncing.**", comment: "Alert message body")
        static let alertAction = NSLocalizedString("ReScan.alertAction", value: "**Sync**", comment: "Alert action button label")
    }

    enum ShareData {
        static let header = NSLocalizedString("ShareData.header", value: "**Share Data?**", comment: "Share data header")
        static let body = NSLocalizedString("ShareData.body", value: "**Help improve Litewallet by sharing your anonymous data with us. This does not include any financial information. We respect your financial privacy.**", comment: "Share data view body")
        static let toggleLabel = NSLocalizedString("ShareData.toggleLabel", value: "**Share Anonymous Data?**", comment: "Share data switch label.")
    }

    enum ConfirmPaperPhrase {
        static let word = NSLocalizedString("ConfirmPaperPhrase.word", value: "**Word #%1$@**", comment: "Word label eg. Word #1, Word #2")
        static let label = NSLocalizedString("ConfirmPaperPhrase.label", value: "**To make sure everything was written down correctly, please enter the following words from your paper key.**", comment: "Confirm paper phrase view label.")
        static let error = NSLocalizedString("ConfirmPaperPhrase.error", value: "**The words entered do not match your paper key. Please try again.**", comment: "Confirm paper phrase error message")
    }

    enum StartPaperPhrase {
        static let body = NSLocalizedString("StartPaperPhrase.body", value: "**Your paper key is the only way to restore your Litewallet if your mobile is unavailable.\n No one in the Litecoin Foundation team can give this paper key to you!\n\nWe will show you a list of words to write down on a piece of paper and keep safe.\n\nPLEASE MAKE BACKUPS AND DON'T LOSE IT!**", comment: "Paper key explanation text.")
        static let buttonTitle = NSLocalizedString("StartPaperPhrase.buttonTitle", value: "**Write Down Paper Key**", comment: "button label")
        static let againButtonTitle = NSLocalizedString("StartPaperPhrase.againButtonTitle", value: "**Write Down Paper Key Again**", comment: "button label")
        static let date = NSLocalizedString("StartPaperPhrase.date", value: "**You last wrote down your paper key on %1$@**", comment: "Argument is date")
    }

    enum WritePaperPhrase {
        static let instruction = NSLocalizedString("WritePaperPhrase.instruction", value: "**Write down each word in order and store it in a safe place.**", comment: "Paper key instructions.")
        static let step = NSLocalizedString("WritePaperPhrase.step", value: "**%1$d of %2$d**", comment: "1 of 3")
        static let next = NSLocalizedString("WritePaperPhrase.next", value: "**Next**", comment: "button label")
        static let previous = NSLocalizedString("WritePaperPhrase.previous", value: "**Previous**", comment: "button label")
    }

    enum TransactionDirection {
        static let to = NSLocalizedString("TransactionDirection.to", value: "**Sent to this Address**", comment: "(this transaction was) Sent to this address:")
        static let received = NSLocalizedString("TransactionDirection.address", value: "**Received at this Address**", comment: "(this transaction was) Received at this address:")
    }

    enum RequestAnAmount {
        static let title = NSLocalizedString("RequestAnAmount.title", value: "**Request an Amount**", comment: "Request a specific amount of Litecoin")
        static let noAmount = NSLocalizedString("RequestAnAmount.noAmount", value: "**Please enter an amount first.**", comment: "No amount entered error message.")
    }

    enum Alerts {
        static let pinSet = NSLocalizedString("Alerts.pinSet", value: "**PIN Set**", comment: "Alert Header label (the PIN was set)")
        static let paperKeySet = NSLocalizedString("Alerts.paperKeySet", value: "**Paper Key Set**", comment: "Alert Header Label (the paper key was set)")
        static let sendSuccess = NSLocalizedString("Alerts.sendSuccess", value: "**Send Confirmation**", comment: "Send success alert header label (confirmation that the send happened)")
        static let sendFailure = NSLocalizedString("Alerts.sendFailure", value: "**Send failed**", comment: "Send failure alert header label (the send failed to happen)")
        static let paperKeySetSubheader = NSLocalizedString("Alerts.paperKeySetSubheader", value: "**Awesome!**", comment: "Alert Subheader label (playfully positive)")
        static let sendSuccessSubheader = NSLocalizedString("Alerts.sendSuccessSubheader", value: "**Money Sent!**", comment: "Send success alert subheader label (e.g. the money was sent)")
        static let copiedAddressesHeader = NSLocalizedString("Alerts.copiedAddressesHeader", value: "**Addresses Copied**", comment: "'the addresses were copied'' Alert title")
        static let copiedAddressesSubheader = NSLocalizedString("Alerts.copiedAddressesSubheader", value: "**All wallet addresses successfully copied.**", comment: "Addresses Copied Alert sub header")
    }

    enum MenuButton {
        static let security = NSLocalizedString("MenuButton.security", value: "**Security Center**", comment: "Menu button title")
        static let support = NSLocalizedString("MenuButton.support", value: "**Support**", comment: "Menu button title")
        static let settings = NSLocalizedString("MenuButton.settings", value: "**Settings**", comment: "Menu button title")
        static let lock = NSLocalizedString("MenuButton.lock", value: "**Lock Wallet**", comment: "Menu button title")
        static let buy = NSLocalizedString("MenuButton.buy", value: "**Buy Litecoin**", comment: "Buy Litecoin title")
    }

    enum MenuViewController {
        static let modalTitle = NSLocalizedString("MenuViewController.modalTitle", value: "**Menu**", comment: "Menu modal title")
    }

    enum StartViewController {
        static let createButton = NSLocalizedString("MenuViewController.createButton", value: "**Create New Wallet**", comment: "button label")
        static let recoverButton = NSLocalizedString("MenuViewController.recoverButton", value: "**Recover Wallet**", comment: "button label")
        static let message = NSLocalizedString("StartViewController.message", value: "**The most secure and safest way to use Litecoin.**", comment: "Start view message")
    }

    enum AccessibilityLabels {
        static let close = NSLocalizedString("AccessibilityLabels.close", value: "**Close**", comment: "Close modal button accessibility label")
        static let faq = NSLocalizedString("AccessibilityLabels.faq", value: "**Support Center**", comment: "Support center accessibiliy label")
    }

    enum Watch {
        static let noWalletWarning = NSLocalizedString("Watch.noWalletWarning", value: "**Open the Litewallet iPhone app to set up your wallet.**", comment: "'No wallet' warning for watch app")
    }

    enum Search {
        static let sent = NSLocalizedString("Search.sent", value: "**sent**", comment: "Sent filter label")
        static let received = NSLocalizedString("Search.received", value: "**received**", comment: "Received filter label")
        static let pending = NSLocalizedString("Search.pending", value: "**pending**", comment: "Pending filter label")
        static let complete = NSLocalizedString("Search.complete", value: "**complete**", comment: "Complete filter label")
    }

    enum Prompts {
        static let affirm = NSLocalizedString("Prompts.PaperKey.affirm", value: "**Continue**", comment: "Affirm button title.")
        static let cancel = NSLocalizedString("Prompts.PaperKey.cancel", value: "**Cancel**", comment: "Cancel button.")
        static let enable = NSLocalizedString("Prompts.PaperKey.enable", value: "**Enable**", comment: "Enable button.")
        static let dismiss = NSLocalizedString("Prompts.dismiss", value: "****Dismiss**", comment: "Dismiss button.")
        enum TouchId {
            static let title = NSLocalizedString("Prompts.TouchId.title", value: "**Enable Touch ID**", comment: "Enable touch ID prompt title")
            static let body = NSLocalizedString("Prompts.TouchId.body", value: "**Tap here to enable Touch ID**", comment: "Enable touch ID prompt body")
        }
        enum PaperKey {
            static let title = NSLocalizedString("Prompts.PaperKey.title", value: "**Action Required**", comment: "An action is required (You must do this action).")
            static let body = NSLocalizedString("Prompts.PaperKey.body", value: "**Your Paper Key must be kept in a safe place. It is the only way modify or restore your Litewallet or transfer your Litecoin. Please write it down.**", comment: "Warning about paper key.")
        }
        enum SetPin {
            static let title = NSLocalizedString("Prompts.SetPin.title", value: "**Set PIN**", comment: "Set PIN prompt title.")
            static let body = NSLocalizedString("Prompts.SetPin.body", value: "**Litewallet requires a 6-digit PIN. Please set and store your PIN in a safe place.**", comment: "Upgrade PIN prompt body.")
        }
        enum RecommendRescan {
            static let title = NSLocalizedString("Prompts.RecommendRescan.title", value: "**Transaction Rejected**", comment: "Transaction rejected prompt title")
            static let body = NSLocalizedString("Prompts.RecommendRescan.body", value: "**Your wallet may be out of sync. This can often be fixed by rescanning the blockchain.**", comment: "Transaction rejected prompt body")
        }
        enum NoPasscode {
            static let title = NSLocalizedString("Prompts.NoPasscode.title", value: "**Turn device passcode on**", comment: "No Passcode set warning title")
            static let body = NSLocalizedString("Prompts.NoPasscode.body", value: "**A device passcode is needed to safeguard your wallet.**", comment: "No passcode set warning body")
        }
        enum ShareData {
            static let title = NSLocalizedString("Prompts.ShareData.title", value: "**Share Anonymous Data**", comment: "Share data prompt title")
            static let body = NSLocalizedString("Prompts.ShareData.body", value: "**Help improve Litewallet by sharing your anonymous data with us**", comment: "Share data prompt body")
        }
        enum FaceId {
            static let title = NSLocalizedString("Prompts.FaceId.title", value: "**Enable Face ID**", comment: "Enable face ID prompt title")
            static let body = NSLocalizedString("Prompts.FaceId.body", value: "**Tap here to enable Face ID**", comment: "Enable face ID prompt body")
        }
    }

    enum PaymentProtocol {
        enum Errors {
            static let untrustedCertificate = NSLocalizedString("PaymentProtocol.Errors.untrustedCertificate", value: "**untrusted certificate**", comment: "Untrusted certificate payment protocol error message")
            static let missingCertificate = NSLocalizedString("PaymentProtocol.Errors.missingCertificate", value: "**missing certificate**", comment: "Missing certificate payment protocol error message")
            static let unsupportedSignatureType = NSLocalizedString("PaymentProtocol.Errors.unsupportedSignatureType", value: "**unsupported signature type**", comment: "Unsupported signature type payment protocol error message")
            static let requestExpired = NSLocalizedString("PaymentProtocol.Errors.requestExpired", value: "**request expired**", comment: "Request expired payment protocol error message")
            static let badPaymentRequest = NSLocalizedString("PaymentProtocol.Errors.badPaymentRequest", value: "**Bad Payment Request**", comment: "Bad Payment request alert title")
            static let smallOutputErrorTitle = NSLocalizedString("PaymentProtocol.Errors.smallOutputError", value: "**Couldn't make payment**", comment: "Payment too small alert title")
            static let smallPayment = NSLocalizedString("PaymentProtocol.Errors.smallPayment", value: "**Litecoin payments can't be less than %1$@.**", comment: "Amount too small error message")
            static let smallTransaction = NSLocalizedString("PaymentProtocol.Errors.smallTransaction", value: "**Litecoin transaction outputs can't be less than $@.**", comment: "Output too small error message.")
            static let corruptedDocument = NSLocalizedString("PaymentProtocol.Errors.corruptedDocument", value: "**Unsupported or corrupted document**", comment: "Error opening payment protocol file message")
        }
    }

    enum URLHandling {
        static let addressListAlertTitle = NSLocalizedString("URLHandling.addressListAlertTitle", value: "**Copy Wallet Addresses**", comment: "Authorize to copy wallet address alert title")
        static let addressListAlertMessage = NSLocalizedString("URLHandling.addressaddressListAlertMessage", value: "**Copy wallet addresses to clipboard?**", comment: "Authorize to copy wallet addresses alert message")
        static let addressListVerifyPrompt = NSLocalizedString("URLHandling.addressList", value: "**Authorize to copy wallet address to clipboard**", comment: "Authorize to copy wallet address PIN view prompt.")
        static let copy = NSLocalizedString("URLHandling.copy", value: "**Copy**", comment: "Copy wallet addresses alert button label")
    }

    enum ApiClient {
        static let notReady = NSLocalizedString("ApiClient.notReady", value: "**Wallet not ready**", comment: "Wallet not ready error message")
        static let jsonError = NSLocalizedString("ApiClient.jsonError", value: "**JSON Serialization Error**", comment: "JSON Serialization error message")
        static let tokenError = NSLocalizedString("ApiClient.tokenError", value: "**Unable to retrieve API token**", comment: "API Token error message")
    }

    enum CameraPlugin {
        static let centerInstruction = NSLocalizedString("CameraPlugin.centerInstruction", value: "**Center your ID in the box**", comment: "Camera plugin instruction")
    }

    enum LocationPlugin {
        static let disabled = NSLocalizedString("LocationPlugin.disabled", value: "**Location services are disabled.**", comment: "Location services disabled error")
        static let notAuthorized = NSLocalizedString("LocationPlugin.notAuthorized", value: "**Litewallet does not have permission to access location services.**", comment: "No permissions for location services")
    }

    enum Webview {
        static let updating = NSLocalizedString("Webview.updating", value: "**Updating...**", comment: "Updating webview message")
        static let errorMessage = NSLocalizedString("Webview.errorMessage", value: "**There was an error loading the content. Please try again.**", comment: "Webview loading error message")
        static let dismiss = NSLocalizedString("Webview.dismiss", value: "**Dismiss**", comment: "Dismiss button label")

    }

    enum TimeSince {
        static let seconds = NSLocalizedString("TimeSince.seconds", value: "**%1$@ s**", comment: "6 s (6 seconds)")
        static let minutes = NSLocalizedString("TimeSince.minutes", value: "**%1$@ m**", comment: "6 m (6 minutes)")
        static let hours = NSLocalizedString("TimeSince.hours", value: "**%1$@ h**", comment: "6 h (6 hours)")
        static let days = NSLocalizedString("TimeSince.days", value: "**%1$@ d**", comment: "6 d (6 days)")
    }

    enum Import {
        static let leftCaption = NSLocalizedString("Import.leftCaption", value: "**Wallet to be imported**", comment: "Caption for graphics")
        static let rightCaption = NSLocalizedString("Import.rightCaption", value: "**Your Litewallet Wallet**", comment: "Caption for graphics")
        static let importMessage = NSLocalizedString("Import.message", value: "**Importing a wallet transfers all the money from your other wallet into your Litewallet wallet using a single transaction.**", comment: "Import wallet intro screen message")
        static let importWarning = NSLocalizedString("Import.warning", value: "**Importing a wallet does not include transaction history or other details.**", comment: "Import wallet intro warning message")
        static let scan = NSLocalizedString("Import.scan", value: "**Scan Private Key**", comment: "Scan Private key button label")
        static let title = NSLocalizedString("Import.title", value: "**Import Wallet**", comment: "Import Wallet screen title")
        static let importing = NSLocalizedString("Import.importing", value: "**Importing Wallet**", comment: "Importing wallet progress view label")
        static let confirm = NSLocalizedString("Import.confirm", value: "**Send %1$@ from this private key into your wallet? The Litecoin network will receive a fee of %2$@.**", comment: "Sweep private key confirmation message")
        static let checking = NSLocalizedString("Import.checking", value: "**Checking private key balance...**", comment: "Checking private key balance progress view text")
        static let password = NSLocalizedString("Import.password", value: "**This private key is password protected.**", comment: "Enter password alert view title")
        static let passwordPlaceholder = NSLocalizedString("Import.passwordPlaceholder", value: "**password**", comment: "password textfield placeholder")
        static let unlockingActivity = NSLocalizedString("Import.unlockingActivity", value: "**Unlocking Key**", comment: "Unlocking Private key activity view message.")
        static let importButton = NSLocalizedString("Import.importButton", value: "**Import**", comment: "Import button label")
        static let success = NSLocalizedString("Import.success", value: "**Success**", comment: "Import wallet success alert title")
        static let successBody = NSLocalizedString("Import.SuccessBody", value: "**Successfully imported wallet.**", comment: "Successfully imported wallet message body")
        static let wrongPassword = NSLocalizedString("Import.wrongPassword", value: "**Wrong password, please try again.**", comment: "Wrong password alert message")
        enum Error {
            static let notValid = NSLocalizedString("Import.Error.notValid", value: "**Not a valid private key**", comment: "Not a valid private key error message")
            static let duplicate = NSLocalizedString("Import.Error.duplicate", value: "**This private key is already in your wallet.**", comment: "Duplicate key error message")
            static let empty = NSLocalizedString("Import.Error.empty", value: "**This private key is empty.**", comment: "empty private key error message")
            static let highFees = NSLocalizedString("Import.Error.highFees", value: "**Transaction fees would cost more than the funds available on this private key.**", comment: "High fees error message")
            static let signing = NSLocalizedString("Import.Error.signing", value: "**Error signing transaction**", comment: "Import signing error message")
        }
    }

    enum BitID {
        static let title = NSLocalizedString("BitID.title", value: "**BitID Authentication Request**", comment: "BitID Authentication Request alert view title")
        static let authenticationRequest = NSLocalizedString("BitID.authenticationRequest", value: "**%1$@ is requesting authentication using your Litecoin wallet**", comment: "<sitename> is requesting authentication using your Litecoin wallet")
        static let deny = NSLocalizedString("BitID.deny", value: "**Deny**", comment: "Deny button label")
        static let approve = NSLocalizedString("BitID.approve", value: "**Approve**", comment: "Approve button label")
        static let success = NSLocalizedString("BitID.success", value: "**Successfully Authenticated**", comment: "BitID success alert title")
        static let error = NSLocalizedString("BitID.error", value: "**Authentication Error**", comment: "BitID error alert title")
        static let errorMessage = NSLocalizedString("BitID.errorMessage", value: "**Please check with the service. You may need to try again.**", comment: "BitID error alert messaage")

    }
    
    enum Donate {
        static let title = NSLocalizedString("Donate.title", value: "**Donate to the Litecoin Foundation! %@**", comment: "Donate to the Litecoin Foundation")
        static let titleConfirmation = NSLocalizedString("Donate.title.confirmation", value: "**Confirm Donation**", comment: "Donate Confirmation")
        static let memo = NSLocalizedString("Donate.memo", value: "**Donation to the Litecoin Foundation**", comment: "Donate Memo")
        static let toThe = NSLocalizedString("Donate.toThe", value: "**Donate to the**", comment: "Donate articles to the")
        static let word = NSLocalizedString("Donate.word", value: "**Donate**", comment: "Donate")
    }

    enum WipeWallet {
        static let title = NSLocalizedString("WipeWallet.title", value: "**Start or Recover Another Wallet**", comment: "Wipe wallet navigation item title.")
        static let alertTitle = NSLocalizedString("WipeWallet.alertTitle", value: "**Wipe Wallet?**", comment: "Wipe wallet alert title")
        static let alertMessage = NSLocalizedString("WipeWallet.alertMessage", value: "**Are you sure you want to delete this wallet?**", comment: "Wipe wallet alert message")
        static let wipe = NSLocalizedString("WipeWallet.wipe", value: "**Wipe**", comment: "Wipe wallet button title")
        static let wiping = NSLocalizedString("WipeWallet.wiping", value: "**Wiping...**", comment: "Wiping activity message")
        static let failedTitle = NSLocalizedString("WipeWallet.failedTitle", value: "**Failed**", comment: "Failed wipe wallet alert title")
        static let failedMessage = NSLocalizedString("WipeWallet.failedMessage", value: "**Failed to wipe wallet.**", comment: "Failed wipe wallet alert message")
        static let instruction = NSLocalizedString("WipeWallet.instruction", value: "**To start a new wallet or restore an existing wallet, you must first erase the wallet that is currently installed. To continue, enter the current wallet's Paper Key.**", comment: "Enter key to wipe wallet instruction.")
        static let startMessage = NSLocalizedString("WipeWallet.startMessage", value: "**Starting or recovering another wallet allows you to access and manage a different Litewallet wallet on this device.**", comment: "Start wipe wallet view message")
        static let startWarning = NSLocalizedString("WipeWallet.startWarning", value: "**Your current wallet will be removed from this device. If you wish to restore it in the future, you will need to enter your Paper Key.**", comment: "Start wipe wallet view warning")
        static let emptyWallet = NSLocalizedString("WipeWallet.emptyWallet", value: "**Forget seed or PIN?**", comment: "Warning if user lost phrase")
        static let resetTitle = NSLocalizedString("resetTitle", value: "**Empty Wallet Reset**", comment: "Warning Empty Wipe title")
        static let resetButton = NSLocalizedString("resetButton", value: "**Yes, reset wallet**", comment: "Reset walet button  title")
        static let warningTitle = NSLocalizedString("WipeWallet.warningTitle", value: "**PLEASE READ!**", comment: "Warning title")
        static let warningDescription = NSLocalizedString("WipeWallet.warningDescription", value: "**Your LiteWallet is empty. Resetting will delete the old private key and wipe the app data.\n\nAfter the reset, be prepared to record the new 12 words and keep them in a very secure place.\n\nNo LiteWallet developers can retrieve this seed for you.**", comment: "Warning description")
        static let warningAlert = NSLocalizedString("WipeWallet.warningAlert", value: "**DO NOT LOSE IT!**", comment: "Warning Alert")
        static let deleteDatabase = NSLocalizedString("WipeWallet.deleteDatabase", value: "**Delete database**", comment: "Delete db")
        static let alertDeleteTitle = NSLocalizedString("WipeWallet.alertDeleteTitle", value: "**Delet Database**", comment: "Delete database title")
        static let deleteMessageTitle = NSLocalizedString("WipeWallet.deleteMessageTitle", value: "**This deletes the database but retains the PIN and phrase. You will be asked to confirm your existing PIN, seed and will re-sync the new db**", comment: "Delete database message")
        static let deleteSync = NSLocalizedString("WipeWallet.deleteSync", value: "**Delete & Sync**", comment: "Delete and sync")



    }

    enum FeeSelector {
        static let title = NSLocalizedString("FeeSelector.title", value: "**Processing Speed**", comment: "Fee Selector title")
        static let regularLabel = NSLocalizedString("FeeSelector.regularLabel", value: "**Estimated Delivery: 2.5 - 5+ minutes**", comment: "Fee Selector regular fee description")
        static let economyLabel = NSLocalizedString("FeeSelector.economyLabel", value: "**Estimated Delivery: ~10 minutes**", comment: "Fee Selector economy fee description")
        static let luxuryLabel = NSLocalizedString("FeeSelector.luxuryLabel", value: "**Delivery: 2.5 - 5+  minutes**", comment: "Fee Selector luxury fee description")
        static let economyWarning = NSLocalizedString("FeeSelector.economyWarning", value: "**This option is not recommended for time-sensitive transactions.**", comment: "Warning message for economy fee")
        static let luxuryMessage = NSLocalizedString("FeeSelector.luxuryMessage", value: "**This option virtually guarantees acceptance of your transaction while you pay a premium.**", comment: "Message for luxury fee")

        static let regular = NSLocalizedString("FeeSelector.regular", value: "**Regular**", comment: "Regular fee")
        static let economy = NSLocalizedString("FeeSelector.economy", value: "**Economy**", comment: "Economy fee")
        static let luxury = NSLocalizedString("FeeSelector.luxury", value: "**Luxury**", comment: "Luxury fee")

    }

    enum Confirmation {
        static let title = NSLocalizedString("Confirmation.title", value: "**Confirmation**", comment: "Confirmation Screen title")
        static let send = NSLocalizedString("Confirmation.send", value: "**Send**", comment: "Send: (amount)")
        static let to = NSLocalizedString("Confirmation.to", value: "**To**", comment: "To: (address)")
        static let staticAddressLabel = NSLocalizedString("Confirmation.staticAddressLabel", value: "**ADDRESS:**", comment: "Address label")

        static let processingTime = NSLocalizedString("Confirmation.processingTime", value: "**Processing time: This transaction will take %1$@ minutes to process.**", comment: "eg. Processing time: This transaction will take 10-30 minutes to process.")
         static let processingAndDonationTime = NSLocalizedString("Confirmation.processingAndDonationTime", value: "**Processing time: These transactions will take %1$@ minutes to process.**", comment: "eg. Processing with Donation time: This transaction will take 10-30 minutes to process.")
        static let amountLabel = NSLocalizedString("Confirmation.amountLabel", value: "**Amount to Send:**", comment: "Amount to Send: ($1.00)")
        static let donateLabel = NSLocalizedString("Confirmation.donateLabel", value: "**Amount to Donate:**", comment: "Amount to Donate: ($1.00)")
        static let feeLabel = NSLocalizedString("Confirmation.feeLabel", value: "**Network Fee:**", comment: "Network Fee: ($1.00)")
        static let shortFeeLabel = NSLocalizedString("Confirmation.shortFeeLabel", value: "**FEE:**", comment: "Short Network Fee: ($1.00)")
        static let totalLabel = NSLocalizedString("Confirmation.totalLabel", value: "**Total Cost:**", comment: "Total Cost: ($5.00)")
        static let amountDetailLabel = NSLocalizedString("Confirmation.amountDetailLabel", value: "**Exchange details:**", comment: "$53.09/L + 1.07%")
    }

    enum BCH {
        static let title = NSLocalizedString("BCH.title", value: "**Withdraw BCH**", comment: "Widthdraw BCH view title")
        static let body = NSLocalizedString("BCH.body", value: "**Enter a destination BCH address below. All BCH in your wallet at the time of the fork (%1$@) will be sent.**", comment: "Send BCH view body.")
        static let txHashHeader = NSLocalizedString("BCH.txHashHeader", value: "**BCH Transaction ID**", comment: "Tx Hash button header")
        static let paymentProtocolError = NSLocalizedString("BCH.paymentProtocolError", value: "**Payment Protocol Requests are not supported for BCH transactions**", comment: "Attempted to scan unsupported qr code error message.")
        static let noAddressError = NSLocalizedString("BCH.noAddressError", value: "**Please enter an address**", comment: "No address error message")
        static let confirmationTitle = NSLocalizedString("BCH.confirmationTitle", value: "**Confirmation**", comment: "Confirmation alert title")
        static let confirmationMessage = NSLocalizedString("BCH.confirmationMessage", value: "**Confirm sending %1$@ to %2$@**", comment: "Confirm sending <$5.00> to <address>?")
        static let successMessage = NSLocalizedString("BCH.successMessage", value: "**BCH was successfully sent.**", comment: "BCH successfully sent alert message")
        static let hashCopiedMessage = NSLocalizedString("BCH.hashCopiedMessage", value: "**Transaction ID copied**", comment: "Transaction ID copied message")
        static let genericError = NSLocalizedString("BCH.genericError", value: "**Your account does not contain any BCH, or you received BCH after the fork.**", comment: "Generic bch erorr message")
    }

    enum NodeSelector {
        static let manualButton = NSLocalizedString("NodeSelector.manualButton", value: "**Switch to Manual Mode**", comment: "Switch to manual mode button label")
        static let automaticButton = NSLocalizedString("NodeSelector.automaticButton", value: "**Switch to Automatic Mode**", comment: "Switch to automatic mode button label")
        static let title = NSLocalizedString("NodeSelector.title", value: "**Litecoin Nodes**", comment: "Node Selector view title")
        static let nodeLabel = NSLocalizedString("NodeSelector.nodeLabel", value: "**Current Primary Node**", comment: "Node address label")
        static let statusLabel = NSLocalizedString("NodeSelector.statusLabel", value: "**Node Connection Status**", comment: "Node status label")
        static let connected = NSLocalizedString("NodeSelector.connected", value: "**Connected**", comment: "Node is connected label")
        static let notConnected = NSLocalizedString("NodeSelector.notConnected", value: "**Not Connected**", comment: "Node is not connected label")
        static let enterTitle = NSLocalizedString("NodeSelector.enterTitle", value: "**Enter Node**", comment: "Enter Node ip address view title")
        static let enterBody = NSLocalizedString("NodeSelector.enterBody", value: "**Enter Node IP address and port (optional)**", comment: "Enter node ip address view body")
    }

    enum Welcome {
        static let title = NSLocalizedString("Welcome.title", value: "**Welcome to Litewallet**", comment: "Welcome view title")
        static let body = NSLocalizedString("Welcome.body", value: "**Litewallet now has a brand new look and some new features.\n\nAll coins are displayed in lites (ł). 1 Litecoin (Ł) = 1000 lites (ł).**", comment: "Welcome view body text")
    }
}
