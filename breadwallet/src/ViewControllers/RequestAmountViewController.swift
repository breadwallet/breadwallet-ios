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
        self.currencySlider = CurrencySlider(rates: store.state.rates,
                                             defaultCode: store.state.defaultCurrencyCode,
                                             isBtcSwapped: store.state.isBtcSwapped)
        super.init(nibName: nil, bundle: nil)
    }

    //MARK - Private
    private let amount = SendAmountCell(placeholder: S.Send.amountLabel)
    private let currencyButton = ShadowButton(title: S.Send.defaultCurrencyLabel, type: .tertiary)
    private let currencyContainer = InViewAlert(type: .secondary)
    private let pinPad = PinPadViewController(style: .white, keyboardType: .decimalPad)
    private let qrCode = UIImageView()
    private let address = UILabel(font: .customBody(size: 14.0))
    private let addressPopout = InViewAlert(type: .primary)
    private let share = ShadowButton(title: S.Receive.share, type: .tertiary, image: #imageLiteral(resourceName: "Share"))
    private let sharePopout = InViewAlert(type: .secondary)
    private let border = UIView()
    private var topSharePopoutConstraint: NSLayoutConstraint?
    private var currencyContainerHeight: NSLayoutConstraint?
    private let currencyBorder = UIView(color: .secondaryShadow)
    private let wallet: BRWallet
    private let currencySlider: CurrencySlider

    //MARK - PinPad State
    private var satoshis: UInt64 = 0 {
        didSet {
            setAmountLabel()
            setQrCode()
        }
    }
    private var minimumFractionDigits = 0
    private var hasTrailingDecimal = false
    private var selectedRate: Rate? {
        didSet {
            setAmountLabel()
            setQrCode()
            //Update pinpad content to match currency change
            let currentOutput = amount.content ?? ""
            var set = CharacterSet.decimalDigits
            set.formUnion(CharacterSet(charactersIn: "."))
            pinPad.currentOutput = String(String.UnicodeScalarView(currentOutput.unicodeScalars.filter { set.contains($0) }))
        }
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
        addActions()
        setupCopiedMessage()
        setupShareButtons()
        amount.clipsToBounds = true
        currencyContainer.contentView = currencySlider
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        amount.textField.becomeFirstResponder()
        currencySlider.load()
    }

    private func addSubviews() {
        view.addSubview(amount)
        view.addSubview(currencyContainer)
        view.addSubview(currencyBorder)
        view.addSubview(qrCode)
        view.addSubview(address)
        view.addSubview(addressPopout)
        view.addSubview(share)
        view.addSubview(sharePopout)
        view.addSubview(border)
        amount.addSubview(currencyButton)
    }

    private func addConstraints() {
        amount.constrainTopCorners(height: SendCell.defaultHeight)
        currencyButton.constrain([
            currencyButton.constraint(.centerY, toView: amount.accessoryView),
            currencyButton.constraint(.trailing, toView: amount, constant: -C.padding[2]) ])

        currencyContainer.heightConstraint = currencyContainer.heightAnchor.constraint(equalToConstant: 0.0)
        currencyContainer.pinTo(viewAbove: amount)
        currencyContainer.constrain([currencyContainer.heightConstraint])
        currencyContainer.arrowXLocation = view.bounds.width - 64.0/2.0 - C.padding[2]

        currencyBorder.pinTo(viewAbove: currencyContainer, height: 1.0)

        addChildViewController(pinPad, layout: {
            pinPad.view.pinTo(viewAbove: currencyBorder, padding: 0.0, height: pinPad.height)
        })
        qrCode.constrain([
            qrCode.constraint(.width, constant: qrSize.width),
            qrCode.constraint(.height, constant: qrSize.height),
            qrCode.topAnchor.constraint(equalTo: pinPad.view.bottomAnchor, constant: C.padding[2]),
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
        currencyButton.isToggleable = true

        amount.border.isHidden = true //Hide the default border because it needs to stay below the currency switcher when it gets expanded
    }

    private func addActions() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(RequestAmountViewController.addressTapped))
        address.addGestureRecognizer(gr)
        address.isUserInteractionEnabled = true
        share.addTarget(self, action: #selector(RequestAmountViewController.shareTapped), for: .touchUpInside)

        pinPad.ouputDidUpdate = { [weak self] output in
            self?.amount.content = output
        }

        amount.textFieldDidChange = { [weak self] text in
            guard let myself = self else { return }
            myself.minimumFractionDigits = 0 //set default
            if let decimalLocation = text.range(of: NumberFormatter().currencyDecimalSeparator)?.upperBound {
                let locationValue = text.distance(from: text.endIndex, to: decimalLocation)
                if locationValue == -2 {
                    myself.minimumFractionDigits = 2
                } else if locationValue == -1 {
                    myself.minimumFractionDigits = 1
                }
            }

            //If trailing decimal, append the decimal to the output
            myself.hasTrailingDecimal = false //set default
            if let decimalLocation = text.range(of: NumberFormatter().currencyDecimalSeparator)?.upperBound {
                if text.endIndex == decimalLocation {
                    myself.hasTrailingDecimal = true
                }
            }

            //Satoshis amount should be the last thing to be set here
            //b/c it triggers a UI update
            if let value = Double(text) {
                myself.satoshis = UInt64((value * 100.0).rounded(.toNearestOrEven))
            } else {
                myself.satoshis = 0
            }
        }

        currencySlider.didSelectCurrency = { [weak self] rate in
            if rate.code == "BTC" {
                self?.selectedRate = nil
            } else {
                self?.selectedRate = rate
            }
            self?.currencyButton.title = "\(rate.code) (\(rate.currencySymbol))"
            self?.currencySwitchTapped() //collapse currency view
        }
        currencyContainer.contentView = currencySlider

        currencyButton.tap = { [weak self] in
            self?.currencySwitchTapped()
        }
    }

    private func currencySwitchTapped() {
        UIView.spring(C.animationDuration, animations: {
            self.currencyContainer.toggle()
            self.view.superview?.layoutIfNeeded()
        }, completion: {_ in
            self.currencyContainer.isExpanded = !self.currencyContainer.isExpanded
        })
    }

    private func setAmountLabel() {
        var formatter: NumberFormatter
        var output = ""
        if let selectedRate = selectedRate {
            formatter = NumberFormatter()
            formatter.locale = selectedRate.locale
            formatter.numberStyle = .currency
            let amount = (Double(satoshis)/Double(C.satoshis))*selectedRate.rate
            output = formatter.string(from: amount as NSNumber) ?? "error"
        } else {
            formatter = Amount.bitsFormatter
            output = formatter.string(from: Double(satoshis)/100.0 as NSNumber) ?? "error"
        }

        if satoshis > 0 {
            formatter.minimumFractionDigits = minimumFractionDigits

            if hasTrailingDecimal {
                output = output.appending(".")
            }
        }
        amount.setAmountLabel(text: output)
    }

    private func setQrCode(){
        let request = PaymentRequest.requestString(withAddress: wallet.receiveAddress, forAmount: satoshis)
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
        presentEmail?(address.text!, qrCode.image!)
    }

    @objc private func textTapped() {
        presentText?(address.text!, qrCode.image!)
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
