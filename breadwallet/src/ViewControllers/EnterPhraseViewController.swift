//
//  EnterPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

enum PhraseEntryReason {
    case setSeed(EnterPhraseCallback)
    case validateForResettingPin(EnterPhraseCallback)
    case validateForWipingWallet(()->Void)
}

typealias EnterPhraseCallback = (String) -> Void

class EnterPhraseViewController : UIViewController, UIScrollViewDelegate, Trackable {

    init(walletManager: BTCWalletManager, reason: PhraseEntryReason) {
        self.walletManager = walletManager
        self.enterPhrase = EnterPhraseCollectionViewController(walletManager: walletManager)
        self.faq = UIButton.buildFaqButton(articleId: ArticleIds.recoverWallet)
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }

    //MARK: - Private
    private let walletManager: BTCWalletManager
    private let reason: PhraseEntryReason
    private let enterPhrase: EnterPhraseCollectionViewController
    private let errorLabel = UILabel.wrapping(font: .customBody(size: 16.0), color: .cameraGuideNegative)
    private let instruction = UILabel(font: .customBold(size: 14.0), color: .white)
    private let subheader = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    private let faq: UIButton
    private let scrollView = UIScrollView()
    private let container = UIView()
    private let moreInfoButton = UIButton(type: .system)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(container)
        container.addSubview(subheader)
        container.addSubview(errorLabel)
        container.addSubview(instruction)
        container.addSubview(faq)
        container.addSubview(moreInfoButton)

        addChildViewController(enterPhrase)
        container.addSubview(enterPhrase.view)
        enterPhrase.didMove(toParentViewController: self)
    }

    private var navBarHeight: CGFloat {
        guard let height = self.navigationController?.navigationBar.frame.height else {
            return 44
        }
        return height
    }
    
    private var statusBarHeight: CGFloat {
        return UIApplication.shared.statusBarFrame.height
    }
    
    private func addConstraints() {
        // Prevent the scroll view content from being visible behind the clear-background
        // nav bar by setting its top constraint to account for the nav bar and status bar.
        scrollView.constrain(toSuperviewEdges: UIEdgeInsets(top: navBarHeight + statusBarHeight, left: 0, bottom: 0, right: 0))
        
        scrollView.constrain([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor) ])
        container.constrain(toSuperviewEdges: nil)
        container.constrain([
            container.widthAnchor.constraint(equalTo: view.widthAnchor) ])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            subheader.topAnchor.constraint(equalTo: container.topAnchor),
            subheader.trailingAnchor.constraint(equalTo: faq.leadingAnchor, constant: -C.padding[2])])
        instruction.constrain([
            instruction.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: C.padding[3]),
            instruction.leadingAnchor.constraint(equalTo: subheader.leadingAnchor, constant: C.padding[2])])
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
            faq.centerYAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]),
            faq.widthAnchor.constraint(equalToConstant: 44.0),
            faq.heightAnchor.constraint(equalToConstant: 44.0) ])
        moreInfoButton.constrain([
            moreInfoButton.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: C.padding[2]),
            moreInfoButton.leadingAnchor.constraint(equalTo: subheader.leadingAnchor) ])
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        errorLabel.text = S.RecoverWallet.invalid
        errorLabel.isHidden = true
        errorLabel.textAlignment = .center
        enterPhrase.didFinishPhraseEntry = { [weak self] phrase in
            self?.validatePhrase(phrase)
        }
        instruction.text = S.RecoverWallet.instruction
        faq.tintColor = .white
        switch reason {
        case .setSeed(_):
            saveEvent("enterPhrase.setSeed")
            title = S.RecoverWallet.header
            subheader.text = S.RecoverWallet.subheader
            moreInfoButton.isHidden = true
        case .validateForResettingPin(_):
            saveEvent("enterPhrase.resettingPin")
            title = S.RecoverWallet.headerResetPin
            subheader.text = S.RecoverWallet.subheaderResetPin
            instruction.isHidden = true
            moreInfoButton.setTitle(S.RecoverWallet.resetPinInfo, for: .normal)
            moreInfoButton.tap = {
                Store.trigger(name: .presentFaq(ArticleIds.resetPinWithPaperKey, nil))
            }
            faq.isHidden = true
        case .validateForWipingWallet(_):
            saveEvent("enterPhrase.wipeWallet")
            title = S.WipeWallet.title
            subheader.text = S.WipeWallet.instruction
        }

        scrollView.delegate = self
    }

    private func validatePhrase(_ phrase: String) {
        guard walletManager.isPhraseValid(phrase) else {
            saveEvent("enterPhrase.invalid")
            errorLabel.isHidden = false
            return
        }
        saveEvent("enterPhrase.valid")
        errorLabel.isHidden = true

        switch reason {
        case .setSeed(let callback):
            guard self.walletManager.setSeedPhrase(phrase) else { errorLabel.isHidden = false; return }
            //Since we know that the user had their phrase at this point,
            //this counts as a write date
            UserDefaults.writePaperPhraseDate = Date()
            Store.perform(action: LoginSuccess())
            return callback(phrase)
        case .validateForResettingPin(let callback):
            guard self.walletManager.authenticate(phrase: phrase) else { errorLabel.isHidden = false; return }
            UserDefaults.writePaperPhraseDate = Date()
            return callback(phrase)
        case .validateForWipingWallet(let callback):
            guard self.walletManager.authenticate(phrase: phrase) else { errorLabel.isHidden = false; return }
            return callback()
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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
