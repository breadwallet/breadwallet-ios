//
//  InterfaceController.swift
//  breadwallet WatchKit Extension
//
//  Created by ajv on 10/5/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {

    @IBOutlet var bitsBalance: WKInterfaceLabel!
    @IBOutlet var localBalance: WKInterfaceLabel!
    @IBOutlet var loadingIndicator: WKInterfaceImage!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        NotificationCenter.default.addObserver(self, selector: #selector(InterfaceController.update), name: .ApplicationDataDidUpdateNotification, object: nil)

        update()
    }

    @objc func update() {
        if let data = WatchDataManager.shared.data {
            loadingIndicator.setHidden(true)
            bitsBalance.setText(data.balance)
            localBalance.setText(data.localBalance)
        } else {
            bitsBalance.setText("")
            localBalance.setText("")
        }
    }

    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
