//
//  TxMemoCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-02.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class TxMemoCell: TxDetailRowCell {
    
    // MARK: - Views
    
    fileprivate let textView = UITextView()
    fileprivate let placeholderLabel = UILabel(font: .customBody(size: 14.0), color: .lightGray)
    
    // MARK: - Vars

    var viewModel: TxDetailViewModel!
    weak var tableView: UITableView!
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(textView)
        textView.addSubview(placeholderLabel)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        textView.constrain([
            textView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: C.padding[2]),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        
        placeholderLabel.constrain([
            placeholderLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: container.topAnchor),
            placeholderLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: textView.widthAnchor)
            ])
        placeholderLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    override func setupStyle() {
        super.setupStyle()

        textView.font = .customBody(size: 14.0)
        textView.textColor = .darkGray
        textView.textAlignment = .right
        textView.isScrollEnabled = false
        textView.returnKeyType = .done
        textView.delegate = self
        
        placeholderLabel.textAlignment = .right
        placeholderLabel.text = S.TransactionDetails.commentsPlaceholder
    }
    
    // MARK: -
    
    func set(viewModel: TxDetailViewModel, tableView: UITableView) {
        self.tableView = tableView
        self.viewModel = viewModel
        textView.text = viewModel.comment
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    fileprivate func saveComment(comment: String) {
        guard let kvStore = Backend.kvStore else { return }
        viewModel.tx.save(comment: comment, kvStore: kvStore)
        Store.trigger(name: .txMemoUpdated(viewModel.tx.hash))
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
    
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        // trigger cell resize
        tableView.beginUpdates()
        tableView.endUpdates()
    }
}
