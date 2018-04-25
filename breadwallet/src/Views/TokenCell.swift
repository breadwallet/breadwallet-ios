//
//  TokenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-08.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class TokenCell : UITableViewCell {

    private let header = UILabel(font: .customBold(size: 18.0), color: .darkText)
    private let subheader = UILabel(font: .customBody(size: 16.0), color: .secondaryShadow)
    private let icon = UIImageView()
    private let button = UIButton.outline(title: S.TokenList.add)
    private var identifier: String = ""
    private var listType: TokenListType = .add
    private var isCurrencyHidden = false

    var didAddIdentifier:((String)->Void)?
    var didRemoveIdentifier:((String)->Void)?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func set(currency: CurrencyDef, listType: TokenListType, isHidden: Bool) {
        header.text = currency.code
        subheader.text = currency.name
        icon.image = UIImage(named: currency.code.lowercased())
        self.isCurrencyHidden = isHidden
        if let token = currency as? ERC20Token {
            self.identifier = token.address
        } else {
            self.identifier = currency.code
        }
        self.listType = listType
        setInitialButtonState()
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
            icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[1]),
            icon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[1]),
            icon.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[1]),
            icon.heightAnchor.constraint(equalToConstant: 44.0),
            icon.widthAnchor.constraint(equalToConstant: 44.0)])
        header.constrain([
            header.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: C.padding[1]),
            header.bottomAnchor.constraint(equalTo: contentView.centerYAnchor)])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: C.padding[1]),
            subheader.topAnchor.constraint(equalTo: contentView.centerYAnchor)])
        button.constrain([
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[1]),
            button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[1]),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[1]),
            button.widthAnchor.constraint(equalToConstant: 80.0)])
    }

    private func setInitialData() {
        selectionStyle = .none
        icon.contentMode = .scaleAspectFill
        setInitialButtonState()
    }
    
    private func setInitialButtonState() {
        isCurrencyHidden ? setAddButton() : setRemoveButton()
        button.tap = strongify(self) { myself in
            if myself.button.layer.borderColor == UIColor.blue.cgColor {
                myself.setRemoveButton()
                myself.didAddIdentifier?(myself.identifier)
            } else {
                myself.setAddButton()
                myself.didRemoveIdentifier?(myself.identifier)
            }
        }
    }
    
    private func setAddButton() {
        button.layer.borderColor = UIColor.blue.cgColor
        button.setTitle(listType.addTitle, for: .normal)
        button.tintColor = .blue
    }
    
    private func setRemoveButton() {
        button.layer.borderColor = UIColor.red.cgColor
        button.setTitle(listType.removeTitle, for: .normal)
        button.tintColor = .red
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

