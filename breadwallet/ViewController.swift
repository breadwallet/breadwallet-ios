//
//  ViewController.swift
//  breadwallet
//
//  Created by ajv on 10/5/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import libunbound

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var key = BRKey()
        var secret = UInt256(u64: (0, 0, 0, 1))
        let mpk = BRMasterPubKey()
        var tx = BRTransactionNew()
        let wallet = BRWalletNew(&tx, 0, mpk)
        
        BRKeySetSecret(&key, &secret, 0)
        
        BRWalletFree(wallet)
        BRTransactionFree(tx)

        let ctx = ub_ctx_create()
        
        ub_ctx_delete(ctx)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

