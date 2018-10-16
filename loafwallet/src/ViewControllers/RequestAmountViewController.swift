//
//  RequestAmountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-03.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private let qrSize: CGSize = CGSize(width: 186.0, height: 186.0)
private let smallButtonHeight: CGFloat = 32.0
private let buttonPadding: CGFloat = 20.0
private let smallSharePadding: CGFloat = 12.0
private let largeSharePadding: CGFloat = 20.0

class RequestAmountViewController : UIViewController {

    var presentEmail: PresentShare?
    var presentText: PresentShare?

    init(wallet: BRWallet, store: Store) {
        self.wallet = wallet
        amountView = AmountViewController(store: store, isPinPadExpandedAtLaunch: true, isRequesting: true)
        super.init(nibName: nil, bundle: nil)
    }

    //MARK - Private
    private let amountView: AmountViewController
    private let qrCode = UIImageView()
    private let address = UILabel(font: .customBody(size: 14.0))
    private let addressPopout = InViewAlert(type: .primary)
    private let share = ShadowButton(title: S.Receive.share, type: .tertiary, image: #imageLiteral(resourceName: "Share"))
    private let sharePopout = InViewAlert(type: .secondary)
    private let border = UIView()
    private var topSharePopoutConstraint: NSLayoutConstraint?
    private let wallet: BRWallet

    //MARK - PinPad State
    private var amount: Satoshis? {
        didSet {
            setQrCode()
        }
    }
    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
        addActions()
        setupCopiedMessage()
        setupShareButtons()
    }

    private func addSubviews() {
        view.addSubview(qrCode)
        view.addSubview(address)
        view.addSubview(addressPopout)
        view.addSubview(share)
        view.addSubview(sharePopout)
        view.addSubview(border)
    }

    private func addConstraints() {
        addChildViewController(amountView, layout: {
            amountView.view.constrain([
                amountView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                amountView.view.topAnchor.constraint(equalTo: view.topAnchor),
                amountView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        })
        qrCode.constrain([
            qrCode.constraint(.width, constant: qrSize.width),
            qrCode.constraint(.height, constant: qrSize.height),
            qrCode.topAnchor.constraint(equalTo: amountView.view.bottomAnchor, constant: C.padding[2]),
            qrCode.constraint(.centerX, toView: view) ])
        address.constrain([
            address.constraint(toBottom: qrCode, constant: C.padding[1]),
            address.constraint(.centerX, toView: view) ])
        addressPopout.heightConstraint = addressPopout.constraint(.height, constant: 0.0)
        addressPopout.constrain([
            addressPopout.constraint(toBottom: address, constant: 0.0),
            addressPopout.constraint(.centerX, toView: view),
            addressPopout.constraint(.width, toView: view),
            addressPopout.heightConstraint ])
        share.constrain([
            share.constraint(toBottom: addressPopout, constant: C.padding[2]),
            share.constraint(.centerX, toView: view),
            share.constraint(.width, constant: qrSize.width),
            share.constraint(.height, constant: smallButtonHeight) ])
        sharePopout.heightConstraint = sharePopout.constraint(.height, constant: 0.0)
        topSharePopoutConstraint = sharePopout.constraint(toBottom: share, constant: largeSharePadding)
        sharePopout.constrain([
            topSharePopoutConstraint,
            sharePopout.constraint(.centerX, toView: view),
            sharePopout.constraint(.width, toView: view),
            sharePopout.heightConstraint ])
        border.constrain([
            border.constraint(.width, toView: view),
            border.constraint(toBottom: sharePopout, constant: 0.0),
            border.constraint(.centerX, toView: view),
            border.constraint(.height, constant: 1.0),
            border.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setData() {
        view.backgroundColor = .white
        address.text = wallet.receiveAddress
        address.textColor = .grayTextTint
        border.backgroundColor = .secondaryBorder
        qrCode.image = UIImage.qrCode(data: "\(wallet.receiveAddress)".data(using: .utf8)!, color: CIColor(color: .black))?
            .resize(qrSize)!
        share.isToggleable = true
        sharePopout.clipsToBounds = true
    }

    private func addActions() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(RequestAmountViewController.addressTapped))
        address.addGestureRecognizer(gr)
        address.isUserInteractionEnabled = true
        share.addTarget(self, action: #selector(RequestAmountViewController.shareTapped), for: .touchUpInside)
        amountView.didUpdateAmount = { [weak self] amount in
            self?.amount = amount
        }
    }

    private func setQrCode(){
        guard let amount = amount else { return }
        let request = PaymentRequest.requestString(withAddress: wallet.receiveAddress, forAmount: amount.rawValue)
        qrCode.image = UIImage.qrCode(data: request.data(using: .utf8)!, color: CIColor(color: .black))?
            .resize(qrSize)!
    }

    private func setupCopiedMessage() {
        let copiedMessage = UILabel(font: .customMedium(size: 14.0))
        copiedMessage.textColor = .white
        copiedMessage.text = S.Receive.copied
        copiedMessage.textAlignment = .center
        addressPopout.contentView = copiedMessage
    }

    private func setupShareButtons() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let email = ShadowButton(title: S.Receive.emailButton, type: .tertiary)
        let text = ShadowButton(title: S.Receive.textButton, type: .tertiary)
        container.addSubview(email)
        container.addSubview(text)
        email.constrain([
            email.constraint(.leading, toView: container, constant: C.padding[2]),
            email.constraint(.top, toView: container, constant: buttonPadding),
            email.constraint(.bottom, toView: container, constant: -buttonPadding),
            email.trailingAnchor.constraint(equalTo: container.centerXAnchor, constant: -C.padding[1]) ])
        text.constrain([
            text.constraint(.trailing, toView: container, constant: -C.padding[2]),
            text.constraint(.top, toView: container, constant: buttonPadding),
            text.constraint(.bottom, toView: container, constant: -buttonPadding),
            text.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: C.padding[1]) ])
        sharePopout.contentView = container
        email.addTarget(self, action: #selector(RequestAmountViewController.emailTapped), for: .touchUpInside)
        text.addTarget(self, action: #selector(RequestAmountViewController.textTapped), for: .touchUpInside)
    }

    @objc private func shareTapped() {
        toggle(alertView: sharePopout, shouldAdjustPadding: true)
        if addressPopout.isExpanded {
            toggle(alertView: addressPopout, shouldAdjustPadding: false)
        }
    }

    @objc private func addressTapped() {
        guard let text = address.text else { return }
        UIPasteboard.general.string = text
        toggle(alertView: addressPopout, shouldAdjustPadding: false, shouldShrinkAfter: true)
        if sharePopout.isExpanded {
            toggle(alertView: sharePopout, shouldAdjustPadding: true)
        }
    }

    @objc private func emailTapped() {
        guard let amount = amount else { return showErrorMessage(S.RequestAnAmount.noAmount) }
        let text = PaymentRequest.requestString(withAddress: wallet.receiveAddress, forAmount: amount.rawValue)
        presentEmail?(text, qrCode.image!)
    }

    @objc private func textTapped() {
        guard let amount = amount else { return showErrorMessage(S.RequestAnAmount.noAmount) }
        let text = PaymentRequest.requestString(withAddress: wallet.receiveAddress, forAmount: amount.rawValue)
        presentText?(text, qrCode.image!)
    }

    private func toggle(alertView: InViewAlert, shouldAdjustPadding: Bool, shouldShrinkAfter: Bool = false) {
        share.isEnabled = false
        address.isUserInteractionEnabled = false

        var deltaY = alertView.isExpanded ? -alertView.height : alertView.height
        if shouldAdjustPadding {
            if deltaY > 0 {
                deltaY -= (largeSharePadding - smallSharePadding)
            } else {
                deltaY += (largeSharePadding - smallSharePadding)
            }
        }

        if alertView.isExpanded {
            alertView.contentView?.isHidden = true
        }

        UIView.spring(C.animationDuration, animations: {
            if shouldAdjustPadding {
                let newPadding = self.sharePopout.isExpanded ? largeSharePadding : smallSharePadding
                self.topSharePopoutConstraint?.constant = newPadding
            }
            alertView.toggle()
            self.parent?.view.layoutIfNeeded()
        }, completion: { _ in
            alertView.isExpanded = !alertView.isExpanded
            self.share.isEnabled = true
            self.address.isUserInteractionEnabled = true
            alertView.contentView?.isHidden = false
            if shouldShrinkAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                    if alertView.isExpanded {
                        self.toggle(alertView: alertView, shouldAdjustPadding: shouldAdjustPadding)
                    }
                })
            }
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RequestAmountViewController : ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.requestAmount
    }

    var modalTitle: String {
        return S.Receive.request
    }
}
