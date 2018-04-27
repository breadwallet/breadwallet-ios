//
//  TokenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-08.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class TokenCell : UITableViewCell {

    private let header = UILabel(font: .customBold(size: 18.0), color: UIColor.fromHex("546875"))
    private let subheader = UILabel(font: .customBody(size: 16.0), color: UIColor.fromHex("546875"))
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
            icon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[1]),
            icon.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[1]),
            icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2]),
            icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            icon.heightAnchor.constraint(equalToConstant: 40.0),
            icon.widthAnchor.constraint(equalToConstant: 40.0)])
        header.constrain([
            header.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: C.padding[1]),
            header.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 1.0)])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: C.padding[1]),
            subheader.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -1.0)])
        button.constrain([
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[2]),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 40.0),
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

