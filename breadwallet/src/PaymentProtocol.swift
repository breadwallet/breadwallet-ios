//
//  PaymentProtocol.swift
//  breadwallet
//
//  Created by Aaron Voisine on 5/01/17.
//  Copyright (c) 2017 breadwallet LLC
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

// BIP70 payment protocol: https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki
// bitpay json payment protocol: https://github.com/bitpay/jsonPaymentProtocol/blob/master/specification.md

class PaymentProtocolDetails {
    internal let cPtr: UnsafeMutablePointer<BRPaymentProtocolDetails>
    internal var isManaged: Bool
    
    internal init(_ cPtr: UnsafeMutablePointer<BRPaymentProtocolDetails>) {
        self.cPtr = cPtr
        self.isManaged = false
    }
    
    init?(network: String = "main",
          outputs: [BRTxOutput],
          time: UInt64,
          expires: UInt64,
          memo: String? = nil,
          paymentURL: String? = nil,
          merchantData: [UInt8]? = nil) {
        guard let cPtr = BRPaymentProtocolDetailsNew(network, outputs, outputs.count, time, expires, memo, paymentURL,
                                                     merchantData, merchantData?.count ?? 0) else { return nil }
        cPtr.pointee.outCount = outputs.count
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    init?(data: Data) {
        let bytes = [UInt8](data)
        guard let cPtr = BRPaymentProtocolDetailsParse(bytes, bytes.count) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: BRPaymentProtocolDetailsSerialize(cPtr, nil, 0))
        BRPaymentProtocolDetailsSerialize(cPtr, &bytes, bytes.count)
        return bytes
    }
    
    var network: String { // main / test / regtest, default is "main"
        return String(cString: cPtr.pointee.network)
    }
    
    var currency: String = "BTC" // three digit currency code representing which coin the request is based on (bitpay)
    
    var requiredFeeRate: Double = 0.0 // the minimum fee per byte required on this transaction (bitpay)

    var outputs: [BRTxOutput] { // where to send payments, outputs[n].amount defaults to 0
        return [BRTxOutput](UnsafeBufferPointer(start: cPtr.pointee.outputs, count: cPtr.pointee.outCount))
    }

    var time: UInt64 { // request creation time, seconds since unix epoch, optional
        return cPtr.pointee.time
    }

    var expires: UInt64 { // when this request should be considered invalid, optional
        return cPtr.pointee.expires
    }

    var memo: String? { // human-readable description of request for the customer, optional
        guard cPtr.pointee.memo != nil else { return nil }
        return String(cString: cPtr.pointee.memo)
    }

    var paymentURL: String? { // url to send payment and get payment ack, optional
        guard cPtr.pointee.paymentURL != nil else { return nil }
        return String(cString: cPtr.pointee.paymentURL)
    }

    var paymentId: String? // the invoice ID, can be kept for records (bitpay)
    
    var merchantData: [UInt8]? { // arbitrary data to include in the payment message, optional
        guard cPtr.pointee.merchantData != nil else { return nil }
        return [UInt8](UnsafeBufferPointer(start: cPtr.pointee.merchantData, count: cPtr.pointee.merchDataLen))
    }

    deinit {
        if isManaged { BRPaymentProtocolDetailsFree(cPtr) }
    }
}

class PaymentProtocolRequest {
    internal struct Request: Decodable {
        internal struct Output: Decodable {
            let amount: UInt64
            let address: String
        }
        
        let network: String
        let currency: String
        let requiredFeeRate: Double
        let outputs: [Output]
        let time: Date
        let expires: Date
        let memo: String
        let paymentUrl: URL
        let paymentId: String
    }
    
    internal let cPtr: UnsafeMutablePointer<BRPaymentProtocolRequest>
    internal var isManaged: Bool
    private var cName: String?
    private var errMsg: String?
    private var didValidate: Bool = false
    
    internal init(_ cPtr: UnsafeMutablePointer<BRPaymentProtocolRequest>) {
        self.details = PaymentProtocolDetails(cPtr.pointee.details)
        self.details.isManaged = false
        self.cPtr = cPtr
        self.isManaged = false
    }

    init?(version: UInt32 = 1,
          pkiType: String = "none",
          pkiData: [UInt8]? = nil,
          details: PaymentProtocolDetails,
          signature: [UInt8]? = nil) {
        guard details.isManaged else { return nil } // request must be able take over memory management of details
        self.details = details
        guard let cPtr = BRPaymentProtocolRequestNew(version, pkiType, pkiData, pkiData?.count ?? 0, details.cPtr,
                                                     signature, signature?.count ?? 0) else { return nil }
        details.isManaged = false
        self.cPtr = cPtr
        self.isManaged = true
    }

    init?(data: Data) {
        let bytes = [UInt8](data)
        guard let cPtr = BRPaymentProtocolRequestParse(bytes, bytes.count) else { return nil }
        self.details = PaymentProtocolDetails(cPtr.pointee.details)
        self.details.isManaged = false
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    init?(json: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        guard let req = try? decoder.decode(Request.self, from: json.data(using: .utf8)!) else { return nil }
        let outputs = req.outputs.map {
            BRTxOutput(req.currency == "BCH" ? $0.address.bitcoinAddr : $0.address, $0.amount)
        }
        guard !outputs.isEmpty && outputs[0].amount > 0 && outputs[0].scriptLen > 0 else { return nil }
        guard let details = PaymentProtocolDetails(network: req.network, outputs: outputs,
                                                   time: UInt64(req.time.timeIntervalSince1970),
                                                   expires: UInt64(req.expires.timeIntervalSince1970),
                                                   memo: req.memo, paymentURL: req.paymentUrl.absoluteString)
            else { return nil }
        details.currency = req.currency
        details.requiredFeeRate = req.requiredFeeRate
        details.paymentId = req.paymentId
        mimeType = "application/payment-request"
        guard let cPtr = BRPaymentProtocolRequestNew(1, "none", nil, 0, details.cPtr, nil, 0) else { return nil }
        details.isManaged = false
        self.details = details
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: BRPaymentProtocolRequestSerialize(cPtr, nil, 0))
        BRPaymentProtocolRequestSerialize(cPtr, &bytes, bytes.count)
        return bytes
    }

    var version: UInt32 { // default is 1
        return cPtr.pointee.version
    }
    
    var pkiType: String { // none / x509+sha256 / x509+sha1, default is "none"
        return String(cString: cPtr.pointee.pkiType)
    }
    
    var pkiData: [UInt8]? { // depends on pkiType, optional
        guard cPtr.pointee.pkiData != nil else { return nil }
        return [UInt8](UnsafeBufferPointer(start: cPtr.pointee.pkiData, count: cPtr.pointee.pkiDataLen))
    }
    
    var details: PaymentProtocolDetails // required
    
    var signature: [UInt8]? { // pki-dependent signature, optional
        guard cPtr.pointee.signature != nil else { return nil }
        return [UInt8](UnsafeBufferPointer(start: cPtr.pointee.signature, count: cPtr.pointee.sigLen))
    }

    var certs: [[UInt8]] { // array of DER encoded certificates
        var certs = [[UInt8]]()
        var idx = 0
        
        while BRPaymentProtocolRequestCert(cPtr, nil, 0, idx) > 0 {
            certs.append([UInt8](repeating: 0, count: BRPaymentProtocolRequestCert(cPtr, nil, 0, idx)))
            BRPaymentProtocolRequestCert(cPtr, UnsafeMutablePointer(mutating: certs[idx]), certs[idx].count, idx)
            idx += 1
        }
        
        return certs
    }
    
    var digest: [UInt8] { // hash of the request needed to sign or verify the request
        let digest = [UInt8](repeating: 0, count: BRPaymentProtocolRequestDigest(cPtr, nil, 0))
        BRPaymentProtocolRequestDigest(cPtr, UnsafeMutablePointer(mutating: digest), digest.count)
        return digest
    }

    func isValid() -> Bool {
        defer { didValidate = true }
        
        if pkiType != "none" {
            var certs = [SecCertificate]()
            let policies = [SecPolicy](repeating: SecPolicyCreateBasicX509(), count: 1)
            var trust: SecTrust?
            var trustResult = SecTrustResultType.invalid
            
            for c in self.certs {
                if let cert = SecCertificateCreateWithData(nil, Data(bytes: c) as CFData) { certs.append(cert) }
            }
            
            if !certs.isEmpty {
                cName = SecCertificateCopySubjectSummary(certs[0]) as String?
            }
            
            SecTrustCreateWithCertificates(certs as CFTypeRef, policies as CFTypeRef, &trust)
            if let trust = trust { SecTrustEvaluate(trust, &trustResult) } // verify certificate chain
            
            // .unspecified indicates a positive result that wasn't decided by the user
            guard trustResult == .unspecified || trustResult == .proceed else {
                errMsg = certs.isEmpty ? S.PaymentProtocol.Errors.missingCertificate : S.PaymentProtocol.Errors.untrustedCertificate
                
                if let trust = trust, let properties = SecTrustCopyProperties(trust) as? [[AnyHashable: Any]] {
                    for prop in properties {
                        if prop["type"] as? String != kSecPropertyTypeError as String { continue }
                        errMsg = errMsg! + " - " + (prop["value"] as? String ?? "")
                        break
                    }
                }
                
                return false
            }

            var status = errSecUnimplemented
            var pubKey: SecKey?
            if let trust = trust { pubKey = SecTrustCopyPublicKey(trust) }
            
            if let pubKey = pubKey, let signature = signature {
                if pkiType == "x509+sha256" {
                    status = SecKeyRawVerify(pubKey, .PKCS1SHA256, digest, digest.count, signature, signature.count)
                } else if pkiType == "x509+sha1" {
                    status = SecKeyRawVerify(pubKey, .PKCS1SHA1, digest, digest.count, signature, signature.count)
                }
            }

            guard status == errSecSuccess else {
                if status == errSecUnimplemented {
                    errMsg = S.PaymentProtocol.Errors.unsupportedSignatureType
                    print(errMsg!)
                } else {
                    errMsg = NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription
                    print("SecKeyRawVerify error: " + errMsg!)
                }
                
                return false
            }
        } else if !self.certs.isEmpty { // non-standard extention to include an un-certified request name
            cName = String(data: Data(self.certs[0]), encoding: .utf8)
        }
        
        guard details.expires == 0 || NSDate.timeIntervalSinceReferenceDate <= Double(details.expires) else {
            errMsg = S.PaymentProtocol.Errors.requestExpired
            return false
        }
        
        return true
    }
    
    var amount: UInt64 {
        return details.outputs.map { $0.amount }.reduce(0, +)
    }
    
    var commonName: String? {
        if !didValidate { _ = self.isValid() }
        return cName
    }
    
    var errorMessage: String? {
        if !didValidate { _ = self.isValid() }
        return errMsg
    }

    var address: String {
        return details.outputs.first!.swiftAddress
    }
    
    var mimeType: String = "application/bitcoin-paymentrequest"
    
    deinit {
        if isManaged { BRPaymentProtocolRequestFree(cPtr) }
    }
}

class PaymentProtocolPayment {
    internal struct Payment: Decodable, Encodable {
        let currency: String
        let transactions: [String]
    }
    
    internal let cPtr: UnsafeMutablePointer<BRPaymentProtocolPayment>
    internal var isManaged: Bool

    internal init(_ cPtr: UnsafeMutablePointer<BRPaymentProtocolPayment>) {
        self.cPtr = cPtr
        self.isManaged = false
    }

    init?(merchantData: [UInt8]? = nil,
          transactions: [BRTxRef?],
          refundTo: [(address: String, amount: UInt64)],
          memo: String? = nil) {
        var txRefs = transactions
        guard let cPtr = BRPaymentProtocolPaymentNew(merchantData, merchantData?.count ?? 0, &txRefs, txRefs.count,
                                                     refundTo.map { $0.amount },
                                                     refundTo.map { BRAddress(string: $0.address) ?? BRAddress() },
                                                     refundTo.count, memo) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
    }

    init?(data: Data) {
        let bytes = [UInt8](data)
        guard let cPtr = BRPaymentProtocolPaymentParse(bytes, bytes.count) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: BRPaymentProtocolPaymentSerialize(cPtr, nil, 0))
        BRPaymentProtocolPaymentSerialize(cPtr, &bytes, bytes.count)
        return bytes
    }

    var currency: String = "BTC" // three digit currency code representing which coin the request is based on (bitpay)
    
    var merchantData: [UInt8]? { // from request->details->merchantData, optional
        guard cPtr.pointee.merchantData != nil else { return nil }
        return [UInt8](UnsafeBufferPointer(start: cPtr.pointee.merchantData, count: cPtr.pointee.merchDataLen))
    }

    var transactions: [BRTxRef?] { // array of signed BRTxRef to satisfy outputs from details
        return [BRTxRef?](UnsafeBufferPointer(start: cPtr.pointee.transactions, count: cPtr.pointee.txCount))
    }
    
    var refundTo: [BRTxOutput] { // where to send refunds, if a refund is necessary, refundTo[n].amount defaults to 0
        return [BRTxOutput](UnsafeBufferPointer(start: cPtr.pointee.refundTo, count: cPtr.pointee.refundToCount))
    }
    
    var memo: String? { // human-readable message for the merchant, optional
        guard cPtr.pointee.memo != nil else { return nil }
        return String(cString: cPtr.pointee.memo)
    }
    
    var json: String? {
        let tx = transactions.compactMap { $0?.bytes?.reduce("") { $0 + String(format: "%02x", $1) } }
        guard let data = try? JSONEncoder().encode(Payment(currency: currency, transactions: tx)) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    deinit {
        if isManaged { BRPaymentProtocolPaymentFree(cPtr) }
    }
}

class PaymentProtocolACK {
    internal struct Ack: Decodable {
        let payment: PaymentProtocolPayment.Payment
        let memo: String?
    }
    
    internal let cPtr: UnsafeMutablePointer<BRPaymentProtocolACK>
    internal var isManaged: Bool
    
    internal init(_ cPtr: UnsafeMutablePointer<BRPaymentProtocolACK>) {
        self.cPtr = cPtr
        self.isManaged = false
    }
    
    init?(payment: PaymentProtocolPayment, memo: String? = nil) {
        guard payment.isManaged else { return nil } // ack must be able to take over memory management of payment
        guard let cPtr = BRPaymentProtocolACKNew(payment.cPtr, memo) else { return nil }
        payment.isManaged = false
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    init?(data: Data) {
        let bytes = [UInt8](data)
        guard let cPtr = BRPaymentProtocolACKParse(bytes, bytes.count) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    init?(json: String) {
        guard let ack = try? JSONDecoder().decode(Ack.self, from: json.data(using: .utf8)!) else { return nil }
        guard let payment = PaymentProtocolPayment(transactions: [], refundTo: []) else { return nil }
        payment.currency = ack.payment.currency
        guard let cPtr = BRPaymentProtocolACKNew(payment.cPtr, ack.memo) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
    }
    
    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: BRPaymentProtocolACKSerialize(cPtr, nil, 0))
        BRPaymentProtocolACKSerialize(cPtr, &bytes, bytes.count)
        return bytes
    }

    var payment: PaymentProtocolPayment { // payment message that triggered this ack, required
        return PaymentProtocolPayment(cPtr.pointee.payment)
    }

    var memo: String? { // human-readable message for customer, optional
        guard cPtr.pointee.memo != nil else { return nil }
        return String(cString: cPtr.pointee.memo)
    }
    
    deinit {
        if isManaged { BRPaymentProtocolACKFree(cPtr) }
    }
}
