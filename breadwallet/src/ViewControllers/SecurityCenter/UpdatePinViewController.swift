//
//  UpdatePinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-16.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication

enum UpdatePinType {
    case creationNoPhrase
    case creationWithPhrase
    case update
}

class UpdatePinViewController: UIViewController, Subscriber {

    // MARK: - Public
    var setPinSuccess: ((String) -> Void)?
    var resetFromDisabledSuccess: ((String) -> Void)?
    var resetFromDisabledWillSucceed: (() -> Void)?

    init(keyMaster: KeyMaster,
         type: UpdatePinType,
         showsBackButton: Bool = true,
         phrase: String? = nil,
         eventContext: EventContext = .none) {
        self.keyMaster = keyMaster
        self.phrase = phrase
        self.pinView = PinView(style: .create, length: Store.state.pinLength)
        self.showsBackButton = showsBackButton
        self.type = type
        self.eventContext = eventContext
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Private
    private let header = UILabel.wrapping(font: Theme.h2Title, color: Theme.primaryText)
    private let instruction = UILabel.wrapping(font: Theme.body1, color: Theme.secondaryText)
    private let caption = UILabel.wrapping(font: .customBody(size: 13.0), color: .white)
    private var pinView: PinView
    private let pinPadBackground = UIView(color: .white)
    private let pinPad = PinPadViewController(style: .clear, keyboardType: .pinPad, maxDigits: 0, shouldShowBiometrics: false)
    private let spacer = UIView()
    private let keyMaster: KeyMaster
    
    private lazy var faq = UIButton.buildFaqButton(articleId: ArticleIds.setPin, currency: nil, tapped: { [unowned self] in
        self.trackEvent(event: .helpButton)
    })
    
    private var shouldShowFAQButton: Bool {
        // Don't show the FAQ button during onboarding because we don't have the wallet/authentication
        // initialized yet, and therefore can't open platform content.
        return eventContext != .onboarding
    }
    
    private var step: Step = .verify {
        didSet {
            switch step {
            case .verify:
                instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
                caption.isHidden = true
            case .new:
                let instructionText = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterNew
                if instruction.text != instructionText {
                    instruction.pushNewText(instructionText)
                }
                header.text = S.UpdatePin.createTitle
                caption.isHidden = false
            case .confirmNew:
                caption.isHidden = true
                if isCreatingPin {
                    header.text = S.UpdatePin.createTitleConfirm
                } else {
                    instruction.pushNewText(S.UpdatePin.reEnterNew)
                }
            }
        }
    }
    private var currentPin: String?
    private var newPin: String?
    private var phrase: String?
    private let type: UpdatePinType
    private var isCreatingPin: Bool {
        return type != .update
    }
    private let newPinLength = 6
    private let showsBackButton: Bool
    
    var eventContext: EventContext = .none

    private enum Step {
        case verify
        case new
        case confirmNew
    }

    override func viewDidLoad() {
        
        if shouldShowFAQButton {
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: faq)
        }
        
        header.textAlignment = .center
        instruction.textAlignment = .center
        
        addSubviews()
        addConstraints()
        setData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackEvent(event: .appeared)
    }
    
    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(instruction)
        view.addSubview(caption)
        view.addSubview(pinView)
        view.addSubview(spacer)
        view.addSubview(pinPadBackground)
    }

    private func addConstraints() {
        let leftRightMargin: CGFloat = E.isSmallScreen ? 40 : 60
        
        header.constrain([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: C.padding[2]),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftRightMargin),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -leftRightMargin) ])
        
        instruction.constrain([
            instruction.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            instruction.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            instruction.trailingAnchor.constraint(equalTo: header.trailingAnchor) ])
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: spacer.centerYAnchor),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
        addPinPad()
        spacer.constrain([
            spacer.topAnchor.constraint(equalTo: instruction.bottomAnchor),
            spacer.bottomAnchor.constraint(equalTo: caption.topAnchor) ])
        caption.constrain([
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }

    private func addPinPad() {
        addChild(pinPad)
        pinPadBackground.addSubview(pinPad.view)
        pinPadBackground.constrain([
            pinPadBackground.widthAnchor.constraint(equalToConstant: floor(view.bounds.width/3.0)*3.0),
            pinPadBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinPadBackground.heightAnchor.constraint(equalToConstant: pinPad.height),
            pinPadBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[3] : 0.0) ])
        pinPad.view.constrain(toSuperviewEdges: nil)
        pinPad.didMove(toParent: self)
    }

    private func setData() {
        caption.text = S.UpdatePin.caption
        view.backgroundColor = Theme.primaryBackground
        header.text = isCreatingPin ? S.UpdatePin.createTitle : S.UpdatePin.updateTitle
        instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
        pinPad.ouputDidUpdate = { [weak self] text in
            guard let step = self?.step else { return }
            switch step {
            case .verify:
                self?.didUpdateForCurrent(pin: text)
            case .new :
                self?.didUpdateForNew(pin: text)
            case .confirmNew:
                self?.didUpdateForConfirmNew(pin: text)
            }
        }

        if isCreatingPin {
            step = .new
            caption.isHidden = false
        } else {
            caption.isHidden = true
        }

        if !showsBackButton {
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = true
        }
    }

    private func didUpdateForCurrent(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == Store.state.pinLength {
            if keyMaster.authenticate(withPin: pin) {
                pushNewStep(.new)
                currentPin = pin
                replacePinView()
            } else {
                if keyMaster.walletDisabledUntil > 0 {
                    dismiss(animated: true, completion: {
                        Store.perform(action: RequireLogin())
                    })
                } else {
                    clearAfterFailure()
                }
            }
        }
    }

    private func didUpdateForNew(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == newPinLength {
            trackEvent(event: .pinKeyed)
            newPin = pin
            pushNewStep(.confirmNew)
        }
    }

    private func didUpdateForConfirmNew(pin: String) {
        guard let newPin = newPin else { return }
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == newPinLength {
            if pin == newPin {
                trackEvent(event: .pinCreated)
                didSetNewPin()
            } else {
                clearAfterFailure()
                pushNewStep(.new)
            }
        }
    }

    private func clearAfterFailure() {
        pinPad.view.isUserInteractionEnabled = false
        pinView.shake { [weak self] in
            self?.pinPad.view.isUserInteractionEnabled = true
            self?.pinView.fill(0)
        }
        pinPad.clear()
        trackEvent(event: .pinCreationError)
    }

    private func replacePinView() {
        pinView.removeFromSuperview()
        pinView = PinView(style: .create, length: newPinLength)
        view.addSubview(pinView)
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: spacer.centerYAnchor),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
    }

    private func pushNewStep(_ newStep: Step) {
        step = newStep
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pinView.fill(0)
        }
    }

    private func didSetNewPin() {
        guard let newPin = newPin else { return }
        var success = false
        if let seedPhrase = phrase {
            success = keyMaster.resetPin(newPin: newPin, seedPhrase: seedPhrase)
        } else if let currentPin = currentPin {
            success = keyMaster.changePin(newPin: newPin, currentPin: currentPin)
            DispatchQueue.main.async { Store.trigger(name: .didUpgradePin) }
        } else if type == .creationNoPhrase {
            success = keyMaster.setPin(newPin)
        }

        DispatchQueue.main.async {
            if success {
                if self.resetFromDisabledSuccess != nil {
                    self.resetFromDisabledWillSucceed?()
                    Store.perform(action: Alert.Show(.pinSet(callback: { [weak self] in
                        self?.dismiss(animated: true, completion: {
                            self?.resetFromDisabledSuccess?(newPin)
                        })
                    })))
                } else {
                    Store.perform(action: Alert.Show(.pinSet(callback: { [weak self] in
                        guard let `self` = self else { return }
                        self.setPinSuccess?(newPin)
                        if self.type != .creationNoPhrase {
                            self.parent?.dismiss(animated: true, completion: nil)
                        }
                    })))
                }

            } else {
                let alert = UIAlertController(title: S.UpdatePin.updateTitle, message: S.UpdatePin.setPinError, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { [weak self] _ in
                    self?.clearAfterFailure()
                    self?.pushNewStep(.new)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// user events tracking
extension UpdatePinViewController: Trackable {
    func trackEvent(event: Event) {
        saveEvent(context: eventContext, screen: .setPin, event: event)
    }
}
