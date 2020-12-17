// 
//  Gift.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-21.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import WalletKit
import UIKit

struct Gift: Codable, Equatable {
    let shared: Bool
    let claimed: Bool
    let reclaimed: Bool? //TODO:GIFT - make this not optional
    let txnHash: String?
    let keyData: String
    let name: String?
    let rate: Double?
    let amount: Double?
}

extension Gift {
    
    var encodedKeyString: String? {
        return keyData.data(using: .utf8)?.base64EncodedString()
    }
    
    var url: String? {
        guard let key = encodedKeyString else { return nil }
        return "https://brd.com/x/gift/\(key)"
    }
    
    static func create(key: Key, hash: String?, name: String, rate: Double, amount: Double) -> Gift {
        return Gift(shared: false,
                    claimed: false,
                    reclaimed: false,
                    txnHash: hash,
                    keyData: key.encodeAsPrivate,
                    name: name,
                    rate: rate,
                    amount: amount)
    }
    
    func qrImage() -> UIImage? {
        guard let data = url?.data(using: .utf8) else { return nil }
        return UIImage.qrCode(data: data)?.resize(CGSize(width: 300.0, height: 300.0))
    }
    
    func createImage() -> UIImage? {
        guard let background = UIImage(named: "GiftCard") else { return nil }
        guard let data = url?.data(using: .utf8) else { return nil }
        guard let qr = UIImage.qrCode(data: data)?.resize(CGSize(width: 300.0, height: 300.0)) else { return nil }
        
        let size = background.size
        UIGraphicsBeginImageContext(size)

        let backGroundSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        background.draw(in: backGroundSize)

        let qrSize = CGRect(x: 561, y: 150, width: qr.size.width, height: qr.size.height)
        qr.draw(in: qrSize, blendMode: .normal, alpha: 1.0)

        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
