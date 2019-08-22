//
//  ReceiveViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import BRCrypto

private let qrSize: CGFloat = 186.0
private let smallButtonHeight: CGFloat = 32.0
private let buttonPadding: CGFloat = 20.0
private let smallSharePadding: CGFloat = 12.0
private let largeSharePadding: CGFloat = 20.0

typealias PresentShare = (String, UIImage) -> Void

class ReceiveViewController: UIViewController, Subscriber, Trackable {

    // MARK: - Public
    
    // Invoked with a wallet address and optional QR code image. This var is set by the
    // ModalPresenter when the ReceiveViewController is created.
    var shareAddress: PresentShare?
    
    init(currency: Currency, isRequestAmountVisible: Bool, isBTCLegacy: Bool = false) {
        self.currency = currency
        self.isRequestAmountVisible = isRequestAmountVisible
        self.isBTCLegacy = isBTCLegacy
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Private
    private let currency: Currency
    private let isBTCLegacy: Bool
    private let qrCode = UIImageView()
    private let address = UILabel(font: .customBody(size: 14.0))
    private let addressPopout = InViewAlert(type: .primary)
    private let share = BRDButton(title: S.Receive.share, type: .tertiary, image: #imageLiteral(resourceName: "Share"))
    private let sharePopout = InViewAlert(type: .secondary)
    private let border = UIView()
    private let request = BRDButton(title: S.Receive.request, type: .secondary)
    private let addressButton = UIButton(type: .system)
    private var topSharePopoutConstraint: NSLayoutConstraint?
    fileprivate let isRequestAmountVisible: Bool
    private var requestTop: NSLayoutConstraint?
    private var requestBottom: NSLayoutConstraint?

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setStyle()
        addActions()
        setupCopiedMessage()

        //TODO:CRYPTO this does not work since receive address is not a stored property in WalletState
        // need to hook up a WalletListener
//        if isBTCLegacy {
//            Store.subscribe(self, selector: { $0[self.currency]?.legacyReceiveAddress != $1[self.currency]?.legacyReceiveAddress }, callback: { _ in
//                self.setReceiveAddress()
//            })
//        } else {
//            Store.subscribe(self, selector: { $0[self.currency]?.receiveAddress != $1[self.currency]?.receiveAddress }, callback: { _ in
//                self.setReceiveAddress()
//            })
//        }
    }

    private func addSubviews() {
        view.addSubview(qrCode)
        view.addSubview(address)
        view.addSubview(addressPopout)
        view.addSubview(share)
        view.addSubview(sharePopout)
        view.addSubview(border)
        view.addSubview(request)
        view.addSubview(addressButton)
    }

    private func addConstraints() {
        qrCode.constrain([
            qrCode.constraint(.width, constant: qrSize),
            qrCode.constraint(.height, constant: qrSize),
            qrCode.constraint(.top, toView: view, constant: C.padding[4]),
            qrCode.constraint(.centerX, toView: view) ])
        address.constrain([
            address.constraint(toBottom: qrCode, constant: C.padding[1]),
            address.constraint(.leading, toView: view),
            address.constraint(.trailing, toView: view) ])
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
        requestTop = request.constraint(toBottom: border, constant: C.padding[3])
        requestBottom = request.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[5] : -C.padding[2])
        request.constrain([
            requestTop,
            request.constraint(.leading, toView: view, constant: C.padding[2]),
            request.constraint(.trailing, toView: view, constant: -C.padding[2]),
            request.constraint(.height, constant: C.Sizes.buttonHeight),
            requestBottom ])
        addressButton.constrain([
            addressButton.leadingAnchor.constraint(equalTo: address.leadingAnchor, constant: -C.padding[1]),
            addressButton.topAnchor.constraint(equalTo: qrCode.topAnchor),
            addressButton.trailingAnchor.constraint(equalTo: address.trailingAnchor, constant: C.padding[1]),
            addressButton.bottomAnchor.constraint(equalTo: address.bottomAnchor, constant: C.padding[1]) ])
    }

    private func setStyle() {
        view.backgroundColor = .white
        address.textColor = .grayTextTint
        address.textAlignment = .center
        address.adjustsFontSizeToFitWidth = true
        address.minimumScaleFactor = 0.7
        border.backgroundColor = .secondaryBorder
        
        if !isRequestAmountVisible {
            border.isHidden = true
            request.isHidden = true
            request.isEnabled = false
            request.constrain([
                request.heightAnchor.constraint(equalToConstant: 0.0) ])
            requestTop?.constant = 0.0
        }
        sharePopout.clipsToBounds = true
        addressButton.setBackgroundImage(UIImage.imageForColor(.secondaryShadow), for: .highlighted)
        addressButton.layer.cornerRadius = 4.0
        addressButton.layer.masksToBounds = true
        setReceiveAddress()
    }

    private func setReceiveAddress() {
        guard let wallet = currency.wallet else { return assertionFailure() }
        let addressText = isBTCLegacy ? wallet.receiveAddress(for: .btcLegacy) : wallet.receiveAddress
        address.text = addressText
        if let uri = currency.addressURI(addressText),
            let uriData = uri.data(using: .utf8),
            let qrImage = UIImage.qrCode(data: uriData) {
            qrCode.image = qrImage.resize(CGSize(width: qrSize, height: qrSize))
        }
    }

    private func addActions() {
        addressButton.tap = { [weak self] in
            self?.addressTapped()
        }
        request.tap = { [weak self] in
            guard let `self` = self,
                let modalTransitionDelegate = self.parent?.transitioningDelegate as? ModalTransitionDelegate,
                let address = self.address.text else { return }
            modalTransitionDelegate.reset()
            self.dismiss(animated: true, completion: {
                Store.perform(action: RootModalActions.Present(modal: .requestAmount(currency: self.currency, address: address)))
            })
        }
        share.addTarget(self, action: #selector(ReceiveViewController.shareTapped), for: .touchUpInside)
    }

    private func setupCopiedMessage() {
        let copiedMessage = UILabel(font: .customMedium(size: 14.0))
        copiedMessage.textColor = .white
        copiedMessage.text = S.Receive.copied
        copiedMessage.textAlignment = .center
        addressPopout.contentView = copiedMessage
    }
    
    @objc private func shareTapped() {
        guard let text = address.text, let image = qrCode.image else { return }
        shareAddress?(text, image)
    }

    @objc private func addressTapped() {
        guard let text = address.text else { return }
        saveEvent("receive.copiedAddress")
        UIPasteboard.general.string = text
        toggle(alertView: addressPopout, shouldAdjustPadding: false, shouldShrinkAfter: true)
        if sharePopout.isExpanded {
            toggle(alertView: sharePopout, shouldAdjustPadding: true)
        }
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

extension ReceiveViewController: ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.receiveTx
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return "\(S.Receive.title) \(currency.code)"
    }
}
