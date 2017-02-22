//
//  ReceiveViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let qrSize: CGFloat = 186.0
private let smallButtonHeight: CGFloat = 32.0
private let buttonPadding: CGFloat = 20.0
private let smallSharePadding: CGFloat = 12.0
private let largeSharePadding: CGFloat = 20.0

typealias PresentShare = (String, UIImage) -> Void

class ReceiveViewController: UIViewController {

    //MARK - Public
    var presentEmail: PresentShare?
    var presentText: PresentShare?

    init(store: Store, wallet: BRWallet, isRequestAmountVisible: Bool) {
        self.store = store
        self.wallet = wallet
        self.isRequestAmountVisible = isRequestAmountVisible
        super.init(nibName: nil, bundle: nil)
    }

    //MARK - Private
    private let qrCode = UIImageView()
    private let address = UILabel(font: .customBody(size: 14.0))
    private let addressPopout = InViewAlert(type: .primary)
    private let share = ShadowButton(title: NSLocalizedString("Share", comment: "Share button label"), type: .tertiary, image: #imageLiteral(resourceName: "Share"))
    private let sharePopout = InViewAlert(type: .secondary)
    private let border = UIView()
    private let request = ShadowButton(title: NSLocalizedString("Request an Amount", comment: "Request button label"), type: .secondary)
    private var topSharePopoutConstraint: NSLayoutConstraint?
    private let store: Store
    private let wallet: BRWallet
    fileprivate let isRequestAmountVisible: Bool

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setStyle()
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
        view.addSubview(request)
    }

    private func addConstraints() {
        qrCode.constrain([
            qrCode.constraint(.width, constant: qrSize),
            qrCode.constraint(.height, constant: qrSize),
            qrCode.constraint(.top, toView: view, constant: C.padding[4]),
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
            share.constraint(.width, constant: qrSize),
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
            border.constraint(.height, constant: 1.0) ])
        request.constrain([
            request.constraint(toBottom: border, constant: C.padding[3]),
            request.constraint(.leading, toView: view, constant: C.padding[2]),
            request.constraint(.trailing, toView: view, constant: -C.padding[2]),
            request.constraint(.height, constant: C.Sizes.buttonHeight) ])
    }

    private func setStyle() {
        address.text = wallet.receiveAddress
        address.textColor = .grayTextTint
        border.backgroundColor = .secondaryBorder
        //TODO - use payment request object here
        qrCode.image = UIImage.qrCode(data: "bitcoin:\(address.text!)".data(using: .utf8)!, color: CIColor(color: .black))?
                            .resize(CGSize(width: qrSize, height: qrSize))!
        share.isToggleable = true
        if !isRequestAmountVisible {
            border.isHidden = true
            request.isHidden = true
        }
    }

    private func addActions() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(ReceiveViewController.addressTapped))
        address.addGestureRecognizer(gr)
        address.isUserInteractionEnabled = true
        share.addTarget(self, action: #selector(ReceiveViewController.shareTapped), for: .touchUpInside)
    }

    private func setupCopiedMessage() {
        let copiedMessage = UILabel(font: .customMedium(size: 14.0))
        copiedMessage.textColor = .white
        copiedMessage.text = NSLocalizedString("Copied to Clipboard.", comment: "Address copied message.")
        copiedMessage.textAlignment = .center
        addressPopout.contentView = copiedMessage
    }

    private func setupShareButtons() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let email = ShadowButton(title: NSLocalizedString("Email", comment: "Share via email button label"), type: .tertiary)
        let text = ShadowButton(title: NSLocalizedString("Text Message", comment: "Share via text message label"), type: .tertiary)
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
        email.addTarget(self, action: #selector(ReceiveViewController.emailTapped), for: .touchUpInside)
        text.addTarget(self, action: #selector(ReceiveViewController.textTapped), for: .touchUpInside)
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
        toggle(alertView: addressPopout, shouldAdjustPadding: false)
        if sharePopout.isExpanded {
            toggle(alertView: sharePopout, shouldAdjustPadding: true)
        }
    }

    @objc private func emailTapped() {
        presentEmail?(address.text!, qrCode.image!)
    }

    @objc private func textTapped() {
        presentText?(address.text!, qrCode.image!)
    }

    private func toggle(alertView: InViewAlert, shouldAdjustPadding: Bool) {
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
            if let newFrame = self.parent?.view.frame.expandVertically(deltaY) {
                self.parent?.view.frame = newFrame
            }
            alertView.toggle()
            self.parent?.view.layoutIfNeeded()
        }, completion: { _ in
            alertView.isExpanded = !alertView.isExpanded
            self.share.isEnabled = true
            self.address.isUserInteractionEnabled = true
            alertView.contentView?.isHidden = false
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ReceiveViewController: ModalDisplayable {
    var modalTitle: String {
        return NSLocalizedString("Receive", comment: "Receive modal title")
    }

    var modalSize: CGSize {
        let height: CGFloat = isRequestAmountVisible ? 410.0 : 410 - (C.padding[4] + C.Sizes.buttonHeight )
        return CGSize(width: view.frame.width, height: height)
    }

    var isFaqHidden: Bool {
        return false
    }
}
