//
//  TxListCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-02-19.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class TxListCell: UITableViewCell {

    // MARK: - Views
    
    private let timestamp = UILabel(font: .customBody(size: 16.0), color: .darkGray)
    private let descriptionLabel = UILabel(font: .customBody(size: 14.0), color: .lightGray)
    private let amount = UILabel(font: .customBold(size: 18.0))
    private let separator = UIView(color: .separatorGray)
    
    // MARK: Vars
    
    private var viewModel: TxListViewModel!
    
    // MARK: - Init
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    func setTransaction(_ viewModel: TxListViewModel, isBtcSwapped: Bool, rate: Rate, maxDigits: Int, isSyncing: Bool) {
        self.viewModel = viewModel
        
        timestamp.text = viewModel.shortTimestamp
        descriptionLabel.text = viewModel.shortDescription
        amount.attributedText = viewModel.amount(isBtcSwapped: isBtcSwapped, rate: rate)
    }
    
    // MARK: - Private
    
    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }
    
    private func addSubviews() {
        contentView.addSubview(timestamp)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(amount)
        contentView.addSubview(separator)
    }
    
    private func addConstraints() {
        timestamp.constrain([
            timestamp.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[2]),
            timestamp.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2])
            ])
        
        descriptionLabel.constrain([
            descriptionLabel.topAnchor.constraint(equalTo: timestamp.bottomAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[2]),
            descriptionLabel.leadingAnchor.constraint(equalTo: timestamp.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: timestamp.trailingAnchor)
            ])
        
        amount.constrain([
            amount.topAnchor.constraint(equalTo: contentView.topAnchor),
            amount.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            amount.leadingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor, constant: C.padding[6]),
            amount.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[2]),
            ])
        
        separator.constrainBottomCorners(height: 0.5)
    }
    
    private func setupStyle() {
        selectionStyle = .none
        amount.textAlignment = .right
        amount.setContentHuggingPriority(.required, for: .horizontal)
        timestamp.setContentHuggingPriority(.required, for: .vertical)
        descriptionLabel.lineBreakMode = .byTruncatingTail
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
