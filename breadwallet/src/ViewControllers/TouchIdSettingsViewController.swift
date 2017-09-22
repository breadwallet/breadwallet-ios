//
//  TouchIdSettingsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

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
    private let toggle = GradientSwitch()
    private let separator = UIView(color: .secondaryShadow)
    private let textView = UnEditableTextView()
    private let walletManager: WalletManager
    private let store: Store
    private var rate: Rate?
    fileprivate var didTapSpendingLimit = false

    deinit {
        store.unsubscribe(self)
    }

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
        textView.attributedText = textViewText
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
        addFaqButton()
        let hasSetToggleInitialValue = false
        store.subscribe(self, selector: { $0.isTouchIdEnabled != $1.isTouchIdEnabled }, callback: {
            self.toggle.isOn = $0.isTouchIdEnabled
            if !hasSetToggleInitialValue {
                self.toggle.sendActions(for: .valueChanged) //This event is needed because the gradient background gets set on valueChanged events
            }
        })
        toggle.valueChanged = { [weak self] in
            guard let myself = self else { return }
            if LAContext.canUseTouchID {
                myself.store.perform(action: TouchId.setIsEnabled(myself.toggle.isOn))
                myself.textView.attributedText = myself.textViewText
            } else {
                myself.presentCantUseTouchIdAlert()
                myself.toggle.isOn = false
            }
        }
    }

    private func addFaqButton() {
        let negativePadding = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        negativePadding.width = -16.0
        let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.enableTouchId)
        faqButton.tintColor = .white
        navigationItem.rightBarButtonItems = [negativePadding, UIBarButtonItem(customView: faqButton)]
    }

    private var textViewText: NSAttributedString {
        guard let rate = rate else { return NSAttributedString(string: "") }
        let amount = Amount(amount: walletManager.spendingLimit, rate: rate, maxDigits: store.state.maxDigits)
        let string = "\(String(format: S.TouchIdSettings.spendingLimit, amount.bits, amount.localCurrency))\n\n\(String(format: S.TouchIdSettings.customizeText, S.TouchIdSettings.linkText))"
        let linkText = S.TouchIdSettings.linkText
        let attributedString = NSMutableAttributedString(string: string, attributes: [
                NSAttributedStringKey.font: UIFont.customBody(size: 13.0),
                NSAttributedStringKey.foregroundColor: UIColor.darkText
            ])
        let linkAttributes = [
                NSAttributedStringKey.font: UIFont.customMedium(size: 13.0),
                NSAttributedStringKey.link: NSURL(string:"http://spending-limit")!]

        if let range = string.range(of: linkText, options: [], range: nil, locale: nil) {
            let from = range.lowerBound.samePosition(in: string.utf16)!
            let to = range.upperBound.samePosition(in: string.utf16)!
            attributedString.addAttributes(linkAttributes, range: NSRange(location: string.utf16.distance(from: string.utf16.startIndex, to: from),
                                                                          length: string.utf16.distance(from: from, to: to)))
        }

        return attributedString
    }

    fileprivate func presentCantUseTouchIdAlert() {
        let alert = UIAlertController(title: S.TouchIdSettings.unavailableAlertTitle, message: S.TouchIdSettings.unavailableAlertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
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
        if LAContext.canUseTouchID {
            guard !didTapSpendingLimit else { return false }
            didTapSpendingLimit = true
            presentSpendingLimit?()
        } else {
            presentCantUseTouchIdAlert()
        }
        return false
    }
}
