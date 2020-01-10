//
//  TransactionManager.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//
import Foundation

class TransactionManager: NSObject, Subscriber {
    
    static let sharedInstance = TransactionManager()
    var transactions: [Transaction] = []
    var store: Store?
    var rate: Rate?
    
    override init() {
        super.init()
    }
    
    func fetchTransactionData(store: Store) {
        self.store = store
        
        store.subscribe(self, selector: { $0.walletState.transactions != $1.walletState.transactions },
                        callback: { state in
                            self.transactions = state.walletState.transactions
        })
        
        store.subscribe(self,selector: { $0.currentRate != $1.currentRate},
                        callback: {
                            
                            self.rate = $0.currentRate
        })
        
        store.subscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { _ in
                    //reload
                })
        
        
    }
    
}
