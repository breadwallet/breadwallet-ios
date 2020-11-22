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

struct Gift: Codable {
    let shared: Bool
    let claimed: Bool
    let keyData: String
}

extension Gift {
    static func create(key: Key) -> Gift {
        return Gift(shared: false, claimed: false, keyData: key.encodeAsPrivate)
    }
    
    func createImage() -> UIImage? {
        guard let background = UIImage(named: "GiftCard") else { return nil }
        guard let data = keyData.data(using: .utf8) else { return nil }
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
