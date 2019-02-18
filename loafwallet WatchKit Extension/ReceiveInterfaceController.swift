//
//  ReceiveInterfaceController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import WatchKit
import UIKit
class ReceiveInterfaceController : WKInterfaceController {

    @IBOutlet var image: WKInterfaceImage!
    @IBOutlet var label: WKInterfaceLabel!

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        NotificationCenter.default.addObserver(self, selector: #selector(ReceiveInterfaceController.runUpdate), name: .ApplicationDataDidUpdateNotification, object: nil)
        runUpdate()
    }

    @objc func runUpdate() {
        guard let data = WatchDataManager.shared.data else { return }
        image.setImage(data.qrCode)
    }
}
