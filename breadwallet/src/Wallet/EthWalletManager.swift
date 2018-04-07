//
//  EthWalletManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-04.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import BRCore.Ethereum

class EthWalletManager : WalletManager {
    static let defaultGasLimit: UInt64 = 48000

    var peerManager: BRPeerManager?
    var wallet: BRWallet?
    var currency: CurrencyDef = Currencies.eth
    var kvStore: BRReplicatedKVStore?
    var apiClient: BRAPIClient?
    var address: String?
    var gasPrice: UInt256 = 0
    var walletID: String?
    
    var tokens: [ERC20Token] = []

    var ethAddress: BREthereumAddress?
    var account: BREthereumAccount?
    var ethWallet: BREthereumWallet?
    private var timer: Timer? = nil
    private let updateInterval: TimeInterval = 5
    private var pendingTransactions = [EthTx]()

    init() {
        guard let pubKey = ethPubKey else { return }
        self.account = createAccountWithPublicKey(pubKey)
        guard account != nil else { return }
        self.ethAddress = accountGetPrimaryAddress(self.account)
        self.ethWallet = walletCreate(account, E.isTestnet ? ethereumTestnet : ethereumMainnet)
        if let address = addressAsString(self.ethAddress) {
            if let address = String(cString: address, encoding: .utf8) {
                self.address = address
                Store.perform(action: WalletChange(self.currency).set(self.currency.state.mutate(receiveAddress: address)))
            }
        }
        if let walletID = getWalletID() {
            self.walletID = walletID
            print("walletID:", walletID)
        }
        DispatchQueue.main.async { [weak self] in
            guard let myself = self else { return }
            myself.timer = Timer.scheduledTimer(timeInterval: myself.updateInterval, target: myself, selector: #selector(myself.refresh), userInfo: nil, repeats: true)
        }
    }

    @objc private func refresh() {
        updateBalance()
        updateTransactionList()
        
        updateTokenBalances()
    }

    func updateBalance() {
        guard let address = address else { return }
        apiClient?.getBalance(address: address, handler: { result in
            switch result {
            case .success(let value):
                Store.perform(action: WalletChange(self.currency).setBalance(value))
            case .error(let error):
                print("getBalance error: \(error.localizedDescription)")
            }
        })
    }

    func updateTransactionList() {
        guard let address = address else { return }
        apiClient?.getEthTxList(address: address, handler: { [weak self] result in
            guard let `self` = self else { return }
            guard case .success(let txList) = result else { return }
            for tx in txList {
                if let index = self.pendingTransactions.index(where: { $0.hash == tx.hash }) {
                    self.pendingTransactions.remove(at: index)
                }
            }
            let transactions = (self.pendingTransactions + txList).map { EthTransaction(tx: $0, accountAddress: address, kvStore: self.kvStore, rate: self.currency.state.currentRate) }
            Store.perform(action: WalletChange(self.currency).setTransactions(transactions))
        })
    }

    func sendTx(toAddress: String, amount: UInt256, callback: @escaping (JSONRPCResult<EthTx>)->Void) {
        guard var privKey = BRKey(privKey: ethPrivKey!) else { return }
        privKey.compressed = 0
        defer { privKey.clean() }
        let ethToAddress = createAddress(toAddress)
        let ethAmount = amountCreateEther((etherCreate(amount)))
        let gasPrice = gasPriceCreate((etherCreate(self.gasPrice)))
        let gasLimit = gasCreate(EthWalletManager.defaultGasLimit)
        let nonce = getNonce()
        let tx = walletCreateTransactionDetailed(ethWallet, ethToAddress, ethAmount, gasPrice, gasLimit, nonce)
        walletSignTransactionWithPrivateKey(ethWallet, tx, privKey)
        let txString = walletGetRawTransactionHexEncoded(ethWallet, tx, "0x")
        apiClient?.sendRawTransaction(rawTx: String(cString: txString!, encoding: .utf8)!, handler: { result in
            switch result {
            case .success(let txHash):
                let pendingTx = EthTx(blockNumber: 0,
                                      timeStamp: Date().timeIntervalSince1970,
                                      value: amount,
                                      gasPrice: gasPrice.etherPerGas.valueInWEI,
                                      gasLimit: gasLimit.amountOfGas,
                                      gasUsed: 0,
                                      from: self.address!,
                                      to: toAddress,
                                      confirmations: 0,
                                      nonce: UInt64(nonce),
                                      hash: txHash,
                                      isError: false)
                self.pendingTransactions.append(pendingTx)
                callback(.success(pendingTx))

            case .error(let error):
                callback(.error(error))
            }
        })
    }

    //Nonce is either previous nonce + 1 , or 1 if no transactions have been sent yet
    private func getNonce() -> UInt64 {
        let sentTransactions = Store.state.wallets[currency.code]?.transactions.filter { self.isOwnAddress(address: ($0 as! EthTransaction).fromAddress) }
        let previousNonce = sentTransactions?.map { ($0 as! EthTransaction).nonce }.max()
        return (previousNonce == nil) ? 0 : previousNonce! + 1
    }

    func resetForWipe() {
        tokens.removeAll()
        timer?.invalidate()
    }

    func canUseBiometrics(forTx: BRTxRef) -> Bool {
        return false
    }

    func isOwnAddress(address: String) -> Bool {
        return address.lowercased() == self.address?.lowercased()
    }

    // walletID identifies a wallet by the ethereum public key
    // 1. compute the sha256(address[0]) -- note address excludes the "0x" prefix
    // 2. take the first 10 bytes of the sha256 and base32 encode it (lowercasing the result)
    // 3. split the result into chunks of 4-character strings and join with a space
    //
    // this provides an easily human-readable (and verbally-recitable) string that can
    // be used to uniquely identify this wallet.
    //
    // the user may then provide this ID for later lookup in associated systems
    private func getWalletID() -> String? {
        if let small = address?.dropFirst(2).data(using: .utf8)?.sha256[0..<10].base32.lowercased() {
            return stride(from: 0, to: small.count, by: 4).map {
                let start = small.index(small.startIndex, offsetBy: $0)
                let end = small.index(start, offsetBy: 4, limitedBy: small.endIndex) ?? small.endIndex
                return String(small[start..<end])
                }.joined(separator: " ")
        }
        return nil
    }
}

// ERC20 Support
extension EthWalletManager {
    func updateTokenBalances() {
        guard let address = address, let apiClient = apiClient else { return }
        //TODO: single API call
        tokens.forEach { token in
            apiClient.getTokenBalance(address: address, token: token, handler: { result in
                switch result {
                case .success(let value):
                    Store.perform(action: WalletChange(token).setBalance(value))
                case .error(let error):
                    print("getTokenBalance error: \(error.localizedDescription)")
                }
            })
        }
    }
}
