//
//  TouchIdSettingsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class MyTextView : UITextView {
    override var canBecomeFirstResponder: Bool {
        return false
    }
}

class TouchIdSettingsViewController : UIViewController {

    var presentSpendingLimit: (() -> Void)?

    private let header = RadialGradientView(backgroundColor: .darkPurple)
    private let illustration = UIImageView(image: #imageLiteral(resourceName: "TouchId-Large"))
    private let label = UILabel.wrapping(font: .customBody(size: 16.0), color: .darkText)
    private let switchLabel = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let toggle = UISwitch()
    private let separator = UIView(color: .secondaryShadow)
    private let textView = MyTextView()
    private let walletManager: WalletManager

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(illustration)
        view.addSubview(label)
        view.addSubview(switchLabel)
        view.addSubview(toggle)
        view.addSubview(separator)
        view.addSubview(textView)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0.0, topPadding: 0.0)
        header.constrain([header.heightAnchor.constraint(equalToConstant: C.Sizes.largeHeaderHeight)])
        illustration.constrain([
            illustration.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            illustration.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: C.padding[2]) ])
        label.constrain([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: C.padding[2]),
            label.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -C.padding[2]) ])
        switchLabel.constrain([
            switchLabel.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            switchLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: C.padding[2]) ])
        toggle.constrain([
            toggle.centerYAnchor.constraint(equalTo: switchLabel.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: label.trailingAnchor) ])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: switchLabel.leadingAnchor),
            separator.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: C.padding[1]),
            separator.trailingAnchor.constraint(equalTo: toggle.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        textView.constrain([
            textView.leadingAnchor.constraint(equalTo: separator.leadingAnchor),
            textView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[2]),
            textView.trailingAnchor.constraint(equalTo: separator.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor )])
    }

    private func setData() {
        view.backgroundColor = .white
        title = S.TouchIdSettings.title
        label.text = S.TouchIdSettings.label
        switchLabel.text = S.TouchIdSettings.switchLabel
        textView.isEditable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0.0
        textView.delegate = self
        textView.attributedText = textViewText
        textView.tintColor = .primaryButton
        toggle.isOn = walletManager.spendingLimit > 0
        toggle.valueChanged = {
            print("isOn: \(self.toggle.isOn)")
        }
    }

    private var textViewText: NSAttributedString {
        let string = "Spending Limit: 1btc = $678.93 USD \n\nYou can customize your Touch ID Spending Limit from the "
        let link = "Touch ID Spending Limit Screen"
        let attributedString = NSMutableAttributedString(string: string, attributes: [
                NSFontAttributeName: UIFont.customBody(size: 13.0),
                NSForegroundColorAttributeName: UIColor.darkText
            ])
        let attributedLink = NSMutableAttributedString(string: link, attributes: [
                NSFontAttributeName: UIFont.customMedium(size: 13.0),
                NSLinkAttributeName: NSURL(string:"http://spending-limit")!
            ])
        attributedString.append(attributedLink)
        return attributedString
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TouchIdSettingsViewController : UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        presentSpendingLimit?()
        return false
    }
}
