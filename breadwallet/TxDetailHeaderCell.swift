//
//  TxDetailHeaderCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-21.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxDetailHeaderCell: UITableViewCell {
    
    // MARK: - Accessors
    
    public var fiatAmount: String {
        get {
            return fiatAmountLabel.text ?? ""
        }
        set {
            fiatAmountLabel.text = newValue
        }
    }
    
    public var tokenAmount: String {
        get {
            return tokenAmountLabel.text ?? ""
        }
        set {
            tokenAmountLabel.text = newValue
        }
    }

    // MARK: - Views
    
    internal let container = UIView()
    internal let fiatAmountLabel = UILabel(font: UIFont.customBold(size: 15.0))
    internal let tokenAmountLabel = UILabel(font: UIFont.customMedium(size: 13.0))
    internal let separator = UIView(color: .secondaryShadow)
    
    // MARK: - Init
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }
    
    internal func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(fiatAmountLabel)
        container.addSubview(tokenAmountLabel)
        container.addSubview(separator)
    }
    
    internal func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets.zero)
        fiatAmountLabel.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[4])
        tokenAmountLabel.pinTo(viewAbove: fiatAmountLabel, padding: C.padding[1])
        separator.constrainBottomCorners(height: 0.5)
    }
    
    internal func setupStyle() {
        fiatAmountLabel.textColor = .txListGreen
        fiatAmountLabel.textAlignment = .center
        tokenAmountLabel.textColor = .grayText
        tokenAmountLabel.textAlignment = .center
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
