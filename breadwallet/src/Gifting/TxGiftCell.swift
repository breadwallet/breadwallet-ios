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
    
    private let share = UIButton(type: .system)
    private let reclaim = UIButton(type: .system)
    
    private var viewModel: TxDetailViewModel!
    private var gift: Gift?
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(share)
        container.addSubview(reclaim)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        share.constrain([
            share.constraint(.trailing, toView: container),
            share.constraint(.top, toView: container),
            share.constraint(.bottom, toView: container)])
        
        reclaim.constrain([
            reclaim.trailingAnchor.constraint(equalTo: share.leadingAnchor, constant: -C.padding[1]),
            reclaim.constraint(.top, toView: container),
            reclaim.constraint(.bottom, toView: container)])
    }
    
    override func setupStyle() {
        super.setupStyle()
        share.titleLabel?.font = .customBody(size: 14.0)
        reclaim.titleLabel?.font = .customBody(size: 14.0)
        
        share.tap = showShare
        reclaim.tap = showReclaim
        
        share.setTitle("Share", for: .normal)
        reclaim.setTitle("Reclaim", for: .normal)
    }
    
    private func showShare() {
        let alert = UIAlertController(title: "Share", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Share link", style: .default, handler: { _ in
            guard let url = self.gift?.url else { return }
            //TODO:GIFT - make this work for iOS 13
            if #available(iOS 13.0, *) {
                let ac = UIActivityViewController(activityItems: [url], applicationActivities: [])
                UIApplication.topViewController()?.present(ac, animated: true)
                self.markAsShared()
            }
        }))
        alert.addAction(UIAlertAction(title: "Share QR Code", style: .default, handler: { _ in
            guard let image = self.gift?.createImage() else { return }
            //TODO:GIFT - make this work for iOS 13
            if #available(iOS 13.0, *) {
                let ac = UIActivityViewController(activityItems: [ShareActivityItemSource(shareText: "Gift Bitcoin", shareImage: image)], applicationActivities: [])
                UIApplication.topViewController()?.present(ac, animated: true)
                self.markAsShared()
            }
        }))
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
    }
    
    private func showReclaim() {
        
    }
    
    private func markAsShared() {
        guard let kvStore = Backend.kvStore else { return }
        guard let gift = gift else { return }
        let newHash = gift.txnHash ?? viewModel.transactionHash
        
        let newGift = Gift(shared: true, claimed: gift.claimed, txnHash: newHash, keyData: gift.keyData)
        viewModel.tx.updateGiftStatus(gift: newGift, kvStore: kvStore)
        if let hash = newGift.txnHash {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("[gifting] txMetaDataUpdated")
                Store.trigger(name: .txMetaDataUpdated(hash))
            }
        }
    }
    
    func set(gift: Gift, viewModel: TxDetailViewModel) {
        self.gift = gift
        self.viewModel = viewModel
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
