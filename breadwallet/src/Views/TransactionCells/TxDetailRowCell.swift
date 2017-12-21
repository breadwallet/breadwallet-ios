//
//  TxDetailRowCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-21.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxDetailRowCell: UITableViewCell {
    
    // MARK: - Accessors
    
    public var title: String {
        get {
            return titleLabel.text ?? ""
        }
        set {
            titleLabel.text = newValue
        }
    }

    // MARK: - Views
    
    internal let container = UIView()
    internal let titleLabel = UILabel(font: UIFont.customMedium(size: 13.0))
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
        container.addSubview(titleLabel)
        container.addSubview(separator)
    }
    
    internal func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets.zero)
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor,
                                                constant: C.padding[2]),
            titleLabel.constraint(.top, toView: container, constant: C.padding[2])
            ])
        separator.constrainBottomCorners(height: 0.5)
    }
    
    internal func setupStyle() {
        titleLabel.textColor = .grayTextTint
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
