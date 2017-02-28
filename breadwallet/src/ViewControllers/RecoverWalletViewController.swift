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
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let store: Store
    private let walletManager: WalletManager
    private let enterPhrase = EnterPhraseCollectionViewController()
    private let errorLabel = UILabel(font: .customBody(size: 16.0), color: .cameraGuideNegative)
    private let instruction = UILabel(font: .customBold(size: 14.0), color: .darkText)

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        addChildViewController(enterPhrase, layout: {
            enterPhrase.view.constrain([
                enterPhrase.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
                enterPhrase.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
                enterPhrase.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
                enterPhrase.view.heightAnchor.constraint(equalToConstant: 273.0) ])
        })
        view.addSubview(errorLabel)
        view.addSubview(instruction)
    }

    private func addConstraints() {
        errorLabel.constrain([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: enterPhrase.view.bottomAnchor, constant: C.padding[1]) ])
        instruction.constrain([
            instruction.bottomAnchor.constraint(equalTo: enterPhrase.view.topAnchor, constant: -C.padding[1]),
            instruction.leadingAnchor.constraint(equalTo: enterPhrase.view.leadingAnchor) ])
    }

    private func setData() {
        view.backgroundColor = .secondaryButton
        errorLabel.text = "Invalid Phrase"
        errorLabel.isHidden = true
        errorLabel.textAlignment = .center
        enterPhrase.didFinishPhraseEntry = { [weak self] phrase in
            self?.validatePhrase(phrase)
        }
        instruction.text = S.RecoverWallet.instruction
    }

    private func validatePhrase(_ phrase: String) {
        guard walletManager.isPhraseValid(phrase) else {
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true

        if self.walletManager.setSeedPhrase(testPhrase) {
            didSetSeedPhrase?(testPhrase)
        } else {
            //TODO - handle failure
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
