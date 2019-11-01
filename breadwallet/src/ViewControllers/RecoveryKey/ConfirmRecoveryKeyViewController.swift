//
//  ConfirmRecoveryKeyViewController.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-04-09.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

class ConfirmRecoveryKeyViewController: BaseRecoveryKeyViewController {
    
    private var onConfirmedWords: (() -> Void)?
    
    private let keyMaster: KeyMaster
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let firstWordInputView = RecoveryKeyWordInputView()
    private let secondWordInputView = RecoveryKeyWordInputView()
    private let continueButton = BRDButton(title: S.Button.continueAction, type: .primary)

    typealias ConfirmationWordIndices = (first: Int, second: Int)

    private let confirmationIndices: (ConfirmationWordIndices) = {
        func random() -> Int { return Int(arc4random_uniform(10) + 1) }
        let first = random()
        var second = random()
        while !(abs(Int32(second - first)) > 1) {
            second = random()
        }
        return (first, second)
    }()
    
    private let words: [String]

    private var confirmationWords: [String] {
        return [words[confirmationIndices.first], words[confirmationIndices.second]]
    }

    private func confirmationWordLabel(_ index: Int) -> String {
        return String(format: S.ConfirmPaperPhrase.word, "\(index + 1)") // zero-based array, so add one
    }
    
    private var notificationObservers = [String: NSObjectProtocol]()
    
    // MARK: -
        
    init(words: [String], keyMaster: KeyMaster, eventContext: EventContext, confirmed: (() -> Void)?) {
        self.words = words
        self.onConfirmedWords = confirmed
        self.keyMaster = keyMaster
        super.init(eventContext, .confirmPaperKey)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.primaryBackground
        
        showBackButton()
        showCloseButton()
        setUpTitles()
        setUpInputFields()
        setUpContinueButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        listenForBackgroundNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeNotifications()
    }
    
    private func listenForBackgroundNotification() {
        notificationObservers[UIApplication.willResignActiveNotification.rawValue] =
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
                self?.dismiss(animated: false, completion: nil)
        }
    }
    
    private func unsubscribeNotifications() {
        notificationObservers.values.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    override var closeButtonStyle: BaseRecoveryKeyViewController.CloseButtonStyle {
        return eventContext == .onboarding ? .skip : .close
    }
    
    override func onCloseButton() {
        RecoveryKeyFlowController.promptToSetUpRecoveryKeyLater(from: self) { [unowned self] (userWantsToSetUpLater) in
            if userWantsToSetUpLater {
                self.trackEvent(event: .dismissed, metaData: nil, tracked: {
                    self.dismiss(animated: true, completion: nil)
                })
            }
        }
    }
    
    private func setUpContinueButton() {
        continueButton.layer.cornerRadius = 2.0
        continueButton.isEnabled = false    // enable once words are confirmed
        
        view.addSubview(continueButton)
        
        constrainContinueButton(continueButton)
        
        continueButton.title = S.Button.confirm
        
        continueButton.tap = { [unowned self] in
            self.userDidWriteKey()
        }
    }
    
    private func userDidWriteKey() {
        UserDefaults.writePaperPhraseDate = Date()
        Store.trigger(name: .didWritePaperKey)
        trackEvent(event: .paperKeyCreated)
        self.onConfirmedWords?()
    }
    
    private func setUpTitles() {
        
        let titles = [S.RecoverKeyFlow.confirmRecoveryKeyTitle, S.RecoverKeyFlow.confirmRecoveryKeySubtitle]
        let fonts = [E.isSmallScreen ? Theme.h3Title : Theme.h2Title,
                     E.isSmallScreen ? Theme.body2 : Theme.body1]
        let colors = [Theme.primaryText, Theme.secondaryText]
        let margin: CGFloat = E.isSmallScreen ? 35 : 55
        
        for (i, label) in [titleLabel, subtitleLabel].enumerated() {
            view.addSubview(label)
            label.numberOfLines = 0
            label.textAlignment = .center
            label.text = titles[i]
            label.font = fonts[i]
            label.textColor = colors[i]
            label.constrain([
                label.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: margin),
                label.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -margin)
                ])
        }
        
        let topConstant: CGFloat = E.isSmallScreen ? 2 : 28
        titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                        constant: topConstant).isActive = true
        subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]).isActive = true
    }
    
    private func setUpInputFields() {
        guard let view = self.view else { return }
        
        let hints = [confirmationWordLabel(confirmationIndices.first), confirmationWordLabel(confirmationIndices.second)]
        let words = confirmationWords
        
        let topMargin: CGFloat = E.isSmallScreen ? 18 : 42
        let containerHeight: CGFloat = E.isSmallScreen ? 64 : 70
        let verticalSpacing: CGFloat = C.padding[2]
        let leftRightMargin: CGFloat = C.padding[2]

        let topConstraints: [(NSLayoutYAxisAnchor, CGFloat)] = [(subtitleLabel.bottomAnchor, topMargin),
                                                                (firstWordInputView.bottomAnchor, verticalSpacing)]
        
        for (i, wordView) in [firstWordInputView, secondWordInputView].enumerated() {
            view.addSubview(wordView)
            wordView.constrain([
                wordView.heightAnchor.constraint(equalToConstant: containerHeight),
                wordView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: leftRightMargin),
                wordView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -leftRightMargin),
                wordView.topAnchor.constraint(equalTo: topConstraints[i].0, constant: topConstraints[i].1)
                ])
            
            wordView.hint = hints[i]
            wordView.word = words[i]
            
            wordView.onFocusCallback = { [unowned self] in
                if wordView == self.firstWordInputView {
                    self.secondWordInputView.loseFocus()
                } else {
                    self.firstWordInputView.loseFocus()
                }
            }
            
            wordView.onValidateCallback = { [unowned self] in
                if self.shouldEnableContinueButton() {
                    self.continueButton.isEnabled = true
                    // When user gets both words correct, hide the keyboard automatically to show the enabled
                    // continue button. Queue the dismissal on the main thread to prevent trimming of the last character
                    // in the word for some languages such as Japanese.
                    DispatchQueue.main.async {
                        wordView.loseFocus()
                    }
                } else {
                    self.continueButton.isEnabled = false
                }
            }
            
            wordView.onReturnKeyCallback = { [unowned self] in
                if wordView == self.firstWordInputView {
                    _ = self.secondWordInputView.becomeFirstResponder()
                } else {
                    _ = self.secondWordInputView.resignFirstResponder()
                }
            }
        }
        
        firstWordInputView.returnKeyType = .next
        secondWordInputView.returnKeyType = .done
    }
    
    private func shouldEnableContinueButton() -> Bool {
        guard firstWordInputView.matched && secondWordInputView.matched else { return false }
        
        guard keyMaster.isSeedWordValid(firstWordInputView.currentInput) &&
            keyMaster.isSeedWordValid(secondWordInputView.currentInput) else { return false }
        
        return true
    }
}

class RecoveryKeyWordInputView: UIView, UITextFieldDelegate {
    
    var word: String?
    
    var hint: String? {
        didSet {
            hintLabel.text = hint
        }
    }
    
    var currentInput: String {
        return input.text ?? ""
    }
    
    var returnKeyType: UIReturnKeyType = .next {
        didSet {
            input.returnKeyType = returnKeyType
        }
    }
    
    var onFocusCallback: (() -> Void)?
    var onValidateCallback: (() -> Void)?
    var onReturnKeyCallback: (() -> Void)?
    
    func loseFocus() {
        _ = resignFirstResponder()
        hideFocusBar()
        showErrorLabel(haveError)
    }
    
    let mainContainer = UIView()
    let hintLabel = UILabel()
    let errorLabel = UILabel()
    let input = UITextField()
    let clearButton = UIButton()
    let focusBar = UIView()
    
    let xInset: CGFloat = 12
    let mainContainerHeight: CGFloat = E.isSmallScreen ? 50 : 54
    let errorLabelHeight: CGFloat = E.isSmallScreen ? 14 : 16
    let animationDistance: CGFloat = E.isSmallScreen ? 10 : 12
    let inputHeight: CGFloat = E.isSmallScreen ? 16 : 22
    
    var hintLabelAnimationConstraint: NSLayoutConstraint?
    
    var checkImage: UIImage? {
        return UIImage(named: "Checkmark")?.tinted(with: Theme.accent)
    }
    
    var clearInputImage: UIImage? {
        return UIImage(named: "CloseModern")?.tinted(with: Theme.tertiaryText)
    }
    
    var validInput = true {
        didSet {
            errorLabel.isHighlighted = !validInput
        }
    }
    
    var matched: Bool {
        guard let text = input.text, !text.isEmpty, let targetWord = word else { return false }
        guard !haveError else { return false }
        return text.trimmingCharacters(in: .whitespaces) == targetWord
    }
    
    var haveError = false {
        didSet {
            if haveError {
                showFocusBar()
            } else if handlingInput {
                showFocusBar()
            } else {
                hideFocusBar()
            }
        }
    }
    
    var noInput: Bool {
        return (input.text ?? "").isEmpty
    }
    
    var handlingInput = false {
        didSet {
            if handlingInput {
                if noInput {
                    animateHint(up: true)
                }
                showFocusBar()
                input.isUserInteractionEnabled = true
                _ = input.becomeFirstResponder()
                onFocusCallback?()
            } else {
                if noInput {
                    animateHint(up: false)
                }
                input.isUserInteractionEnabled = false
                hideFocusBar()
                _ = input.resignFirstResponder()
            }
        }
    }
    
    init() {
        super.init(frame: .zero)
        setUp()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool { return true }

    override func becomeFirstResponder() -> Bool {
        handlingInput = true
        return input.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        guard handlingInput else { return false }
        if let text = input.text, text.isEmpty {
            animateHint(up: false)
        }
        handlingInput = false
        return input.resignFirstResponder()
    }
    
    private func setUp() {
        backgroundColor = .clear
        
        setUpMainContainer()
        setUpFocusBar()
        setUpErrorLabel()
        setUpHintLabel()
        setUpInputField()
        
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    
    private func setUpMainContainer() {
        mainContainer.backgroundColor = Theme.secondaryBackground
        addSubview(mainContainer)
        mainContainer.constrain([
            mainContainer.heightAnchor.constraint(equalToConstant: mainContainerHeight),
            mainContainer.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 0),
            mainContainer.rightAnchor.constraint(equalTo: self.rightAnchor, constant: 0),
            mainContainer.topAnchor.constraint(equalTo: self.topAnchor, constant: 0)
            ])
    }

    private func setUpErrorLabel() {
        // the focus bar sits at the bottom of the main container; the error label sits below
        // the focus bar, snapped to the bottom of the overall view
        addSubview(errorLabel)
        errorLabel.constrain([
            errorLabel.heightAnchor.constraint(equalToConstant: errorLabelHeight),
            errorLabel.leftAnchor.constraint(equalTo: self.leftAnchor),
            errorLabel.rightAnchor.constraint(equalTo: self.rightAnchor),
            errorLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
        errorLabel.isHidden = true
        errorLabel.textColor = Theme.error
        errorLabel.font = Theme.caption
        errorLabel.text = S.RecoverKeyFlow.confirmRecoveryInputError
    }
    
    private func setUpFocusBar() {
        mainContainer.addSubview(focusBar)
        focusBar.backgroundColor = Theme.accent
        focusBar.constrain([
            focusBar.heightAnchor.constraint(equalToConstant: 2),
            focusBar.leftAnchor.constraint(equalTo: mainContainer.leftAnchor),
            focusBar.rightAnchor.constraint(equalTo: mainContainer.rightAnchor),
            focusBar.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor)
            ])
        focusBar.isHidden = true
    }
    
    private func setUpHintLabel() {
        hintLabel.textColor = Theme.tertiaryText
        hintLabel.font = Theme.body1
        
        mainContainer.addSubview(hintLabel)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.leftAnchor.constraint(equalTo: mainContainer.leftAnchor, constant: xInset).isActive = true
        
        let centering = hintLabel.centerYAnchor.constraint(equalTo: mainContainer.centerYAnchor)
        centering.isActive = true
        hintLabelAnimationConstraint = centering
    }
    
    private func setUpInputField() {
        input.textColor = Theme.primaryText
        input.font = Theme.body1
        input.backgroundColor = .clear
        input.borderStyle = .none
        input.returnKeyType = returnKeyType
        input.clearButtonMode = .never          // we'll add a custom 'X' button
        input.isUserInteractionEnabled = false  // set to 'true' in the tap gesture handler
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        input.delegate = self
        
        mainContainer.addSubview(input)
        input.constrain([
            input.leftAnchor.constraint(equalTo: mainContainer.leftAnchor, constant: xInset),
            input.rightAnchor.constraint(equalTo: mainContainer.rightAnchor, constant: -xInset),
            input.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -C.padding[1]),
            input.heightAnchor.constraint(equalToConstant: inputHeight)
            ])
        
        input.addTarget(self, action: #selector(textChanged(textField:)), for: .editingChanged)
        input.addTarget(self, action: #selector(keyboardDoneTapped(textField:)), for: .editingDidEndOnExit)
        
        // add a custom clear button ('X')
        clearButton.addTarget(self, action: #selector(clearInput), for: .touchUpInside)
        
        mainContainer.addSubview(clearButton)
        
        clearButton.constrain([
            clearButton.centerYAnchor.constraint(equalTo: mainContainer.centerYAnchor),
            clearButton.heightAnchor.constraint(equalToConstant: 24),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.rightAnchor.constraint(equalTo: mainContainer.rightAnchor, constant: -12)
            ])

        updateClearButton()
    }
    
    private func showFocusBar() {
        guard input.isFirstResponder else { return }
        focusBar.isHidden = false
        focusBar.backgroundColor = haveError ? Theme.error : Theme.accent
    }
    
    private func hideFocusBar() {
        focusBar.isHidden = true
        focusBar.backgroundColor = Theme.accent
    }
    
    private func showErrorLabel(_ show: Bool) {
        errorLabel.isHidden = !show
    }
    
    private func updateClearButton() {
        if let text = input.text, !text.isEmpty {
            clearButton.isHidden = false
            clearButton.setImage(matched ? checkImage : clearInputImage, for: .normal)
            clearButton.isUserInteractionEnabled = !matched
        } else {
            clearButton.isHidden = true
        }
    }
    
    @objc private func tapped() {
        guard !handlingInput else { return }
        handlingInput = true
    }
    
    @objc private func textChanged(textField: UITextField) {
        let text = textField.text ?? ""
        validate(text)
        onValidateCallback?()
    }
    
    @objc private func keyboardDoneTapped(textField: UITextField) {
        _ = resignFirstResponder()
        onValidateCallback?()
    }
    
    @objc private func clearInput() {
        input.text = ""
        updateClearButton()
        haveError = false
        showErrorLabel(false)
        showFocusBar()
    }
    
    private func animateHint(up: Bool) {
        if let anchor = hintLabelAnimationConstraint {
            let constant = up ? -animationDistance : 0
            let scale: CGFloat = up ? 0.75 : 1.0
            let label = hintLabel
            
            let deltaX = (up ? -((1.0 - scale) * label.frame.width) : 0)
            let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
            let finalTransform = scaleTransform.translatedBy(x: deltaX, y: 0)
            
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                anchor.constant = constant
                label.transform = finalTransform
                self.mainContainer.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    func validate(_ text: String) {
        guard !text.isEmpty, let word = word else {
            haveError = false
            return
        }

        haveError = !(word.hasPrefix(text.lowercased()))
        
        updateClearButton()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        animateHint(up: true)
        showFocusBar()
        showErrorLabel(false)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturnKeyCallback?()
        return false
    }
}
