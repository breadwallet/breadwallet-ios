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
    private let iconBackground = UIView()
    private let button = UIButton.outline(title: S.TokenList.add)
    private var address: String = ""
    
    var didAddToken:((String)->Void)?
    var didRemoveToken:((String)->Void)?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func set(name: String, code: String, address: String) {
        header.text = code
        subheader.text = name
        icon.image = #imageLiteral(resourceName: "TempBLogo")
        self.address = address
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        contentView.addSubview(header)
        contentView.addSubview(subheader)
        contentView.addSubview(iconBackground)
        iconBackground.addSubview(icon)
        contentView.addSubview(button)
    }

    private func addConstraints() {
        iconBackground.constrain([
            iconBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[1]),
            iconBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[1]),
            iconBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[1]),
            iconBackground.heightAnchor.constraint(equalToConstant: 44.0),
            iconBackground.widthAnchor.constraint(equalToConstant: 44.0)])
        icon.constrain(toSuperviewEdges: UIEdgeInsetsMake(C.padding[1], C.padding[1]+2, -C.padding[1], -C.padding[1]))
        header.constrain([
            header.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: C.padding[1]),
            header.bottomAnchor.constraint(equalTo: contentView.centerYAnchor)])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: C.padding[1]),
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
        iconBackground.backgroundColor = .blue
        iconBackground.layer.cornerRadius = 4.0
        iconBackground.layer.masksToBounds = true
        button.tap = strongify(self) { myself in
            if myself.button.layer.borderColor == UIColor.blue.cgColor {
                myself.button.layer.borderColor = UIColor.red.cgColor
                myself.button.setTitle(S.TokenList.remove, for: .normal)
                myself.button.tintColor = .red
                myself.didAddToken?(myself.address)
            } else {
                myself.button.layer.borderColor = UIColor.blue.cgColor
                myself.button.setTitle(S.TokenList.add, for: .normal)
                myself.button.tintColor  = .blue
                myself.didRemoveToken?(myself.address)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

