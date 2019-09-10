//
//  ConfirmPaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class ConfirmPaperPhraseViewController: UIViewController {

    init(keyMaster: KeyMaster, pin: String, eventContext: EventContext, callback: @escaping () -> Void) {
        self.pin = pin
        self.keyMaster = keyMaster
        self.eventContext = eventContext
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
        if !E.isIPhone4 {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(keyboardWillShow(notification:)),
                                                   name: UIResponder.keyboardWillShowNotification,
                                                   object: nil)
        }
    }

    private let label = UILabel.wrapping(font: UIFont.customBody(size: 16.0))

    lazy private var confirmFirstPhrase: ConfirmPhraseView = {
        ConfirmPhraseView(text: String(format: S.ConfirmPaperPhrase.word, "\(self.indices.0 + 1)"),
                          word: self.words[self.indices.0])
    }()
    lazy private var confirmSecondPhrase: ConfirmPhraseView = {
        ConfirmPhraseView(text: String(format: S.ConfirmPaperPhrase.word, "\(self.indices.1 + 1)"),
                          word: self.words[self.indices.1])
    }()
    private let submit = BRDButton(title: S.Button.submit, type: .primary)
    private let header = RadialGradientView(backgroundColor: .pink)
    private let pin: String
    private let keyMaster: KeyMaster
    private let callback: () -> Void
    private var eventContext: EventContext = .none
    
    //Select 2 random indices from 1 to 10. The second number must
    //be at least one number away from the first.
    private let indices: (Int, Int) = {
        func random() -> Int { return Int(arc4random_uniform(10) + 1) }
        let first = random()
        var second = random()
        while !(abs(Int32(second - first)) > 1) {
            second = random()
        }
        return (first, second)
    }()
    lazy private var words: [String] = {
        guard let phraseString = self.keyMaster.seedPhrase(pin: self.pin) else { return [] }
        return phraseString.components(separatedBy: " ")
    }()

    private var notificationObservers = [String: NSObjectProtocol]()

    deinit {
        notificationObservers.values.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackEvent(event: .appeared)
    }
    
    override func viewDidLoad() {
        view.backgroundColor = .darkBackground
        label.text = S.ConfirmPaperPhrase.label
        label.textColor = .white
        
        addSubviews()
        addConstraints()
        addButtonActions()

        confirmFirstPhrase.textField.becomeFirstResponder()

        notificationObservers[UIApplication.willResignActiveNotification.rawValue] =
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }

        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.confirmPhrase)
        faqButton.tintColor = .white
        navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(label)
        view.addSubview(confirmFirstPhrase)
        view.addSubview(confirmSecondPhrase)
        view.addSubview(submit)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
            header.constraint(.height, constant: 152.0) ])
        label.constrainBottomCorners(sidePadding: C.padding[1], bottomPadding: C.padding[2])
        confirmFirstPhrase.constrain([
            confirmFirstPhrase.constraint(toBottom: header, constant: 0.0),
            confirmFirstPhrase.constraint(.width, toView: view, constant: 0.0),
            confirmFirstPhrase.constraint(.centerX, toView: view, constant: 0.0) ])
        confirmSecondPhrase.constrain([
            confirmSecondPhrase.constraint(toBottom: confirmFirstPhrase, constant: 0.0),
            confirmSecondPhrase.constraint(.width, toView: view, constant: 0.0),
            confirmSecondPhrase.constraint(.centerX, toView: view, constant: 0.0) ])
    }

    private func addButtonActions() {
        submit.addTarget(self, action: #selector(checkTextFields), for: .touchUpInside)
        confirmFirstPhrase.callback = { [weak self] in
            self?.confirmSecondPhrase.textField.becomeFirstResponder()
        }
        if E.isIPhone4 {
            confirmSecondPhrase.textField.returnKeyType = .done
            confirmSecondPhrase.doneCallback = strongify(self) { myself in
                myself.checkTextFields()
            }
        }
    }

    private func addSubmitButtonConstraints(keyboardHeight: CGFloat) {
        submit.constrain([
            submit.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -C.padding[1] - keyboardHeight),
            submit.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            submit.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            submit.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight)
        ])
    }

    @objc private func checkTextFields() {
        if confirmFirstPhrase.textField.text == words[indices.0] && confirmSecondPhrase.textField.text == words[indices.1] {
            UserDefaults.writePaperPhraseDate = Date()
            Store.trigger(name: .didWritePaperKey)
            trackEvent(event: .paperKeyCreated)
            callback()
        } else {
            confirmFirstPhrase.validate()
            confirmSecondPhrase.validate()
            trackEvent(event: .paperKeyError)
            showErrorMessage(S.ConfirmPaperPhrase.error)
        }
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        self.addSubmitButtonConstraints(keyboardHeight: frameValue.cgRectValue.height)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ConfirmPaperPhraseViewController: Trackable {
    func trackEvent(event: Event) {
        saveEvent(context: eventContext, screen: .confirmPaperKey, event: event)
    }
}
