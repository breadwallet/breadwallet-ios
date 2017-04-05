//
//  RecoverWalletViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class RecoverWalletViewController : UIViewController {

    //MARK: - Public
    var didSetSeedPhrase: ((String) -> Void)?

    init(store: Store, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
        self.enterPhrase = EnterPhraseCollectionViewController(walletManager: walletManager)
        self.faq = UIButton.buildFaqButton(store: store)
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }

    //MARK: - Private
    private let store: Store
    private let walletManager: WalletManager
    private let enterPhrase: EnterPhraseCollectionViewController
    private let errorLabel = UILabel(font: .customBody(size: 16.0), color: .cameraGuideNegative)
    private let instruction = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let header = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let subheader = UILabel(font: .customBody(size: 16.0), color: .darkText)
    private let faq: UIButton
    private let scrollView = UIScrollView()
    private let container = UIView()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(container)
        container.addSubview(header)
        container.addSubview(subheader)
        container.addSubview(errorLabel)
        container.addSubview(instruction)
        container.addSubview(faq)
        
        addChildViewController(enterPhrase)
        container.addSubview(enterPhrase.view)
        enterPhrase.didMove(toParentViewController: self)
    }

    private func addConstraints() {
        scrollView.constrain(toSuperviewEdges: nil)
        container.constrain(toSuperviewEdges: nil)
        container.constrain([
            container.widthAnchor.constraint(equalTo: view.widthAnchor) ])
        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[1]) ])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subheader.topAnchor.constraint(equalTo: header.bottomAnchor),
            subheader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        instruction.constrain([
            instruction.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: C.padding[3]),
            instruction.leadingAnchor.constraint(equalTo: subheader.leadingAnchor) ])
        enterPhrase.view.constrain([
            enterPhrase.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            enterPhrase.view.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: C.padding[1]),
            enterPhrase.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            enterPhrase.view.heightAnchor.constraint(equalToConstant: enterPhrase.height) ])
        errorLabel.constrain([
            errorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            errorLabel.topAnchor.constraint(equalTo: enterPhrase.view.bottomAnchor, constant: C.padding[1]),
            errorLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            errorLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2] )])
        faq.constrain([
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            faq.widthAnchor.constraint(equalToConstant: 44.0),
            faq.heightAnchor.constraint(equalToConstant: 44.0) ])
    }

    private func setData() {
        view.backgroundColor = .secondaryButton
        errorLabel.text = S.RecoverWallet.invalid
        errorLabel.isHidden = true
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.lineBreakMode = .byWordWrapping
        enterPhrase.didFinishPhraseEntry = { [weak self] phrase in
            self?.validatePhrase(phrase)
        }
        instruction.text = S.RecoverWallet.instruction
        header.text = S.RecoverWallet.header
        subheader.text = S.RecoverWallet.subheader
        subheader.numberOfLines = 0
        subheader.lineBreakMode = .byWordWrapping
    }

    private func validatePhrase(_ phrase: String) {
        guard walletManager.isPhraseValid(phrase) else {
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true

        if self.walletManager.setSeedPhrase(phrase) {
            didSetSeedPhrase?(phrase)
        } else {
            //TODO - handle failure
        }
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let frameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
        var contentInset = scrollView.contentInset
        if contentInset.bottom == 0.0 {
            contentInset.bottom = frameValue.cgRectValue.height + 44.0
        }
        scrollView.contentInset = contentInset
    }

    @objc private func keyboardWillHide(notification: Notification) {
        var contentInset = scrollView.contentInset
        if contentInset.bottom > 0.0 {
            contentInset.bottom = 0.0
        }
        scrollView.contentInset = contentInset
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
