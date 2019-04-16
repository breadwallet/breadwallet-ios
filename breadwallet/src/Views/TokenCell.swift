//
//  TokenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-08.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class TokenCell: SeparatorCell {
    
    static let cellIdentifier = "TokenCell"
    
    private let addColor = UIColor.navigationTint
    private let removeColor = UIColor.orangeButton

    private let header = UILabel(font: .customBold(size: 18.0), color: UIColor.white)
    private let subheader = UILabel(font: .customBody(size: 14.0), color: UIColor.transparentWhiteText)
    private let icon = UIImageView()
    private let button = ToggleButton(normalTitle: S.TokenList.add, normalColor: .navigationTint, selectedTitle: S.TokenList.hide, selectedColor: .orangeButton)
    private var identifier: String = ""
    private var listType: TokenListType = .add
    private var isCurrencyHidden = false

    var didAddIdentifier: ((String) -> Void)?
    var didRemoveIdentifier: ((String) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func set(currency: Currency, listType: TokenListType, isHidden: Bool) {
        header.text = currency.name
        subheader.text = currency.code
        icon.image = currency.imageSquareBackground
        self.isCurrencyHidden = isHidden
        self.identifier = currency.tokenAddress ?? currency.code
        self.listType = listType
        setState()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        contentView.addSubview(header)
        contentView.addSubview(subheader)
        contentView.addSubview(icon)
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
            button.widthAnchor.constraint(equalToConstant: 70.0)])
    }

    private func setInitialData() {
        selectionStyle = .none
        icon.contentMode = .scaleAspectFill
        setState()
    }
    
    private func setState() {
        if listType == .add {
            button.setTitle(S.TokenList.add, for: .normal)
            button.setTitle(S.TokenList.remove, for: .selected)
        } else {
            button.setTitle(S.TokenList.show, for: .normal)
            button.setTitle(S.TokenList.hide, for: .selected)
        }
        
        button.tap = strongify(self) { myself in
            let isRemoveButton = myself.button.isSelected
            if isRemoveButton {
                myself.didRemoveIdentifier?(myself.identifier)
            } else {
                myself.didAddIdentifier?(myself.identifier)
            }
            myself.button.isSelected = !isRemoveButton
        }
        
        button.isSelected = !isCurrencyHidden
        
        if listType == .manage {
            let alpha: CGFloat = isCurrencyHidden ? 0.5 : 1.0
            header.alpha = alpha
            subheader.alpha = alpha
            icon.alpha = alpha
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
