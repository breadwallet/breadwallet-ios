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
    var viewModel: TxDetailViewModel!
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(textView)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        textView.constrain([
            textView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: C.padding[2]),
            textView.constraint(.trailing, toView: container),
            textView.constraint(.top, toView: container),
            textView.constraint(.bottom, toView: container)
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        
        textView.font = .customBody(size: 13.0)
        textView.textColor = .darkText
        textView.textAlignment = .right
        textView.isScrollEnabled = false
        textView.returnKeyType = .done
        textView.delegate = self
    }
    
    // MARK: -
    
    func set(viewModel: TxDetailViewModel) {
        self.viewModel = viewModel
        textView.text = viewModel.comment
    }
    
    fileprivate func saveComment(comment: String) {
        guard let tx = viewModel.tx as? BtcTransaction,
            let rate = store?.state.currentRate else { return }
        
        tx.saveComment(comment: comment, rate: rate)
        
        store?.trigger(name: .txMemoUpdated(tx.hash))
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
