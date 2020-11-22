// 
//  TxGiftCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-21.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit
import WalletKit

class TxGiftCell: TxDetailRowCell {
    
    // MARK: Views
    
    private let addressButton = UIButton(type: .system)
    private var gift: Gift?
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(addressButton)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        addressButton.constrain([
            addressButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: C.padding[1]),
            addressButton.constraint(.trailing, toView: container),
            addressButton.constraint(.top, toView: container),
            addressButton.constraint(.bottom, toView: container)
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        addressButton.titleLabel?.font = .customBody(size: 14.0)
        addressButton.titleLabel?.adjustsFontSizeToFitWidth = true
        addressButton.titleLabel?.minimumScaleFactor = 0.7
        addressButton.titleLabel?.lineBreakMode = .byTruncatingMiddle
        addressButton.titleLabel?.textAlignment = .right
        addressButton.tintColor = .darkGray
        
        addressButton.tap = share
    }
    
    private func share() {
        guard let image = gift?.createImage() else { return }
        //let item = UIActivityItemSource
        //image.prepareForInterfaceBuilder()
        if #available(iOS 13.0, *) {
            
            
            //let provider = UIActivityItemProvider(placeholderItem: image)
            //let ac = UIActivityViewController(activityItems: [image, provider], applicationActivities: [])
            let ac = UIActivityViewController(activityItems: [ShareActivityItemSource(shareText: "Gift Bitcoin", shareImage: image)], applicationActivities: [])
            UIApplication.topViewController()?.present(ac, animated: true)
        }
    }
    
    func set(gift: Gift) {
        self.gift = gift
        addressButton.setTitle(gift.keyData, for: .normal)
    }
}

import LinkPresentation

@available(iOS 13.0, *)
class ShareActivityItemSource: NSObject, UIActivityItemSource {
    
    var shareText: String
    var shareImage: UIImage
    var linkMetaData = LPLinkMetadata()
    
    init(shareText: String, shareImage: UIImage) {
        self.shareText = shareText
        self.shareImage = shareImage
        linkMetaData.title = shareText
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return shareImage.resize(CGSize(width: shareImage.size.width/2.0, height: shareImage.size.height/2.0)) as Any
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return shareImage
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        return linkMetaData
    }
}

//TODO:GIFT - get rid of this
extension UIApplication {

    class func topViewController(_ base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            let top = topViewController(nav.visibleViewController)
            return top
        }

        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                let top = topViewController(selected)
                return top
            }
        }

        if let presented = base?.presentedViewController {
            let top = topViewController(presented)
            return top
        }
        return base
    }
}
