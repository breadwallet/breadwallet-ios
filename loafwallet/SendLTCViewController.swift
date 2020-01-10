//
//  SendLTCViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation
import UIKit

class SendLTCViewController: UIViewController {
    
    var store: Store?
    
    override func viewDidLoad() {
        

    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let store = self.store else {
            NSLog("ERROR: Store is not initialized")
            return
        }
        
        store.perform(action: RootModalActions.Present(modal: .send))
    }
    
    
}
