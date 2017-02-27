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
    }

    private func addConstraints() {
        errorLabel.constrain([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: enterPhrase.view.bottomAnchor, constant: C.padding[1]) ])
    }

    private func setData() {
        view.backgroundColor = .white
        errorLabel.text = "Invalid Phrase"
        errorLabel.isHidden = true
        errorLabel.textAlignment = .center
        enterPhrase.didFinishPhraseEntry = { [weak self] phrase in
            self?.validatePhrase(phrase)
        }
    }

    private func validatePhrase(_ phrase: String) {
        guard walletManager.isPhraseValid(phrase) else {
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true

//        if self.walletManager.setSeedPhrase(phrase) {
//            //set pin let setPinResult = self.walletManager.forceSetPin(newPin: pin, seedPhrase: phrase)
//            //peerManager.connect()
//        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
