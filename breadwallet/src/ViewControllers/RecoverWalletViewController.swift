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
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let store: Store
    private let walletManager: WalletManager
    private let enterPhrase: EnterPhraseCollectionViewController
    private let errorLabel = UILabel(font: .customBody(size: 16.0), color: .cameraGuideNegative)
    private let instruction = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let header = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let subheader = UILabel(font: .customBody(size: 16.0), color: .darkText)
    private let faq = UIButton.faq

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(subheader)
        view.addSubview(errorLabel)
        view.addSubview(instruction)
        view.addSubview(faq)
        addChildViewController(enterPhrase, layout: {
            enterPhrase.view.constrain([
                enterPhrase.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
                enterPhrase.view.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: C.padding[1]),
                enterPhrase.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
                enterPhrase.view.heightAnchor.constraint(equalToConstant: 273.0) ])
        })
    }

    private func addConstraints() {
        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[1]) ])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subheader.topAnchor.constraint(equalTo: header.bottomAnchor),
            subheader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        instruction.constrain([
            instruction.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: C.padding[3]),
            instruction.leadingAnchor.constraint(equalTo: subheader.leadingAnchor) ])
        errorLabel.constrain([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: enterPhrase.view.bottomAnchor, constant: C.padding[1]) ])
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
