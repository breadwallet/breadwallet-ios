//
//  TokenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-08.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum EditWalletType {
    case manage
    case add
    
    var addTitle: String {
        return self == .manage ? S.TokenList.show : S.TokenList.add
    }
    
    var removeTitle: String {
        return self == .manage ? S.TokenList.hide : S.TokenList.remove
    }
}

class ManageCurrencyCell: SeparatorCell {
    
    static let cellIdentifier = "ManageCurrencyCell"
    
    private let addColor = UIColor.navigationTint
    private let removeColor = UIColor.orangeButton

    private let header = UILabel(font: Theme.h3Title, color: UIColor.white)
    private let subheader = UILabel(font: .customBody(size: 14.0), color: UIColor.transparentWhiteText)
    private let icon = UIImageView()
    private let balanceLabel = UILabel(font: Theme.body3, color: Theme.secondaryText)
    private let button = ToggleButton(normalTitle: S.TokenList.add, normalColor: .navigationTint, selectedTitle: S.TokenList.hide, selectedColor: .orangeButton)
    private var identifier: CurrencyId = ""
    private var listType: EditWalletType = .add
    private var isCurrencyHidden = false
    private var isCurrencyRemovable = true
    
    var didAddIdentifier: ((CurrencyId) -> Void)?
    var didRemoveIdentifier: ((CurrencyId) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func set(currency: CurrencyMetaData, balance: Amount?, listType: EditWalletType, isHidden: Bool, isRemovable: Bool) {
        header.text = currency.name
        subheader.text = currency.code
        icon.image = currency.imageSquareBackground
        if let balance = balance, !balance.isZero {
            balanceLabel.text = balance.tokenDescription
        } else {
            balanceLabel.text = ""
        }
        self.isCurrencyHidden = isHidden
        self.isCurrencyRemovable = isRemovable
        self.identifier = currency.uid
        self.listType = listType
        setState()
    }

    private func setupViews() {
        header.adjustsFontSizeToFitWidth = true
        
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        contentView.addSubview(header)
        contentView.addSubview(subheader)
        contentView.addSubview(icon)
        contentView.addSubview(balanceLabel)
        contentView.addSubview(button)
    }

    private func addConstraints() {
        icon.constrain([
            icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2]),
            icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            icon.heightAnchor.constraint(equalToConstant: 36.0),
            icon.widthAnchor.constraint(equalToConstant: 36.0)])
        header.constrain([
            header.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: C.padding[1]),
            header.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 1.0)])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: C.padding[1]),
            subheader.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -1.0)])
        button.constrain([
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[2]),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 36.0),
            button.widthAnchor.constraint(equalToConstant: 70.0),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: header.trailingAnchor, constant: C.padding[1])])
        balanceLabel.constrain([
            balanceLabel.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -C.padding[1]),
            balanceLabel.centerYAnchor.constraint(equalTo: subheader.centerYAnchor)
            ])
    }

    private func setInitialData() {
        selectionStyle = .none
        icon.contentMode = .scaleAspectFill
    }
    
    private func setState() {
        if listType == .add {
            button.setTitle(S.TokenList.add, for: .normal)
            button.setTitle(S.TokenList.remove, for: .selected)
        } else {
            button.setTitle(S.TokenList.remove, for: .normal)
            button.setTitle(S.TokenList.remove, for: .selected)
        }
        
        button.tap = strongify(self) { myself in
            if self.listType == .manage {
                myself.didRemoveIdentifier?(myself.identifier)
            } else if self.listType == .add {
                let isRemoveButton = myself.button.isSelected
                if isRemoveButton {
                    myself.didRemoveIdentifier?(myself.identifier)
                } else {
                    myself.didAddIdentifier?(myself.identifier)
                }
                myself.button.isSelected = !isRemoveButton
            }
        }
        if listType == .add {
            button.isSelected = !isCurrencyHidden
        } else {
            button.isEnabled = isCurrencyRemovable
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
