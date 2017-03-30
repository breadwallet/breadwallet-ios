//
//  TouchIdSettingsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

class UnEditableTextView : UITextView {
    override var canBecomeFirstResponder: Bool {
        return false
    }
}

class TouchIdSettingsViewController : UIViewController, Subscriber {

    var presentSpendingLimit: (() -> Void)?

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    private let header = RadialGradientView(backgroundColor: .darkPurple)
    private let illustration = UIImageView(image: #imageLiteral(resourceName: "TouchId-Large"))
    private let label = UILabel.wrapping(font: .customBody(size: 16.0), color: .darkText)
    private let switchLabel = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let toggle = UISwitch()
    private let separator = UIView(color: .secondaryShadow)
    private let textView = UnEditableTextView()
    private let walletManager: WalletManager
    private let store: Store
    private var rate: Rate?
    fileprivate var didTapSpendingLimit = false

    override func viewDidLoad() {
        store.subscribe(self, selector: { $0.currentRate != $1.currentRate }, callback: {
            self.rate = $0.currentRate
        })
        addSubviews()
        addConstraints()
        setData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didTapSpendingLimit = false
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
        addGradientToToggle()
    }

    private func addGradientToToggle() {
        toggle.onTintColor = .clear
        let toggleBackground = GradientView()
        toggle.insertSubview(toggleBackground, at: 0)
        toggleBackground.clipsToBounds = true
        toggleBackground.layer.cornerRadius = 16.0
        toggleBackground.constrain(toSuperviewEdges: nil)
        toggleBackground.alpha = walletManager.spendingLimit > 0 ? 1.0 : 0.0
        toggle.valueChanged = { [weak self] in
            guard let myself = self else { return }
            if LAContext.canUseTouchID {
                UIView.animate(withDuration: 0.1, animations: {
                    toggleBackground.alpha = myself.toggle.isOn ? 1.0 : 0.0
                })
                myself.walletManager.spendingLimit = myself.toggle.isOn ? C.satoshis : 0
                myself.textView.attributedText = myself.textViewText
            } else {
                let alert = UIAlertController(title: S.TouchIdSettings.unavailableAlertTitle, message: S.TouchIdSettings.unavailableAlertMessage, preferredStyle: .alert)
                alert.view.tintColor = C.defaultTintColor
                alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
                myself.present(alert, animated: true, completion: nil)
                myself.toggle.isOn = false
            }
        }
    }

    private var textViewText: NSAttributedString {
        guard let rate = rate else { return NSAttributedString(string: "") }
        let amount = Amount(amount: walletManager.spendingLimit, rate: rate.rate)
        let string = "Spending Limit: \(amount.bits) = \(amount.localCurrency) \(rate.code) \n\nYou can customize your Touch ID Spending Limit from the "
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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TouchIdSettingsViewController : UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        guard !didTapSpendingLimit else { return false }
        didTapSpendingLimit = true
        presentSpendingLimit?()
        return false
    }
}
