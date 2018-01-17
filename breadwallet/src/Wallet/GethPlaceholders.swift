//
//  GethPlaceholders.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-01-16.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

public class GethBigInt {
    init(_ integer: Int64) {}
    init(_ integer: Int) {}
    func getString(_ base: Int) -> String {
        return ""
    }
    func getInt64() -> Int64 {
        return 0
    }
    func setString(_ string: String, base: Int) {}
}

class GethContext {

}

class GethEthereumClient {
    init(_ url: String) {}
    func suggestGasPrice() -> GethBigInt {
        return GethBigInt(0)
    }
    func sendTransaction(tx: GethTransaction) {}
}

class GethAddress {
    init(fromBytes: Data) {}
    init(fromHex: String) {}
    func getHex() -> String { return "" }
}

class GethAccount {}

class GethTransaction {
    init() {}
    init(_ nonce: Int64, to: GethAddress, amount: GethBigInt, gasLimit: GethBigInt, gasPrice: GethBigInt, data: Data?) {}
    func getHash() -> String { return "" }
}

class GethKeyStore {
    init(_ directory: String, scryptN: Int, scryptP: Int) {}
    func importECDSAKey(_ data: Data, passphrase: String) -> GethAccount { return GethAccount() }
    func signTx(_ account: GethAccount, tx: GethTransaction, chainID: GethBigInt) -> GethTransaction { return GethTransaction() }
}
