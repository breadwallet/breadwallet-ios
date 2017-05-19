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
import Security
import BRCore

class PaymentProtocolDetails {
    private let cPtr: UnsafeMutablePointer<BRPaymentProtocolDetails>
    private let isManaged: Bool
    
    init(_ cPtr: UnsafeMutablePointer<BRPaymentProtocolDetails>) {
        self.cPtr = cPtr
        self.isManaged = false
    }
    
    var network: String { // "main" or "test", default is "main"
        return String(cString: cPtr.pointee.network)
    }

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

    var merchantData: [UInt8]? { // arbitrary data to include in the payment message, optional
        guard cPtr.pointee.merchantData != nil else { return nil }
        return [UInt8](UnsafeBufferPointer(start: cPtr.pointee.merchantData, count: cPtr.pointee.merchDataLen))
    }

    deinit {
        if isManaged { BRPaymentProtocolDetailsFree(cPtr) }
    }
}

class PaymentProtocolRequest {
    private let cPtr: UnsafeMutablePointer<BRPaymentProtocolRequest>
    private let isManaged: Bool
    private var cName: String?
    private var errMsg: String?
    private var didValidate: Bool = false
    
    init?(buffer: [UInt8]) {
        guard let cPtr = BRPaymentProtocolRequestParse(buffer, buffer.count) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
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
    
    var details: PaymentProtocolDetails { // required
        return PaymentProtocolDetails(cPtr.pointee.details)
    }
    
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
            idx = idx + 1
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
            
            if certs.count > 0 {
                cName = SecCertificateCopySubjectSummary(certs[0]) as String?
            }
            
            SecTrustCreateWithCertificates(certs as CFTypeRef, policies as CFTypeRef, &trust)
            if let trust = trust { SecTrustEvaluate(trust, &trustResult) } // verify certificate chain
            
            // .unspecified indicates a positive result that wasn't decided by the user
            guard trustResult == .unspecified || trustResult == .proceed else {
                errMsg = certs.count > 0 ? NSLocalizedString("untrusted certificate", comment: "") :
                         NSLocalizedString("missing certificate", comment: "")
                
                if let trust = trust, let properties = SecTrustCopyProperties(trust) {
                    for prop in properties as! [Dictionary<AnyHashable, Any>] {
                        if prop["type"] as? String != kSecPropertyTypeError as String { continue }
                        errMsg = errMsg! + " - " + (prop["value"] as! String)
                        break
                    }
                }
                
                return false
            }

            var status = errSecUnimplemented
            var pubKey: SecKey? = nil
            if let trust = trust { pubKey = SecTrustCopyPublicKey(trust) }
            
            if let pubKey = pubKey, let signature = signature {
                if pkiType == "x509+sha256" {
                    status = SecKeyRawVerify(pubKey, .PKCS1SHA256, digest, digest.count, signature, signature.count)
                }
                else if pkiType == "x509+sha1" {
                    status = SecKeyRawVerify(pubKey, .PKCS1SHA1, digest, digest.count, signature, signature.count)
                }
            }

            guard status == errSecSuccess else {
                if status == errSecUnimplemented {
                    errMsg = NSLocalizedString("unsupported signature type", comment: "")
                    print(errMsg!)
                }
                else {
                    errMsg = NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription
                    print("SecKeyRawVerify error: " + errMsg!)
                }
                
                return false
            }
        }
        else if (self.certs.count > 0) { // non-standard extention to include an un-certified request name
            cName = String(data: Data(self.certs[0]), encoding: .utf8)
        }
        
        guard details.expires == 0 || NSDate.timeIntervalSinceReferenceDate <= Double(details.expires) else {
            errMsg = NSLocalizedString("request expired", comment: "")
            return false
        }
        
        return true
    }
    
    var commonName: String? {
        if !didValidate { _ = self.isValid() }
        return cName
    }
    
    var errorMessage: String? {
        if !didValidate { _ = self.isValid() }
        return errMsg
    }
    
    deinit {
        if isManaged { BRPaymentProtocolRequestFree(cPtr) }
    }
}

class PaymentProtocolPayment {
    private let cPtr: UnsafeMutablePointer<BRPaymentProtocolPayment>
    private let isManaged: Bool

    init(_ cPtr: UnsafeMutablePointer<BRPaymentProtocolPayment>) {
        self.cPtr = cPtr
        self.isManaged = false
    }

    init(merchantData: [UInt8]? = nil, transactions: [BRTxRef?],
         refundTo: [(address: String, amount: UInt64)] = [(String, UInt64)](), memo: String? = nil) {
        var txRefs = transactions
        let refundToAddrs = refundTo.map { BRAddress(string: $0.address) ?? BRAddress() }
        let refundToAmounts = refundTo.map { $0.amount }
        self.cPtr = BRPaymentProtocolPaymentNew(merchantData, merchantData?.count ?? 0, &txRefs, txRefs.count,
                                                refundToAmounts, refundToAddrs, refundTo.count, memo)
        self.isManaged = true
    }

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
    
    deinit {
        if isManaged { BRPaymentProtocolPaymentFree(cPtr) }
    }
}

class PaymentProtocolACK {
    private let cPtr: UnsafeMutablePointer<BRPaymentProtocolACK>
    private let isManaged: Bool
    
    init?(buffer: [UInt8]) {
        guard let cPtr = BRPaymentProtocolACKParse(buffer, buffer.count) else { return nil }
        self.cPtr = cPtr
        self.isManaged = true
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

