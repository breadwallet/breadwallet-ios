//
//  AboutCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-05.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class AboutCell: UIView {
    
    let button: UIButton
    
    init(text: String, value: String? = "") {
        button = UIButton.icon(image: #imageLiteral(resourceName: "OpenBrowser"), accessibilityLabel: text)
        textView.text = value
        label.text = text
        super.init(frame: .zero)
        setupTextView()
        setup()
    }
    
    private let label = UILabel(font: .customBody(size: 16.0), color: .white)
    private let separator = UIView(color: .secondaryShadow)
    private let textView = UITextView()//(frame: CGRect(x: 0, y: 0, width: 200, height: 32))
    
    override func layoutSubviews() {
        super.layoutSubviews()
        //        textView.setNeedsUpdateConstraints()
    }
    
    private func setupTextView() {
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.font = .customBody(size: 16.0)
        textView.dataDetectorTypes = .all
        textView.isEditable = false
        textView.tintColor = Theme.icon
    }
    
    private func setup() {
        addSubview(label)
        addSubview(button)
        addSubview(textView)
        addSubview(separator)
        
        button.isHidden = !textView.text.isEmpty
        textView.isHidden = !button.isHidden
        
        label.constrain([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            label.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[2]) ])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        button.constrain([
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            button.centerYAnchor.constraint(equalTo: label.centerYAnchor) ])
        let size = textView.sizeThatFits(self.frame.size)
        textView.constrain([
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            textView.widthAnchor.constraint(equalToConstant: size.width),
            textView.heightAnchor.constraint(equalToConstant: size.height),
            textView.centerYAnchor.constraint(equalTo: label.centerYAnchor) ])
        button.tintColor = .primaryButton
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class WalletIDCell: UIView {
    
    init() {
        button = UIButton(type: .system)
        super.init(frame: .zero)
        setup()
    }
    
    private let button: UIButton
    private let label = UILabel(font: .customBody(size: 16.0), color: .white)
    private let separator = UIView(color: .secondaryShadow)
    
    private func setup() {
        addSubview(label)
        addSubview(button)
        addSubview(separator)
        
        // constraints
        label.constrain([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            label.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[2]) ])
        button.constrain([
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            button.centerYAnchor.constraint(equalTo: label.centerYAnchor) ])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        button.tintColor = .primaryButton
        
        // properties
        button.setTitle(S.URLHandling.copy, for: .normal)
        let title = NSMutableAttributedString(string: S.About.walletID)
        if let walletID = Store.state.walletID {
            title.append(NSAttributedString(string: "\n\(walletID)", attributes: [.foregroundColor: UIColor.darkGray]))
            button.tap = { [unowned self] in
                self.button.tempDisable()
                Store.trigger(name: .lightWeightAlert(S.Receive.copied))
                UIPasteboard.general.string = walletID
            }
        }
        label.numberOfLines = 2
        label.attributedText = title
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
