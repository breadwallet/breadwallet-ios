//
//  ViewController.swift
//  breadwallet
//
//  Created by ajv on 10/5/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
//import libunbound

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var seed = [UInt8](repeating: 0x00, count: 512/8)
        
        //BRBIP39DeriveKey(&seed, "video tiger report bid suspect taxi mail argue naive layer metal surface", nil);
        BRBIP39DeriveKey(&seed, "axis husband project any sea patch drip tip spirit tide bring belt", nil);

        let mpk = BRBIP32MasterPubKey(&seed, 512/8);
        let wallet = BRWalletNew(nil, 0, mpk);
        
        BRWalletSetCallbacks(wallet, nil,
            { (info, balance) in // balanceChanged
            },
            { (info, tx) in // txAdded
            },
            { (info, txHashes, txCount, blockHeight, timestamp) in // txUpdated
            },
            { (info, txHash, notifyUser, recommendRescan) in // txDeleted
            }
        )

        var addr = BRWalletReceiveAddress(wallet)
        
        print("wallet created with first receive address:", withUnsafePointer(to: &addr.s) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<BRAddress>.stride) { String(cString:$0) }
        })
        
        let manager = BRPeerManagerNew(wallet, UInt32(BIP39_CREATION_TIME), nil, 0, nil, 0);

        BRPeerManagerSetCallbacks(manager, nil,
            { (info) in // syncStarted
                print("sync started")
            },
            { (info) in // syncSucceeded
                print("sync succeeded")
            },
            { (info, error) in // syncFailed
                print("sync failed: ", strerror(error))
            },
            { (info) in // txStatusUpdate
            },
            { (info, blocks, blockCount) in // saveBlocks
            },
            { (info, peers, peerCount) in // savePeers
            },
            { (info) -> Int32 in // networkIsReachable
                return 1
            },
            { (info) in // threadCleanup
            }
        )
        
        BRPeerManagerConnect(manager);
        
//        BRPeerManagerDisconnect(manager);
//        BRPeerManagerFree(manager);
//        BRWalletFree(wallet);

//        let ctx = ub_ctx_create()
//
//        ub_ctx_delete(ctx)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

