// 
//  Sharing.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-12-10.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import LinkPresentation

class GiftSharingCoordinator {
    
    private let gift: Gift
    var parent: UIViewController?
    var viewModel: TxViewModel?
    
    init(gift: Gift) {
        self.gift = gift
    }
    
    @available(iOS 13.0, *)
    func showShare() {
        let alert = UIAlertController(title: "Share", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Share link", style: .default, handler: { [weak self] _ in
            self?.shareUrl()
        }))
        alert.addAction(UIAlertAction(title: "Share QR Code", style: .default, handler: { [weak self] _ in
            self?.shareImage()
        }))
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
    }
    
    func closeAction() {
        DispatchQueue.main.async {
            UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    @available(iOS 13.0, *)
    private func shareUrl() {
        let ac = UIActivityViewController(activityItems: [URL(string: gift.url!)!], applicationActivities: [])
        self.present(ac)
    }
    
    @available(iOS 13.0, *)
    private func shareImage() {
        let frame = CGRect(x: 0, y: 0, width: 375, height: 650)
        let temp = ShareGiftView(gift: gift, showButton: false)
        temp.frame = frame
        temp.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: frame.size)
        if let format = renderer.format as? UIGraphicsImageRendererFormat {
            format.opaque = false
            format.scale = 2.0
        }
        let image = renderer.image { _ in
            temp.drawHierarchy(in: frame, afterScreenUpdates: true)
        }
        let item = ShareActivityItemSource(shareText: "Gift Bitcoin", shareImage: image)
        let ac = UIActivityViewController(activityItems: [item], applicationActivities: [])
        self.present(ac)
    }
    
    private func present(_ activity: UIActivityViewController) {
        activity.completionWithItemsHandler = { [weak self] _, success, _, _ in
            if success {
                self?.markAsShared()
            }
            self?.closeAction()
        }
        activity.excludedActivityTypes = [.addToReadingList, .assignToContact, .markupAsPDF, .openInIBooks]
        UIApplication.topViewController()?.present(activity, animated: true)
    }
    
    private func markAsShared() {
        guard let kvStore = Backend.kvStore else { return }
        guard let newHash = gift.txnHash ?? viewModel?.tx.hash else { return }
        let newGift = Gift(shared: true,
                           claimed: gift.claimed,
                           reclaimed: gift.reclaimed,
                           txnHash: newHash,
                           keyData: gift.keyData,
                           name: gift.name,
                           rate: gift.rate,
                           amount: gift.amount)
        viewModel?.tx.updateGiftStatus(gift: newGift, kvStore: kvStore)
        if let hash = newGift.txnHash {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("[gifting] txMetaDataUpdated")
                Store.trigger(name: .txMetaDataUpdated(hash))
            }
        }
    }
    
}

@available(iOS 13.0, *)
class ShareActivityItemSource: NSObject, UIActivityItemSource {
    
    var shareText: String
    var shareImage: UIImage
    
    init(shareText: String, shareImage: UIImage) {
        self.shareText = shareText
        self.shareImage = shareImage
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return shareImage.resize(CGSize(width: shareImage.size.width/2.0,
                                        height: shareImage.size.height/2.0)) as Any
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "You've been gifted Bitcoin"
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
                                suggestedSize size: CGSize) -> UIImage? {
        return shareImage.resize(size)
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return shareImage
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        
        let image = shareImage
        let imageProvider = NSItemProvider(object: image)
        let metadata = LPLinkMetadata()
        metadata.imageProvider = imageProvider
        metadata.title = "Gift Bitcoin"
        metadata.url = URL(string: shareText)
        return metadata
    }
}

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
