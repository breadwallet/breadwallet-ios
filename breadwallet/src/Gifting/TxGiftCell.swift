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
    
    private var coordinator: GiftSharingCoordinator?
    
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
        self.coordinator?.showShare()
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
        self.coordinator = GiftSharingCoordinator(gift: gift)
        self.coordinator?.viewModel = viewModel
    }
}
