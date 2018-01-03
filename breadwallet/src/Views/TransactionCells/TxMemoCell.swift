//
//  TxMemoCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-02.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class TxMemoCell: TxDetailRowCell {
    
    // MARK: - Views
    
    fileprivate let textView = UITextView()
    
    // MARK: - Vars
    
    var store: Store?
    var kvStore: BRReplicatedKVStore?
    var txInfo: TxDetailInfo?
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(textView)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        textView.constrain([
            textView.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: C.padding[1]),
            textView.constraint(.trailing, toView: container),
            textView.constraint(.top, toView: container),
            textView.constraint(.bottom, toView: container)
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        
        textView.font = .customBody(size: 13.0)
        textView.textColor = .darkText
        textView.isScrollEnabled = false
        textView.returnKeyType = .done
        textView.delegate = self
    }
    
    // MARK: -
    
    func set(txInfo: TxDetailInfo, store: Store, kvStore: BRReplicatedKVStore) {
        self.txInfo = txInfo
        self.store = store
        self.kvStore = kvStore
        textView.text = txInfo.memo
    }
    
    fileprivate func saveComment(comment: String) {
        guard let kvStore = self.kvStore,
            let transaction = txInfo?.transaction else { return }
        
        if let metaData = txInfo?.transaction.metaData {
            metaData.comment = comment
            do {
                let _ = try kvStore.set(metaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        } else {
            guard let rate = store?.state.currentRate, // TODO: use original rate
                let rawTx = transaction.rawTransaction else { return }
            let newMetaData = TxMetaData(transaction: rawTx, exchangeRate: rate.rate, exchangeRateCurrency: rate.code, feeRate: 0.0, deviceId: UserDefaults.standard.deviceID)
            newMetaData.comment = comment
            do {
                let _ = try kvStore.set(newMetaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        }
        
        store?.trigger(name: .txMemoUpdated(transaction.hash))
    }
}

extension TxMemoCell: UITextViewDelegate {
    func textViewDidEndEditing(_ textView: UITextView) {
        guard let text = textView.text else { return }
        saveComment(comment: text)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text.rangeOfCharacter(from: CharacterSet.newlines) == nil else {
            textView.resignFirstResponder()
            return false
        }
        
        let count = (textView.text ?? "").utf8.count + text.utf8.count
        if count > C.maxMemoLength {
            return false
        } else {
            return true
        }
    }
}
