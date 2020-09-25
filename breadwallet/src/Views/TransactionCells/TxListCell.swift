//
//  TxListCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-02-19.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import SwiftUI

class TxListCell: UITableViewCell {

    // MARK: - Views
    
    private let timestamp = UILabel(font: .customBody(size: 16.0), color: .darkGray)
    private let descriptionLabel = UILabel(font: .customBody(size: 14.0), color: .lightGray)
    private let amount = UILabel(font: .customBold(size: 18.0))
    private let separator = UIView(color: .separatorGray)
    private let statusIndicator = TxStatusIndicator(width: 44.0)
    private let failedIndicator = UIButton(type: .system)
    private var pendingConstraints = [NSLayoutConstraint]()
    private var completeConstraints = [NSLayoutConstraint]()
    private var statusIconContainer: UIView?
    private var statusIconHosting: Any?
    
    // MARK: Vars
    
    private var viewModel: TxListViewModel!
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    func setTransaction(_ viewModel: TxListViewModel, showFiatAmounts: Bool, rate: Rate, isSyncing: Bool) {
        self.viewModel = viewModel
        
        if #available(iOS 13.0, *) {
            if let hosting = statusIconHosting as? UIHostingController<TxStatusIcon> {
                hosting.rootView = TxStatusIcon(status: viewModel.icon)
            }
        }
        
        descriptionLabel.text = viewModel.shortDescription
        amount.attributedText = viewModel.amount(showFiatAmounts: showFiatAmounts, rate: rate)
        
        statusIndicator.status = viewModel.status
        
        switch viewModel.status {
        case .invalid:
            timestamp.text = S.Transaction.failed
            failedIndicator.isHidden = false
            statusIndicator.isHidden = true
            if #available(iOS 13, *) {
                timestamp.isHidden = false
                NSLayoutConstraint.activate(completeConstraints)
            } else {
                timestamp.isHidden = true
                NSLayoutConstraint.deactivate(completeConstraints)
                NSLayoutConstraint.activate(pendingConstraints)
            }
        case .complete:
            timestamp.text = viewModel.shortTimestamp
            failedIndicator.isHidden = true
            statusIndicator.isHidden = true
            timestamp.isHidden = false
            if #available(iOS 13, *) {
                NSLayoutConstraint.activate(completeConstraints)
            } else {
                NSLayoutConstraint.deactivate(pendingConstraints)
                NSLayoutConstraint.activate(completeConstraints)
            }
        default:
            failedIndicator.isHidden = true
            statusIndicator.isHidden = false
            timestamp.isHidden = false
            timestamp.text = "\(viewModel.confirmations)/\(viewModel.currency.confirmationsUntilFinal) " + S.TransactionDetails.confirmationsLabel
            
            if #available(iOS 13, *) {
                NSLayoutConstraint.activate(completeConstraints)
                NSLayoutConstraint.deactivate(pendingConstraints)
            } else {
               NSLayoutConstraint.deactivate(completeConstraints)
               NSLayoutConstraint.activate(pendingConstraints)
            }
        }
  
        if #available(iOS 13, *) {
            failedIndicator.isHidden = true
            statusIndicator.isHidden = true
        }
    }
    
    // MARK: - Private
    
    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }
    
    private func addSubviews() {
        if #available(iOS 13.0, *) {
            let icon = TxStatusIcon(status: .sent)
            let iconContainer = UIHostingController(rootView: icon)
            contentView.addSubview(iconContainer.view)
            statusIconContainer = iconContainer.view
            statusIconHosting = iconContainer
        }
        contentView.addSubview(timestamp)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(statusIndicator)
        contentView.addSubview(failedIndicator)
        contentView.addSubview(amount)
        contentView.addSubview(separator)
    }
    
    private func addConstraints() {
        if let statusIcon = statusIconContainer {
            statusIcon.constrain([
                statusIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2]),
                statusIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        let leadingXAnchor = statusIconContainer == nil ? contentView.leadingAnchor : statusIconContainer!.trailingAnchor
        
        timestamp.constrain([
            timestamp.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[2]),
            timestamp.leadingAnchor.constraint(equalTo: leadingXAnchor, constant: C.padding[2])])
        descriptionLabel.constrain([
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[2]),
            descriptionLabel.leadingAnchor.constraint(equalTo: timestamp.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: amount.leadingAnchor, constant: -C.padding[2])
        ])
        pendingConstraints = [
            descriptionLabel.centerYAnchor.constraint(equalTo: statusIndicator.centerYAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: C.padding[1]),
            descriptionLabel.heightAnchor.constraint(equalToConstant: 48.0)]
        completeConstraints = [
            descriptionLabel.topAnchor.constraint(equalTo: timestamp.bottomAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: timestamp.leadingAnchor) ]
        statusIndicator.constrain([
            statusIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2]),
            statusIndicator.widthAnchor.constraint(equalToConstant: statusIndicator.width),
            statusIndicator.heightAnchor.constraint(equalToConstant: statusIndicator.height)])
        failedIndicator.constrain([
            failedIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            failedIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2]),
            failedIndicator.widthAnchor.constraint(equalToConstant: statusIndicator.width),
            failedIndicator.heightAnchor.constraint(equalToConstant: 20.0)])
        amount.constrain([
            amount.topAnchor.constraint(equalTo: contentView.topAnchor),
            amount.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            amount.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[2])])
        separator.constrainBottomCorners(height: 0.5)
    }
    
    private func setupStyle() {
        selectionStyle = .none
        amount.textAlignment = .right
        descriptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        descriptionLabel.lineBreakMode = .byTruncatingTail
        
        failedIndicator.setTitle(S.Transaction.failed, for: .normal)
        failedIndicator.titleLabel?.font = .customBold(size: 12.0)
        failedIndicator.setTitleColor(.white, for: .normal)
        failedIndicator.backgroundColor = .failedRed
        failedIndicator.layer.cornerRadius = 3
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
