//
//  BRWalletPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/18/16.
//  Copyright (c) 2016 breadwallet LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import BRCore

// swiftlint:disable cyclomatic_complexity

enum PlatformAuthResult {
    case success(String?)
    case cancelled
    case failed
}

class BRWalletPlugin: BRHTTPRouterPlugin, BRWebSocketClient, Trackable {
    var sockets = [String: BRWebSocket]()
    let walletAuthenticator: TransactionAuthenticator
    let walletManagers: [String: WalletManager]
    var tempBitIDKeys = [String: BRKey]() // this should only ever be mutated from the main thread
    private var tempBitIDResponses = [String: Int]()
    private var tempAuthResponses = [String: Int]()
    private var tempAuthResults = [String: Bool]()
    private var isPresentingAuth = false
    private var btcWalletManager: BTCWalletManager? {
        return walletManagers[Currencies.btc.code] as? BTCWalletManager
    }

    init(walletAuthenticator: TransactionAuthenticator, walletManagers: [String: WalletManager]) {
        self.walletAuthenticator = walletAuthenticator
        self.walletManagers = walletManagers
    }
    
    func announce(_ json: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
            let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) {
            for sock in sockets {
                sock.1.send(String(jsonString))
            }
        } else {
            print("[BRWalletPlugin] announce() could not encode payload: \(json)")
        }
    }

    func hook(_ router: BRHTTPRouter) {
        router.websocket("/_wallet/_socket", client: self)

        router.get("/_wallet/info") { (request, _) -> BRHTTPResponse in
            return try BRHTTPResponse(request: request, code: 200, json: self.walletInfo())
        }
 
        router.get("/_wallet/format") { (request, _) -> BRHTTPResponse in
            if let amounts = request.query["amount"], !amounts.isEmpty {
                let amount = amounts[0]
                
                //TODO: multi-currency support
                var intAmount: UInt64 = 0
                if amount.contains(".") { // assume full bitcoins
                    if let x = Float(amount) {
                        intAmount = UInt64(x * 100000000.0)
                    }
                } else {
                    if let x = UInt64(amount) {
                        intAmount = x
                    }
                }
                return try BRHTTPResponse(request: request, code: 200, json: self.currencyFormat(intAmount))
            } else {
                return BRHTTPResponse(request: request, code: 400)
            }
        }
        
        // POST /_wallet/sign_bitid
        //
        // Sign a message using the user's BitID private key. Calling this WILL trigger authentication
        //
        // Request body: application/json
        //      {
        //          "prompt_string": "Sign in to My Service", // shown to the user in the authentication prompt
        //          "string_to_sign": "https://bitid.org/bitid?x=2783408723", // the string to sign
        //          "bitid_url": "https://bitid.org/bitid", // the bitid url for deriving the private key
        //          "bitid_index": "0" // the bitid index as a string (just pass "0")
        //      }
        //
        // Response body: application/json
        //      {
        //          "signature": "oibwaeofbawoefb" // base64-encoded signature
        //      }
        router.post("/_wallet/sign_bitid") { (request, _) -> BRHTTPResponse in
            guard let cts = request.headers["content-type"], cts.count == 1 && cts[0] == "application/json" else {
                return BRHTTPResponse(request: request, code: 400)
            }
            guard !self.isPresentingAuth else {
                return BRHTTPResponse(request: request, code: 423)
            }

            guard let data = request.body(),
                      let j = try? JSONSerialization.jsonObject(with: data, options: []),
                      let json = j as? [String: String],
                      let stringToSign = json["string_to_sign"],
                      let bitidUrlString = json["bitid_url"],
                      let bitidUrl = URL(string: bitidUrlString),
                      let bii = json["bitid_index"],
                      let bitidIndex = Int(bii) else {
                return BRHTTPResponse(request: request, code: 400)
            }
            if let response = self.tempBitIDResponses[stringToSign] {
                return BRHTTPResponse(request: request, code: response)
            }
            let asyncResp = BRHTTPResponse(async: request)
            DispatchQueue.main.sync {
                CFRunLoopPerformBlock(RunLoop.main.getCFRunLoop(), CFRunLoopMode.commonModes.rawValue) {
                    let url = bitidUrl.host ?? bitidUrl.absoluteString
                    if let key = self.tempBitIDKeys[url] {
                        self.sendBitIDResponse(stringToSign, usingKey: key, request: request, asyncResp: asyncResp)
                    } else {
                        let prompt = bitidUrl.host ?? bitidUrl.description
                        self.isPresentingAuth = true
                        if UserDefaults.isBiometricsEnabled {
                            asyncResp.provide(200, json: ["error": "proxy-shutdown"])
                        }
                        Store.trigger(name: .authenticateForPlatform(prompt, true, { [weak self] result in
                            guard let `self` = self else { request.queue.async { asyncResp.provide(500) }; return }
                            self.isPresentingAuth = false
                            switch result {
                            case .success:
                                if let key = self.walletAuthenticator.buildBitIdKey(url: url, index: bitidIndex) {
                                    self.addKeyToCache(key, url: url)
                                    self.sendBitIDResponse(stringToSign, usingKey: key, request: request, asyncResp: asyncResp)
                                } else {
                                    self.tempBitIDResponses[stringToSign] = 401
                                    request.queue.async { asyncResp.provide(401) }
                                }
                            case .cancelled:
                                self.tempBitIDResponses[stringToSign] = 403
                                request.queue.async { asyncResp.provide(403) }
                            case .failed:
                                self.tempBitIDResponses[stringToSign] = 401
                                request.queue.async { asyncResp.provide(401) }
                            }
                        }))
                    }
                }
            }
            return asyncResp
        }

        // POST /_wallet/authenticate
        //
        // Calling this WILL trigger authentication
        //
        // Request body: application/json
        //      {
        //          "prompt": "Sign in to My Service", // shown to the user in the authentication prompt
        //          "id": "<uuid>" //a uuid used as a key to cache responses
        //      }
        //
        // Response body: application/json
        //      {
        //          "authenticated": true|false
        //      }

        router.post("/_wallet/authenticate") { (request, _) -> BRHTTPResponse in
            guard let cts = request.headers["content-type"], cts.count == 1 && cts[0] == "application/json" else {
                return BRHTTPResponse(request: request, code: 400)
            }
            guard !self.isPresentingAuth else {
                return BRHTTPResponse(request: request, code: 423)
            }

            guard let data = request.body(),
                let j = try? JSONSerialization.jsonObject(with: data, options: []),
                let json = j as? [String: String],
                let id = json["id"],
                let prompt = json["prompt"] else {
                    return BRHTTPResponse(request: request, code: 400)
            }
            if let response = self.tempAuthResponses[id] {
                return BRHTTPResponse(request: request, code: response)
            }
            let asyncResp = BRHTTPResponse(async: request)
            DispatchQueue.main.sync {
                CFRunLoopPerformBlock(RunLoop.main.getCFRunLoop(), CFRunLoopMode.commonModes.rawValue) {
                    if let result = self.tempAuthResults[id], result == true {
                        asyncResp.provide(200, json: ["authenticated": true])
                    } else {
                        self.isPresentingAuth = true
                        if UserDefaults.isBiometricsEnabled {
                            asyncResp.provide(200, json: ["error": "proxy-shutdown"])
                        }
                        Store.trigger(name: .authenticateForPlatform(prompt, true, { [weak self] result in
                            self?.isPresentingAuth = false
                            switch result {
                            case .success:
                                self?.tempAuthResults[id] = true
                                request.queue.async { asyncResp.provide(200, json: ["authenticated": true] )}
                            case .cancelled:
                                self?.tempAuthResponses[id] = 403
                                request.queue.async { asyncResp.provide(403, json: ["authenticated": false]) }
                            case .failed:
                                self?.tempAuthResponses[id] = 401
                                request.queue.async { asyncResp.provide(401, json: ["authenticated": false]) }
                            }
                        }))
                    }
                }
            }
            return asyncResp
        }
        
        router.post("/_event/(name)") { (req, m) -> BRHTTPResponse in
            guard let nameArray = m["name"], nameArray.count == 1 else {
                return BRHTTPResponse(request: req, code: 400)
            }
            let name = nameArray[0]
            if let body = req.body(), !body.isEmpty {
                guard let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: String] else {
                    return BRHTTPResponse(request: req, code: 400)
                }
                self.saveEvent(name, attributes: json)
            } else {
                self.saveEvent(name)
            }
            return BRHTTPResponse(request: req, code: 200)
        }
        
        router.get("/_wallet/version") { (req, _) -> BRHTTPResponse in
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""
            return try BRHTTPResponse(request: req, code: 200, json: ["version": version, "build": build])
        }
        
        // POST /_wallet/currencies
        //
        // Returns all currency details
        //
        // Response body: application/json
        //      {
        //          "id": "BTC" // ticker code
        //          "ticker": "BTC"
        //          "name": "Bitcoin"
        //          "balance": {
        //              "numerator": "10000",
        //              "denominator": "100000000",
        //              "currency": "BTC",
        //          }
        //          "exchange": {
        //              "numerator": "10000",
        //              "denominator": "100000000",
        //              "currency": "JPY", // current fiat exchange rate
        //          }
        //          "colors": ["#000000","#ffffff"] // array of 2 colors in hex
        //      }
        router.get("/_wallet/currencies") { (req, _) -> BRHTTPResponse in
            let fiatCode = req.query["fiat"]?.first
            var response = [[String: Any]]()
            for currency in Store.state.currencies {
                response.append(self.currencyInfo(currency, fiatCode: fiatCode))
            }
            return try BRHTTPResponse(request: req, code: 200, json: response)
        }
        
        // POST /_wallet/addresses/<currency_code>
        //
        // Returns the receive addresses of the given wallet
        //
        // Response body: application/json
        //      {
        //          "currency": "btc"
        //          "address": "1abcd..." // receive address
        //      }
        router.get("/_wallet/addresses/(code)") { (req, m) -> BRHTTPResponse in
            var code: String?
            if let codeArray = m["code"] {
                guard codeArray.count == 1 else {
                    return BRHTTPResponse(request: req, code: 400)
                }
                code = codeArray.first!
            }
            var response = [[String: Any]]()
            let currencies = Store.state.currencies.filter { code == nil || $0.code.lowercased() == code!.lowercased() }
            for currency in currencies {
                // prefer legacy addresses for now until platforms support segwit
                if let address = Store.state[currency]?.legacyReceiveAddress ?? Store.state[currency]?.receiveAddress {
                    response.append(["currency": currency.code,
                                     "address": address])
                }
            }
            return try BRHTTPResponse(request: req, code: 200, json: (response.count == 1) ? response.first! : response)
        }
        
        // POST /_wallet/transaction
        //
        // Creates and optionally sends a transaction
        //
        // Request body: application/json
        //      {
        //          "toAddress": "0x1234...",
        //          "toDescription": "memo", // memo field contents
        //          "currency": "eth", // currency code
        //          "amount": {
        //              "numerator": "10000",
        //              "denominator": "100000000",
        //              "currency": "eth",
        //          }
        //          "transmit": 1 // should transmit or not
        //      }
        //
        // Response body: application/json
        //      {
        //          "hash": "0x123...", // transaction hash
        //          "transaction: "0xffff..." // raw transaction hex encoded
        //          "transmitted": true
        //      }
        router.post("/_wallet/transaction") { (request, _) -> BRHTTPResponse in
            guard !self.isPresentingAuth else {
                return BRHTTPResponse(request: request, code: 423)
            }
            
            let asyncResp = BRHTTPResponse(async: request)
            
            guard let data = request.body(),
                let j = try? JSONSerialization.jsonObject(with: data, options: []),
                let json = j as? [String: Any],
                let toAddress = json["toAddress"] as? String,
                let comment = json["toDescription"] as? String,
                let currencyCode = json["currency"] as? String,
                let shouldTransmit = json["transmit"] as? Int,
                let amt = json["amount"] as? [String: String],
                let numerator = amt["numerator"],
                currencyCode.lowercased() == amt["currency"]?.lowercased(),
                let currency = Store.state.currencies.filter({$0.code.lowercased() == currencyCode.lowercased()}).first,
                currency.isValidAddress(toAddress) else {
                    asyncResp.provide(400, json: ["error": "params-error"])
                    return asyncResp
            }
            
            guard let walletManager = self.walletManagers[currency.code],
                let kvStore = Backend.kvStore,
                let sender = currency.createSender(authenticator: self.walletAuthenticator, walletManager: walletManager, kvStore: kvStore) else {
                    return BRHTTPResponse(request: request, code: 500)
            }
            
            // assume the numerator is in currency's base units
            var amount = UInt256(string: numerator, radix: 10)
            
            // ensure priority fee set for bitcoin transactions
            if currency.matches(Currencies.btc) {
                guard let fees = currency.state?.fees else {
                    asyncResp.provide(400, json: ["error": "fee-error"])
                    return asyncResp
                }
                sender.updateFeeRates(fees, toLevel: .priority)
            }

            guard let fee = sender.fee(forAmount: amount),
                let balance = currency.state?.balance else {
                    asyncResp.provide(500, json: ["error": "fee-error"])
                    return asyncResp
            }
            
            if !(currency is ERC20Token) && (amount <= balance) && (amount + fee) > balance {
                // amount is close to balance and fee puts it over, subtract the fee
                amount -= fee
            }
            
            let result = sender.createTransaction(address: toAddress, amount: amount, comment: comment)
            guard case .ok = result else {
                asyncResp.provide(400, json: ["error": "tx-error"])
                return asyncResp
            }
            
            if shouldTransmit != 0 {
                DispatchQueue.walletQueue.async {
                    self.walletManagers[currency.code]?.peerManager?.connect()
                }
                
                let pinVerifier: PinVerifier = { [weak self] pinValidationCallback in
                    let prompt = S.VerifyPin.authorize
                    self?.isPresentingAuth = true
                    Store.trigger(name: .authenticateForPlatform(prompt, false, { [weak self] result in
                        self?.isPresentingAuth = false
                        switch result {
                        case .success(let pin?):
                            pinValidationCallback(pin)
                        case .cancelled:
                            request.queue.async { asyncResp.provide(403) }
                        default:
                            request.queue.async { asyncResp.provide(401) }
                        }
                    }))
                }
                
                let fee = sender.fee(forAmount: amount) ?? UInt256(0)
                let feeCurrency = (currency is ERC20Token) ? Currencies.eth : currency
                let confirmAmount = Amount(amount: amount,
                                           currency: currency,
                                           rate: nil, //currency.state?.currentRate,
                                           maximumFractionDigits: Amount.highPrecisionDigits)
                let feeAmount = Amount(amount: fee,
                                       currency: feeCurrency,
                                       rate: nil, //feeCurrency.state?.currentRate,
                                       maximumFractionDigits: Amount.highPrecisionDigits)
                
                DispatchQueue.main.sync {
                    CFRunLoopPerformBlock(RunLoop.main.getCFRunLoop(), CFRunLoopMode.commonModes.rawValue) {
                        self.isPresentingAuth = true
                        Store.trigger(name: .confirmTransaction(currency, confirmAmount, feeAmount, toAddress, { (confirmed) in
                            self.isPresentingAuth = false
                            guard confirmed else { return request.queue.async { asyncResp.provide(403) } }
                            
                            sender.sendTransaction(allowBiometrics: false, pinVerifier: pinVerifier, abi: nil, completion: { result in
                                switch result {
                                case .success(let hash, let rawTx):
                                    guard let hash = hash, let rawTx = rawTx else { return request.queue.async { asyncResp.provide(500) } }
                                    request.queue.async { asyncResp.provide(200, json: ["hash": hash.withHexPrefix,
                                                                                        "transaction": rawTx.withHexPrefix,
                                                                                        "transmitted": true]) }
                                default:
                                    request.queue.async { asyncResp.provide(500) }
                                }
                            })
                        }))
                    }
                }
            } else {
                asyncResp.provide(501)
                // TODO: sign tx without sending, get tx data / hash
                //                asyncResp.provide(200, json: ["hash": "",
                //                                              "transaction": "",
                //                                              "transmitted": false])
            }
            return asyncResp
        }
    }

    private func addKeyToCache(_ key: BRKey, url: String) {
        self.tempBitIDKeys[url] = key
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(60)) {
            self.tempBitIDKeys[url] = nil
        }
    }

    private func sendBitIDResponse(_ stringToSign: String, usingKey key: BRKey, request: BRHTTPRequest, asyncResp: BRHTTPResponse) {
        var key = key
        let sig = BRBitID.signMessage(stringToSign, usingKey: key)
        let json: [String: Any] = [
            "signature": sig,
            "address": key.address(legacy: true) ?? ""
        ]
        request.queue.async {
            asyncResp.provide(200, json: json)
        }
    }
    
    // MARK: - socket handlers
    func sendWalletInfo(_ socket: BRWebSocket) {
        var d = self.walletInfo()
        d["type"] = "wallet"
        if let jdata = try? JSONSerialization.data(withJSONObject: d, options: []),
            let jstring = NSString(data: jdata, encoding: String.Encoding.utf8.rawValue) {
            socket.send(String(jstring))
        }
    }
    
    func socketDidConnect(_ socket: BRWebSocket) {
        print("WALLET CONNECT \(socket.id)")
        sockets[socket.id] = socket
        sendWalletInfo(socket)
    }
    
    func socketDidDisconnect(_ socket: BRWebSocket) {
        print("WALLET DISCONNECT \(socket.id)")
        sockets.removeValue(forKey: socket.id)
    }
    
    func socket(_ socket: BRWebSocket, didReceiveText text: String) {
        print("WALLET RECV \(text)")
        socket.send(text)
    }
    
    public func socket(_ socket: BRWebSocket, didReceiveData data: Data) {
        // nothing to do here
    }
}

extension BRWalletPlugin {
    // MARK: - basic wallet functions
    func walletInfo() -> [String: Any] {
        var d = [String: Any]()
        guard let walletManager = btcWalletManager else { return d }
        d["no_wallet"] = walletAuthenticator.noWallet
        if let wallet = walletManager.wallet {
            d["receive_address"] = wallet.legacyReceiveAddress // TODO: use segwit address when platform adds support
            //d["watch_only"] = TODO - add watch only
        }
        d["btc_denomination_digits"] = walletManager.currency.state?.maxDigits
        d["local_currency_code"] = Store.state.defaultCurrencyCode
        let amount = Amount(amount: UInt256(0), currency: Currencies.btc, rate: Currencies.btc.state?.currentRate)
        d["local_currency_precision"] = amount.localFormat.maximumFractionDigits
        d["local_currency_symbol"] = amount.localFormat.currencySymbol
        return d
    }
    
    //TODO: multi-currency support
    func currencyFormat(_ amount: UInt64) -> [String: Any] {
        var d = [String: Any]()
        guard let walletManager = btcWalletManager else { return d }
        if let rate = walletManager.currency.state?.currentRate {
            let amount = Amount(amount: UInt256(amount),
                                currency: walletManager.currency,
                                rate: rate)
            d["local_currency_amount"] = amount.fiatDescription
            d["currency_amount"] = amount.tokenDescription
        }
        return d
    }
    
    func currencyInfo(_ currency: Currency, fiatCode: String?) -> [String: Any] {
        var d = [String: Any]()
        d["id"] = currency.code
        d["ticker"] = currency.code
        d["name"] = currency.name
        d["colors"] = [currency.colors.0.toHex, currency.colors.1.toHex]
        if let balance = currency.state?.balance {
            var numerator = balance.string(radix: 10)
            var denomiator = UInt256(power: currency.commonUnit.decimals).string(radix: 10)
            d["balance"] = ["currency": currency.code,
                            "numerator": numerator,
                            "denominator": denomiator]
        
            var rate: Rate?
            if let code = fiatCode {
                rate = currency.state?.rates.filter({ $0.code == code }).first
            } else {
                rate = currency.state?.currentRate
            }
            
            if let rate = rate {
                let amount = Amount(amount: balance, currency: currency, rate: currency.state?.currentRate)
                let decimals = amount.localFormat.maximumFractionDigits
                let denominatorValue = (pow(10, decimals) as NSDecimalNumber).doubleValue
                
                let fiatValue = (amount.fiatValue as NSDecimalNumber).doubleValue
                numerator = String(Int(fiatValue * denominatorValue))
                denomiator = String(Int(denominatorValue))
                d["fiatBalance"] = ["currency": rate.code,
                                    "numerator": numerator,
                                    "denominator": denomiator]
                
                let rateValue = rate.rate
                numerator = String(Int(rateValue * denominatorValue))
                denomiator = String(Int(denominatorValue))
                d["exchange"] = ["currency": rate.code,
                                 "numerator": numerator,
                                 "denominator": denomiator]
            }
        }
        return d
    }
}
