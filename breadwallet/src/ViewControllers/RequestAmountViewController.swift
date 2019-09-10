//
//  RequestAmountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-03.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private let qrSize: CGSize = CGSize(width: 186.0, height: 186.0)
private let smallButtonHeight: CGFloat = 32.0
private let buttonPadding: CGFloat = 20.0

class RequestAmountViewController: UIViewController {

    // Invoked with a wallet address and optional QR code image. This var is set by the
    // ModalPresenter when the RequestAmountViewController is created.
    var shareAddress: PresentShare?

    init(currency: Currency, receiveAddress: String) {
        self.currency = currency
        self.receiveAddress = receiveAddress
        amountView = AmountViewController(currency: currency, isPinPadExpandedAtLaunch: true, isRequesting: true)
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Private
    private let currency: Currency
    private let amountView: AmountViewController
    private let qrCode = UIImageView()
    private let address = UILabel(font: .customBody(size: 14.0))
    private let addressPopout = InViewAlert(type: .primary)
    private let share = BRDButton(title: S.Receive.share, type: .tertiary, image: #imageLiteral(resourceName: "Share"))
    private let border = UIView()
    private var topSharePopoutConstraint: NSLayoutConstraint?
    private let receiveAddress: String
    
    // MARK: - PinPad State
    private var amount: Amount? {
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
    }

    private func addSubviews() {
        view.addSubview(qrCode)
        view.addSubview(address)
        view.addSubview(addressPopout)
        view.addSubview(share)
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
            share.constraint(.width, constant: qrSize.width),
            share.constraint(.height, constant: smallButtonHeight) ])
        border.constrain([
            border.constraint(.width, toView: view),
            border.constraint(toBottom: share, constant: 20.0),
            border.constraint(.centerX, toView: view),
            border.constraint(.height, constant: 1.0),
            border.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setData() {
        view.backgroundColor = .white
        address.textAlignment = .center
        address.adjustsFontSizeToFitWidth = true
        address.minimumScaleFactor = 0.7
        address.textColor = .grayTextTint
        border.backgroundColor = .secondaryBorder

        address.text = receiveAddress
        if let uri = currency.addressURI(receiveAddress),
            let uriData = uri.data(using: .utf8),
            let qrImage = UIImage.qrCode(data: uriData) {
            qrCode.image = qrImage.resize(qrSize)
        }
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

    private func setQrCode() {
        guard let amount = amount else { return }
        let request = PaymentRequest.requestString(withAddress: receiveAddress, forAmount: amount)

        if let uriData = request.data(using: .utf8),
            let qrImage = UIImage.qrCode(data: uriData) {
            qrCode.image = qrImage.resize(qrSize)
        }
    }

    private func setupCopiedMessage() {
        let copiedMessage = UILabel(font: .customMedium(size: 14.0))
        copiedMessage.textColor = .white
        copiedMessage.text = S.Receive.copied
        copiedMessage.textAlignment = .center
        addressPopout.contentView = copiedMessage
    }

    @objc private func shareTapped() {
        guard let amount = amount else { return showErrorMessage(S.RequestAnAmount.noAmount) }
        let text = PaymentRequest.requestString(withAddress: receiveAddress, forAmount: amount)
        if let image = qrCode.image {
            shareAddress?(text, image)
        }
    }

    @objc private func addressTapped() {
        guard let text = address.text else { return }
        UIPasteboard.general.string = text
        toggle(alertView: addressPopout, shouldShrinkAfter: true)
    }
 
    private func toggle(alertView: InViewAlert, shouldShrinkAfter: Bool = false) {
        share.isEnabled = false
        address.isUserInteractionEnabled = false

        if alertView.isExpanded {
            alertView.contentView?.isHidden = true
        }

        UIView.spring(C.animationDuration, animations: {
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
                        self.toggle(alertView: alertView)
                    }
                })
            }
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RequestAmountViewController: ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.requestAmount
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return S.Receive.request
    }
}
