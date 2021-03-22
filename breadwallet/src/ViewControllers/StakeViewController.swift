// 
//  StakeViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-10-18.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class StakeViewController: UIViewController, Subscriber, Trackable, ModalPresentable {
    
    fileprivate let midContentHeight: CGFloat = 90.0
    fileprivate let bakerContentHeight: CGFloat = 40.0
    fileprivate let selectBakerButtonHeight: CGFloat = 70.0
    fileprivate let removeButtonHeight: CGFloat = 30.0
    
    var presentVerifyPin: ((String, @escaping ((String) -> Void)) -> Void)?
    var onPublishSuccess: (() -> Void)?
    var presentStakeSelection: (((Baker) -> Void) -> Void)?
    
    private let currency: Currency
    private let sender: Sender
    private var baker: Baker?
    
    var parentView: UIView? //ModalPresentable
    
    private let titleLabel = UILabel(font: .customBold(size: 17.0))
    private let caption = UILabel(font: .customBody(size: 15.0))
    private let stakeButton = BRDButton(title: S.Staking.stake, type: .primary)
    private let selectBakerButton = UIButton()
    private let changeBakerButton = UIButton()
    private let bakerInfoView = UIView()
    private let txPendingView = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .gray)
    private let sendingActivity = BRActivityViewController(message: S.TransactionDetails.titleSending)
    
    init(currency: Currency, sender: Sender) {
        self.currency = currency
        self.sender = sender
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Store.unsubscribe(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stakeButton.isHidden = true
        
        view.backgroundColor = .white
        view.addSubview(titleLabel)
        view.addSubview(caption)
        view.addSubview(txPendingView)
        view.addSubview(selectBakerButton)
        view.addSubview(changeBakerButton)
        view.addSubview(stakeButton)
        view.addSubview(bakerInfoView)
        view.addSubview(loadingSpinner)
        
        loadingSpinner.constrain([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        caption.constrain([
            caption.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[3]),
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3])])
        selectBakerButton.constrain([
            selectBakerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            selectBakerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            selectBakerButton.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: C.padding[4]),
            selectBakerButton.constraint(.height, constant: selectBakerButtonHeight) ])
        changeBakerButton.constrain([
            changeBakerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            changeBakerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            changeBakerButton.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: C.padding[4]),
            changeBakerButton.constraint(.height, constant: selectBakerButtonHeight) ])
        txPendingView.constrain([
            txPendingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            txPendingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            txPendingView.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: C.padding[7]),
            txPendingView.constraint(.height, constant: midContentHeight) ])
        bakerInfoView.constrain([
            bakerInfoView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            bakerInfoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            bakerInfoView.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: C.padding[2]),
            bakerInfoView.constraint(.height, constant: midContentHeight) ])
        stakeButton.constrain([
            stakeButton.constraint(.leading, toView: view, constant: C.padding[2]),
            stakeButton.constraint(.trailing, toView: view, constant: -C.padding[2]),
            stakeButton.constraint(toBottom: bakerInfoView, constant: C.padding[4]),
            stakeButton.constraint(.height, constant: C.Sizes.buttonHeight),
            stakeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[5]) ])
        
        Store.subscribe(self, name: .didSelectBaker(nil), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case .didSelectBaker(let baker?) = trigger {
                self?.showSelected(baker: baker)
            }
        })
        
        setInitialData()
    }
    
    private func setInitialData() {
        titleLabel.text = S.Staking.subTitle
        caption.text = S.Staking.descriptionTezos
        titleLabel.textAlignment = .center
        caption.textAlignment = .center
        caption.numberOfLines = 0
        caption.lineBreakMode = .byWordWrapping

        stakeButton.tap = stakeTapped
        selectBakerButton.tap = selectBakerTapped
        changeBakerButton.tap = selectBakerTapped
        loadingSpinner.startAnimating()
        
        //Internally, the stake modal has 4 UI states:
        // - Transaction pending - staked, pending confirm
        // - Delegate staked - staked, confirmed
        // - Empty - No delegate selected
        // - Delegate selected - delegate selected, but not staked (triggered from .didSelectBaker())
        if currency.wallet?.hasPendingTxn == true {
            showTxPending()
        } else {
            //Is Staked
            if let validatorAddress = currency.wallet?.stakedValidatorAddress {
                // Retrieve baker from Baking Bad API using stored address
                ExternalAPIClient.shared.send(BakerRequest(address: validatorAddress)) { [weak self] response in
                    guard case .success(let data) = response else { return }
                    self?.showStaked(baker: data)
                }
            //Is not staked, no baker selected
            } else {
                showBakerEmpty()
            }
        }
    }
    
    private func stakeTapped() {
        if currency.wallet?.isStaked == true {
            unstake()
        } else {
            stake()
        }
    }
    
    private func stake() {
        guard let addressText = baker?.address else { return }
        confirm(address: addressText) { [weak self] success in
            guard success else { return }
            self?.send(address: addressText)
            self?.track(eventName: Event.stake.name)
        }
    }
    
    private func unstake() {
        guard let address = currency.wallet?.receiveAddress else { return }
        confirm(address: address) { [weak self] success in
            guard success else { return }
            self?.send(address: address)
            self?.track(eventName: Event.unstake.name)
        }
    }
    
    private func send(address: String) {
        let pinVerifier: PinVerifier = { [weak self] pinValidationCallback in
            guard let `self` = self else { return assertionFailure() }
            self.sendingActivity.dismiss(animated: false) {
                self.presentVerifyPin?(S.VerifyPin.authorize) { pin in
                    self.parent?.view.isFrameChangeBlocked = false
                    pinValidationCallback(pin)
                    self.present(self.sendingActivity, animated: false)
                }
            }
        }
        
        present(sendingActivity, animated: true)
        sender.stake(address: address, pinVerifier: pinVerifier) { [weak self] result in
            guard let `self` = self else { return }
            self.sendingActivity.dismiss(animated: true) {
                defer { self.sender.reset() }
                switch result {
                case .success:
                    self.onPublishSuccess?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss(animated: true, completion: nil)
                    }
                case .creationError(let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: message, buttonLabel: S.Button.ok)
                case .publishFailure(let code, let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: "\(message) (\(code))", buttonLabel: S.Button.ok)
                case .insufficientGas(let rpcErrorMessage):
                    print("insufficientGas: \(rpcErrorMessage)")
                }
            }
        }
    }
    
    private func confirm(address: String, callback: @escaping (Bool) -> Void) {
        let confirmation = ConfirmationViewController(amount: Amount.zero(currency),
                                                      fee: Amount.zero(currency),
                                                      displayFeeLevel: FeeLevel.regular,
                                                      address: address,
                                                      isUsingBiometrics: true,
                                                      currency: currency,
                                                      shouldShowMaskView: true,
                                                      isStake: true)
        let transitionDelegate = PinTransitioningDelegate()
        transitionDelegate.shouldShowMaskView = true
        confirmation.transitioningDelegate = transitionDelegate
        confirmation.modalPresentationStyle = .overFullScreen
        confirmation.modalPresentationCapturesStatusBarAppearance = true
        confirmation.successCallback = { callback(true) }
        confirmation.cancelCallback = { callback(false) }
        present(confirmation, animated: true, completion: nil)
    }
    
    private func selectBakerTapped() {
        let stakeSelectViewController = SelectBakerViewController(currency: currency)
        stakeSelectViewController.transitioningDelegate = ModalTransitionDelegate(type: .regular)
        stakeSelectViewController.modalPresentationStyle = .overFullScreen
        stakeSelectViewController.modalPresentationCapturesStatusBarAppearance = true
        let vc = ModalViewController(childViewController: stakeSelectViewController)
        present(vc, animated: true, completion: nil)
    }
    
    private func showTxPending() {
        loadingSpinner.stopAnimating()
        selectBakerButton.isHidden = true
        changeBakerButton.isHidden = true
        stakeButton.isHidden = true
        bakerInfoView.alpha = 0.0
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.bakerInfoView.alpha = 1
        }
        buildTxPendingView()
    }
    
    private func showBakerEmpty() {
        loadingSpinner.isHidden = true
        selectBakerButton.isHidden = false
        selectBakerButton.alpha = 0
        changeBakerButton.isHidden = true
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.stakeButton.alpha = 0
            self?.bakerInfoView.alpha = 0
            self?.selectBakerButton.alpha = 1
        } completion: { [weak self] _ in
            self?.stakeButton.isHidden = true
            self?.stakeButton.alpha = 1
            self?.bakerInfoView.isHidden = true
            self?.bakerInfoView.alpha = 1
            self?.selectBakerButton.isHidden = false
        }
        buildSelectBakerButton()
    }
    
    private func showSelected(baker: Baker?) {
        self.baker = baker
        selectBakerButton.isHidden = true
        stakeButton.isHidden = false
        stakeButton.title = S.Staking.stake
        changeBakerButton.isHidden = false
        
        buildChangeBakerButton(with: baker)
    }
    
    private func showStaked(baker: Baker?) {
        self.baker = baker
        loadingSpinner.stopAnimating()
        selectBakerButton.isHidden = true
        changeBakerButton.isHidden = true
        stakeButton.isHidden = false
        stakeButton.title = S.Staking.unstake
        bakerInfoView.isHidden = false
        bakerInfoView.alpha = 0.0
        buildInfoView(with: baker)
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.bakerInfoView.alpha = 1.0
        }
    }
    
    private func buildChangeBakerButton(with baker: Baker?) {
        changeBakerButton.subviews.forEach { $0.removeFromSuperview() }
        changeBakerButton.layer.cornerRadius = C.Sizes.roundedCornerRadius
        changeBakerButton.layer.masksToBounds = true
        changeBakerButton.backgroundColor = currency.colors.0
        let bakerName = UILabel(font: .customBold(size: 18.0), color: .white)
        let bakerFee = UILabel(font: .customBody(size: 12.0), color: UIColor.white.withAlphaComponent(0.6))
        let bakerROI = UILabel(font: .customBold(size: 18.0), color: .white)
        let bakerROIHeader = UILabel(font: .customBody(size: 12.0), color: UIColor.white.withAlphaComponent(0.6))
        let bakerIcon = UIImageView()
        let bakerIconLoadingView = UIView()
        let arrow = UIImageView()
        
        arrow.image = UIImage(named: "RightArrow")?.withRenderingMode(.alwaysTemplate)
        arrow.tintColor = .white
        
        let feeText = baker?.feeString ?? ""
        bakerFee.text = "\(S.Staking.feeHeader) \(feeText)"
        bakerROI.text = baker?.roiString
        bakerROI.adjustsFontSizeToFitWidth = true
        bakerROI.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        bakerROIHeader.text = S.Staking.roiHeader
        bakerName.adjustsFontSizeToFitWidth = true
        bakerName.text = baker?.name
        
        bakerIcon.layer.cornerRadius = C.Sizes.roundedCornerRadius
        bakerIcon.layer.masksToBounds = true
        bakerIcon.backgroundColor = .white
        
        bakerIconLoadingView.layer.cornerRadius = C.Sizes.roundedCornerRadius
        bakerIconLoadingView.layer.masksToBounds = true
        bakerIconLoadingView.backgroundColor = .white
        
        let iconLoadingSpinner = UIActivityIndicatorView(style: .gray)
        bakerIconLoadingView.addSubview(iconLoadingSpinner)
        iconLoadingSpinner.startAnimating()
        
        changeBakerButton.addSubview(bakerName)
        changeBakerButton.addSubview(bakerFee)
        changeBakerButton.addSubview(bakerROI)
        changeBakerButton.addSubview(bakerROIHeader)
        changeBakerButton.addSubview(bakerIcon)
        changeBakerButton.addSubview(bakerIconLoadingView)
        changeBakerButton.addSubview(arrow)
        
        bakerIcon.constrain([
            bakerIcon.topAnchor.constraint(equalTo: changeBakerButton.topAnchor, constant: C.padding[2]),
            bakerIcon.leadingAnchor.constraint(equalTo: changeBakerButton.leadingAnchor, constant: C.padding[2]),
            bakerIcon.heightAnchor.constraint(equalToConstant: bakerContentHeight),
            bakerIcon.widthAnchor.constraint(equalToConstant: bakerContentHeight) ])
        bakerIconLoadingView.constrain([
            bakerIconLoadingView.topAnchor.constraint(equalTo: changeBakerButton.topAnchor, constant: C.padding[2]),
            bakerIconLoadingView.leadingAnchor.constraint(equalTo: changeBakerButton.leadingAnchor, constant: C.padding[2]),
            bakerIconLoadingView.heightAnchor.constraint(equalToConstant: bakerContentHeight),
            bakerIconLoadingView.widthAnchor.constraint(equalToConstant: bakerContentHeight) ])
        iconLoadingSpinner.constrain([
            iconLoadingSpinner.centerXAnchor.constraint(equalTo: bakerIconLoadingView.centerXAnchor),
            iconLoadingSpinner.centerYAnchor.constraint(equalTo: bakerIconLoadingView.centerYAnchor)])
        bakerName.constrain([
            bakerName.topAnchor.constraint(equalTo: changeBakerButton.topAnchor, constant: C.padding[2]),
            bakerName.leadingAnchor.constraint(equalTo: bakerIcon.trailingAnchor, constant: C.padding[2]),
            bakerName.trailingAnchor.constraint(equalTo: bakerROI.leadingAnchor, constant: -C.padding[2]) ])
        bakerFee.constrain([
            bakerFee.topAnchor.constraint(equalTo: bakerName.bottomAnchor),
            bakerFee.leadingAnchor.constraint(equalTo: bakerIcon.trailingAnchor, constant: C.padding[2]) ])
        bakerROI.constrain([
            bakerROI.topAnchor.constraint(equalTo: bakerName.topAnchor),
            bakerROI.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -C.padding[2]) ])
        bakerROIHeader.constrain([
            bakerROIHeader.topAnchor.constraint(equalTo: bakerROI.bottomAnchor),
            bakerROIHeader.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -C.padding[2]) ])
        arrow.constrain([
            arrow.centerYAnchor.constraint(equalTo: changeBakerButton.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: changeBakerButton.trailingAnchor, constant: -C.padding[2]),
            arrow.heightAnchor.constraint(equalToConstant: 10),
            arrow.widthAnchor.constraint(equalToConstant: 7) ])
        
        if let imageUrl = baker?.logo, !imageUrl.isEmpty {
            UIImage.fetchAsync(from: imageUrl) { [weak bakerIcon] (image, url) in
                // Reusable cell, ignore completion from a previous load call
                if url?.absoluteString == imageUrl {
                    bakerIcon?.image = image
                    UIView.animate(withDuration: 0.2) {
                        bakerIconLoadingView.alpha = 0.0
                    }
                }
            }
        }
    }
    
    private func buildSelectBakerButton() {
        selectBakerButton.layer.cornerRadius = C.Sizes.roundedCornerRadius
        selectBakerButton.layer.masksToBounds = true
        selectBakerButton.backgroundColor = currency.colors.0
        let currencyIcon = UIImageView()
        currencyIcon.image = currency.imageNoBackground
        currencyIcon.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        currencyIcon.layer.cornerRadius = C.Sizes.roundedCornerRadius
        currencyIcon.layer.masksToBounds = true
        currencyIcon.tintColor = .white
        let selectBakerLabel = UILabel(font: .customBold(size: 16.0))
        selectBakerLabel.textColor = .white
        selectBakerLabel.text = S.Staking.selectBakerTitle
        let arrow = UIImageView()
        arrow.image = UIImage(named: "RightArrow")?.withRenderingMode(.alwaysTemplate)
        arrow.tintColor = .white
        
        selectBakerButton.addSubview(currencyIcon)
        selectBakerButton.addSubview(selectBakerLabel)
        selectBakerButton.addSubview(arrow)
        
        currencyIcon.constrain([
            currencyIcon.centerYAnchor.constraint(equalTo: selectBakerButton.centerYAnchor),
            currencyIcon.leadingAnchor.constraint(equalTo: selectBakerButton.leadingAnchor, constant: C.padding[2]),
            currencyIcon.heightAnchor.constraint(equalToConstant: bakerContentHeight),
            currencyIcon.widthAnchor.constraint(equalToConstant: bakerContentHeight) ])
        selectBakerLabel.constrain([
            selectBakerLabel.topAnchor.constraint(equalTo: currencyIcon.topAnchor),
            selectBakerLabel.leadingAnchor.constraint(equalTo: currencyIcon.trailingAnchor, constant: C.padding[2]),
            selectBakerLabel.heightAnchor.constraint(equalToConstant: bakerContentHeight) ])
        arrow.constrain([
            arrow.centerYAnchor.constraint(equalTo: selectBakerButton.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: selectBakerButton.trailingAnchor, constant: -C.padding[2]),
            arrow.heightAnchor.constraint(equalToConstant: 10),
            arrow.widthAnchor.constraint(equalToConstant: 7) ])
    }
    
    private func buildInfoView(with baker: Baker?) {
        bakerInfoView.subviews.forEach {$0.removeFromSuperview()}
        let bakerName = UILabel(font: .customBody(size: 20.0), color: .darkGray)
        let bakerFee = UILabel(font: .customBody(size: 12.0), color: .lightGray)
        let bakerROI = UILabel(font: .customBody(size: 20.0), color: .darkGray)
        let bakerROIHeader = UILabel(font: .customBody(size: 12.0), color: .lightGray)
        bakerName.adjustsFontSizeToFitWidth = true
        let bakerIcon = UIImageView()
        let bakerIconLoadingView = UIView()
        
        bakerName.text = baker?.name
        let feeText = baker?.feeString ?? ""
        bakerFee.text = "\(S.Staking.feeHeader) \(feeText)"
        bakerROI.text = baker?.roiString
        bakerROIHeader.text = S.Staking.roiHeader
        
        bakerIcon.layer.cornerRadius = C.Sizes.roundedCornerRadius
        bakerIcon.layer.masksToBounds = true
        
        bakerIconLoadingView.layer.cornerRadius = C.Sizes.roundedCornerRadius
        bakerIconLoadingView.layer.masksToBounds = true
        bakerIconLoadingView.backgroundColor = .lightGray
        
        let iconLoadingSpinner = UIActivityIndicatorView(style: .white)
        bakerIconLoadingView.addSubview(iconLoadingSpinner)
        iconLoadingSpinner.constrain([
            iconLoadingSpinner.centerXAnchor.constraint(equalTo: bakerIconLoadingView.centerXAnchor),
            iconLoadingSpinner.centerYAnchor.constraint(equalTo: bakerIconLoadingView.centerYAnchor)])
        iconLoadingSpinner.startAnimating()
        
        bakerInfoView.addSubview(bakerName)
        bakerInfoView.addSubview(bakerFee)
        bakerInfoView.addSubview(bakerROI)
        bakerInfoView.addSubview(bakerROIHeader)
        bakerInfoView.addSubview(bakerIcon)
        bakerInfoView.addSubview(bakerIconLoadingView)
        
        bakerIcon.constrain([
            bakerIcon.topAnchor.constraint(equalTo: bakerInfoView.topAnchor, constant: C.padding[2]),
            bakerIcon.leadingAnchor.constraint(equalTo: bakerInfoView.leadingAnchor, constant: C.padding[2]),
            bakerIcon.heightAnchor.constraint(equalToConstant: bakerContentHeight),
            bakerIcon.widthAnchor.constraint(equalToConstant: bakerContentHeight) ])
        bakerIconLoadingView.constrain([
            bakerIconLoadingView.topAnchor.constraint(equalTo: bakerInfoView.topAnchor, constant: C.padding[2]),
            bakerIconLoadingView.leadingAnchor.constraint(equalTo: bakerInfoView.leadingAnchor, constant: C.padding[2]),
            bakerIconLoadingView.heightAnchor.constraint(equalToConstant: bakerContentHeight),
            bakerIconLoadingView.widthAnchor.constraint(equalToConstant: bakerContentHeight) ])
        bakerName.constrain([
            bakerName.topAnchor.constraint(equalTo: bakerInfoView.topAnchor, constant: C.padding[2]),
            bakerName.leadingAnchor.constraint(equalTo: bakerIcon.trailingAnchor, constant: C.padding[2]) ])
        bakerFee.constrain([
            bakerFee.topAnchor.constraint(equalTo: bakerName.bottomAnchor),
            bakerFee.leadingAnchor.constraint(equalTo: bakerIcon.trailingAnchor, constant: C.padding[2]) ])
        bakerROI.constrain([
            bakerROI.topAnchor.constraint(equalTo: bakerName.topAnchor),
            bakerROI.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[4]) ])
        bakerROIHeader.constrain([
            bakerROIHeader.topAnchor.constraint(equalTo: bakerROI.bottomAnchor),
            bakerROIHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[4]) ])
        
        if let imageUrl = baker?.logo, !imageUrl.isEmpty {
            UIImage.fetchAsync(from: imageUrl) { [weak bakerIcon] (image, url) in
                // Reusable cell, ignore completion from a previous load call
                if url?.absoluteString == imageUrl {
                    bakerIcon?.image = image
                    UIView.animate(withDuration: 0.2) {
                        bakerIconLoadingView.alpha = 0.0
                    }
                }
            }
        }
    }
    
    private func buildTxPendingView() {
        bakerInfoView.subviews.forEach {$0.removeFromSuperview()}
        let pendingSpinner = UIActivityIndicatorView(style: .gray)
        let pendingLabel = UILabel(font: .customBold(size: 20.0), color: .darkGray)

        pendingLabel.text = S.Staking.pendingTransaction
        
        pendingSpinner.startAnimating()
        
        bakerInfoView.addSubview(pendingSpinner)
        bakerInfoView.addSubview(pendingLabel)
        
        pendingSpinner.constrain([
            pendingSpinner.leadingAnchor.constraint(equalTo: bakerInfoView.leadingAnchor, constant: C.padding[5]),
            pendingSpinner.centerYAnchor.constraint(equalTo: bakerInfoView.centerYAnchor)])
        pendingLabel.constrain([
            pendingLabel.centerYAnchor.constraint(equalTo: pendingSpinner.centerYAnchor),
            pendingLabel.leadingAnchor.constraint(equalTo: pendingSpinner.trailingAnchor, constant: C.padding[2]) ])
    }
}

// MARK: - Trackable

extension StakeViewController {
    private func track(eventName: String) {
        saveEvent(makeEventName([EventContext.wallet.name, currency.code, eventName]))
    }
}

// MARK: - ModalDisplayable

extension StakeViewController: ModalDisplayable {
    var faqArticleId: String? {
        return "staking"
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return "\(S.Staking.stakingTitle) \(currency.code)"
    }
}
