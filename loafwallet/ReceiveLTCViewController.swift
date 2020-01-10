//
//  ReceiveLTCViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import UIKit 

struct WalletAddressData {
    var address: String
    var qrCode: UIImage
    var balance: Double
    var balanceText: String  {
        get {
            String(self.balance) + " Ł"
        }
    }
}

class ReceiveLTCViewController: UIViewController {
     
   var store: Store?
    override func viewDidLoad() {
        super.viewDidLoad()
       
    }
    
    override func viewWillAppear(_ animated: Bool) {
          guard let store = self.store else {
                   NSLog("ERROR: Store is not initialized")
                   return
               }
               
               store.perform(action: RootModalActions.Present(modal: .receive))
    }
     

}
