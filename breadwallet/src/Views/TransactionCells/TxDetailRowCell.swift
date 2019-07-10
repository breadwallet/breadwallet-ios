//
//  TxDetailRowCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-21.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
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
    internal let titleLabel = UILabel(font: UIFont.customBody(size: 14.0))
    internal let separator = UIView(color: .secondaryShadow)
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
        contentView.addSubview(separator)
        container.addSubview(titleLabel)
    }
    
    internal func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: C.padding[2],
                                                           bottom: -C.padding[1],
                                                           right: -C.padding[2]))
        container.constrain([container.heightAnchor.constraint(greaterThanOrEqualToConstant: 29.0)])
        
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.constraint(toTop: container, constant: C.padding[3])
            ])
        separator.constrainTopCorners(height: 0.5)
    }
    
    internal func setupStyle() {
        titleLabel.textColor = .lightGray
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
