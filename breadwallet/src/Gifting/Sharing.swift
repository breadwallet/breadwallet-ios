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
    
    func showShare() {
//        let alert = UIAlertController(title: "Share", message: nil, preferredStyle: .actionSheet)
//        alert.addAction(UIAlertAction(title: "Share link", style: .default, handler: { _ in
//            let url = self.gift.url
//            //TODO:GIFT - make this work for iOS 13
//            if #available(iOS 13.0, *) {
//                let ac = UIActivityViewController(activityItems: [url!], applicationActivities: [])
//                UIApplication.topViewController()?.present(ac, animated: true)
//                self.markAsShared()
//            }
//        }))
//        alert.addAction(UIAlertAction(title: "Share QR Code", style: .default, handler: { _ in
//            let image = self.gift.createImage()!
//            //TODO:GIFT - make this work for iOS 13
//            if #available(iOS 13.0, *) {
//                let ac = UIActivityViewController(activityItems: [ShareActivityItemSource(shareText: "Gift Bitcoin", shareImage: image)], applicationActivities: [])
//                UIApplication.topViewController()?.present(ac, animated: true)
//                self.markAsShared()
//            }
//        }))
//        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
//        UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
        //, gift.url!
//        let ac = UIActivityViewController(activityItems: [gift.qrImage()!, URL(string: gift.url!)!], applicationActivities: nil)
        
        if #available(iOS 13.0, *) {
            let item = ShareActivityItemSource(shareText: gift.url!, shareImage: gift.qrImage()!)
//            let ac = UIActivityViewController(activityItems: [URL(string: gift.url!)!, item], applicationActivities: [])
            let ac = UIActivityViewController(activityItems: [item], applicationActivities: [])
            ac.excludedActivityTypes = [.addToReadingList, .openInIBooks]
            
            ac.completionWithItemsHandler = { activity, success, items, error in
                print("[gifting]: \(activity), \(success), \(items), \(error)")
                DispatchQueue.main.async {
                    UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)

//                    self.parent?.dismiss(animated: true, completion: nil)
                }
            }
            
            UIApplication.topViewController()?.present(ac, animated: true)
        } else {
            // Fallback on earlier versions
        }
        
        self.markAsShared()
    }
    
    private func markAsShared() {
        guard let kvStore = Backend.kvStore else { return }
        //guard let gift = gift else { return }
        guard let newHash = gift.txnHash ?? viewModel?.tx.hash else { return }

        let newGift = Gift(shared: true, claimed: gift.claimed, txnHash: newHash, keyData: gift.keyData)
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
    //var linkMetaData = LPLinkMetadata()
    
    init(shareText: String, shareImage: UIImage) {
        self.shareText = shareText
        self.shareImage = shareImage
        //linkMetaData.title = shareText
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
        //return nil
        //return shareImage
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        
        let image = shareImage
        let imageProvider = NSItemProvider(object: image)
        let metadata = LPLinkMetadata()
        metadata.imageProvider = imageProvider
        metadata.title = "Gift Bitcoin"
        metadata.url = URL(string: shareText)
        return metadata
        //return linkMetaData
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
