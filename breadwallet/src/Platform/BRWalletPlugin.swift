//
//  BRWalletPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/18/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

// swiftlint:disable cyclomatic_complexity

enum PlatformAuthResult {
    case success(String?)
    case cancelled
    case failed
}

class BRWalletPlugin: BRHTTPRouterPlugin, BRWebSocketClient, Trackable {
    var sockets = [String: BRWebSocket]()
    let walletAuthenticator: TransactionAuthenticator
    private var tempAuthResponses = [String: Int]()
    private var tempAuthResults = [String: Bool]()
    private var isPresentingAuth = false

    init(walletAuthenticator: TransactionAuthenticator) {
        self.walletAuthenticator = walletAuthenticator
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
                        if self.walletAuthenticator.isBiometricsEnabledForUnlocking {
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
                guard let wallet = currency.wallet else { return BRHTTPResponse(request: req, code: 404) }
                // prefer legacy addresses for now until platforms support segwit
                let address = currency.isBitcoin ? wallet.receiveAddress(for: .btcLegacy) : wallet.receiveAddress
                response.append(["currency": currency.code,
                                 "address": address])
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

            guard let wallet = Store.state[currency]?.wallet,
            let kvStore = Backend.kvStore else { return BRHTTPResponse(request: request, code: 500) }
            let sender = Sender(wallet: wallet, authenticator: self.walletAuthenticator, kvStore: kvStore)

            // assume the numerator is in currency's base units
            let amount = Amount(tokenString: numerator, currency: currency, unit: currency.baseUnit)
            
            // estimateFee() will only use .priority if multiple fee levels are available (e.g. for BTC)
            let tradeFeeLevel: FeeLevel = .priority
            
            // Fee estimation is asynchronous, so wrap the estimation related processing in a synchronous
            // block. This ensures that we don't set the response value and return `asyncResp` until
            // all transaction processing has completed.
            DispatchQueue.main.sync {
                CFRunLoopPerformBlock(RunLoop.main.getCFRunLoop(), CFRunLoopMode.commonModes.rawValue) {

                    wallet.estimateFee(address: toAddress, amount: amount, fee: tradeFeeLevel, completion: { (feeBasis) in
                        guard let transferFeeBasis = feeBasis else {
                            request.queue.async { asyncResp.provide(500, json: ["error": "fee-error"]) }
                            return
                        }
                        
                        let result = sender.createTransaction(address: toAddress, amount: amount, feeBasis: transferFeeBasis, comment: comment)
                        guard case .ok = result else {
                            request.queue.async { asyncResp.provide(500, json: ["error": "tx-error"]) }
                            return
                        }
                        
                        if shouldTransmit != 0 {
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
                            
                            let feeCurrency = sender.wallet.feeCurrency
                            let confirmAmount = Amount(amount: amount,
                                                       rate: nil,
                                                       maximumFractionDigits: Amount.highPrecisionDigits)
                            let feeAmount = Amount(cryptoAmount: transferFeeBasis.fee,
                                                   currency: feeCurrency,
                                                   rate: nil,
                                                   minimumFractionDigits: nil,
                                                   maximumFractionDigits: Amount.highPrecisionDigits)
                            
                            self.isPresentingAuth = true
                            Store.trigger(name: .confirmTransaction(currency, confirmAmount, feeAmount, tradeFeeLevel, toAddress, { (confirmed) in
                                self.isPresentingAuth = false
                                guard confirmed else { return request.queue.async { asyncResp.provide(403) } }
                                
                                sender.sendTransaction(allowBiometrics: false, pinVerifier: pinVerifier) { result in
                                    switch result {
                                    case .success(let hash, _):
                                        guard let hash = hash else { return request.queue.async { asyncResp.provide(500) } }
                                        request.queue.async { asyncResp.provide(200, json: ["hash": hash.withHexPrefix,
                                                                                            "transaction": "",
                                                                                            "transmitted": true]) }
                                    default:
                                        request.queue.async { asyncResp.provide(500) }
                                    }
                                }
                            }))
                            
                        } else {
                            request.queue.async { asyncResp.provide(501) }
                        }
                        
                    })  // wallet.estimateFee()
                }
            }
            
            // return the response to the post()
            return asyncResp
            
        } // router.post() {}
    } // hook()
    
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
        d["no_wallet"] = walletAuthenticator.noWallet
        guard let btcWalletState = Currencies.btc.state, let wallet = btcWalletState.wallet else {
            return d
        }
        d["receive_address"] = wallet.receiveAddress(for: .btcLegacy) // TODO: use segwit address when platform adds support
            //d["watch_only"] = TODO - add watch only
        d["btc_denomination_digits"] = btcWalletState.currency.defaultUnit.decimals
        d["local_currency_code"] = Store.state.defaultCurrencyCode
        let amount = Amount(tokenString: "0",
                            currency: btcWalletState.currency,
                            rate: btcWalletState.currentRate)
        d["local_currency_precision"] = amount.localFormat.maximumFractionDigits
        d["local_currency_symbol"] = amount.localFormat.currencySymbol
        return d
    }
    
    func currencyInfo(_ currency: Currency, fiatCode: String?) -> [String: Any] {
        var d = [String: Any]()
        d["id"] = currency.code
        d["ticker"] = currency.code
        d["name"] = currency.name
        d["colors"] = [currency.colors.0.toHex, currency.colors.1.toHex]
        if let balance = currency.state?.balance {
            var numerator = balance.tokenUnformattedString(in: currency.baseUnit)
            var denomiator = Amount(tokenString: "1", currency: currency, unit: currency.defaultUnit).tokenUnformattedString(in: currency.baseUnit)
            d["balance"] = ["currency": currency.code,
                            "numerator": numerator,
                            "denominator": denomiator]
                    
            if let rate = currency.state?.currentRate {
                let amount = Amount(amount: balance, rate: currency.state?.currentRate)
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
