// 
//  ShareGiftViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-12-06.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit
import CoinGecko

struct GiftInfo {
    let name: String
    let rate: SimplePrice
    let sats: Amount
}

class ShareGiftView: UIView {
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let qr = UIImageView()
    private let name = UILabel(font: Theme.h0Title, color: UIColor.white)
    private let subHeader = UILabel(font: Theme.h2Title, color: UIColor.white)
    private let separator = UIView(color: UIColor.white.withAlphaComponent(0.15))
    private let logo = UIImageView(image: UIImage(named: "LogoGradientSmall"))
    private let totalLabel = UILabel(font: Theme.body1, color: UIColor.white)
    private let total = UILabel(font: Theme.h0Title, color: UIColor.white)
    private let cell: GiftCurrencyCell
    private let disclaimer = UILabel(font: Theme.body1, color: UIColor.white.withAlphaComponent(0.2))
    private let disclaimer2 = UILabel(font: Theme.body1, color: UIColor.white.withAlphaComponent(0.4))
    private let share = BRDButton(title: "Share", type: .primary)
    private let gift: Gift
    private let showButton: Bool
    
    var didTapShare: (() -> Void)?
        
    init(gift: Gift, showButton: Bool = true) {
        self.gift = gift
        self.showButton = showButton
        self.cell = GiftCurrencyCell(rate: gift.rate ?? 0,
                                     amount: gift.amount ?? 0)
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        addSubview(blurView)
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(qr)
        contentView.addSubview(name)
        contentView.addSubview(subHeader)
        contentView.addSubview(separator)
        contentView.addSubview(logo)
        contentView.addSubview(totalLabel)
        contentView.addSubview(total)
        contentView.addSubview(cell)
        contentView.addSubview(disclaimer)
        contentView.addSubview(disclaimer2)
        addSubview(share)
    }
    
    private func addConstraints() {
        blurView.constrain(toSuperviewEdges: nil)
        let top = scrollView.topAnchor.constraint(lessThanOrEqualTo: topAnchor)
        let padding = showButton ? C.padding[2] : 0
        if !showButton {
            blurView.isHidden = true
            backgroundColor = Theme.primaryBackground
        } else {
            top.priority = .defaultLow
        }
        scrollView.constrain([
            top,
            scrollView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding)
        ])
        
        if showButton {
            scrollView.constrain([
                scrollView.bottomAnchor.constraint(equalTo: share.topAnchor, constant: -padding)
            ])
        } else {
            scrollView.constrain([
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        
        let contentViewPadding = showButton ? -C.padding[4] : 0
        contentView.constrain([
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.topAnchor.constraint(lessThanOrEqualTo: scrollView.topAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: widthAnchor, constant: contentViewPadding)
        ])
        qr.constrain([
            qr.topAnchor.constraint(equalTo: contentView.topAnchor, constant: C.padding[6]),
            qr.centerXAnchor.constraint(equalTo: centerXAnchor),
            qr.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            qr.heightAnchor.constraint(equalTo: qr.widthAnchor)])
        name.constrain([
            name.topAnchor.constraint(equalTo: qr.bottomAnchor, constant: C.padding[2]),
            name.centerXAnchor.constraint(equalTo: centerXAnchor)])
        subHeader.constrain([
            subHeader.topAnchor.constraint(equalTo: name.bottomAnchor, constant: C.padding[1]),
            subHeader.centerXAnchor.constraint(equalTo: centerXAnchor)])
        separator.constrain([
            separator.topAnchor.constraint(equalTo: subHeader.bottomAnchor, constant: C.padding[1]),
                                separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2]),
                                separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[2]),
            separator.heightAnchor.constraint(equalToConstant: 1.0)])
        logo.constrain([
            logo.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[6]),
                        logo.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: C.padding[2])])
        total.constrain([
            total.firstBaselineAnchor.constraint(equalTo: logo.bottomAnchor),
                            total.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -C.padding[2])])
        totalLabel.constrain([
            totalLabel.trailingAnchor.constraint(equalTo: total.trailingAnchor),
            totalLabel.bottomAnchor.constraint(equalTo: total.topAnchor)])
        cell.constrain([
            cell.topAnchor.constraint(equalTo: total.bottomAnchor, constant: C.padding[1]),
            cell.leadingAnchor.constraint(equalTo: logo.leadingAnchor),
            cell.trailingAnchor.constraint(equalTo: total.trailingAnchor),
            cell.heightAnchor.constraint(equalToConstant: 80.0)])
        
        disclaimer.constrain([
            disclaimer.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            disclaimer.topAnchor.constraint(equalTo: cell.bottomAnchor, constant: C.padding[1]),
            disclaimer.trailingAnchor.constraint(equalTo: cell.trailingAnchor)])
        disclaimer2.constrain([
            disclaimer2.leadingAnchor.constraint(equalTo: disclaimer.leadingAnchor),
            disclaimer2.topAnchor.constraint(equalTo: disclaimer.bottomAnchor, constant: C.padding[1]),
            disclaimer2.trailingAnchor.constraint(equalTo: disclaimer.trailingAnchor),
            disclaimer2.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -C.padding[2])
        ])
        
        share.constrain([
            share.heightAnchor.constraint(equalToConstant: 44.0),
            share.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            share.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            share.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[4])])
        
        if !showButton {
            share.constrain([share.heightAnchor.constraint(equalToConstant: 0.0)])
        }
    }
    
    private func setInitialData() {
        qr.image = gift.qrImage()
        qr.contentMode = .scaleAspectFit
        name.text = gift.name ?? "no name"
        subHeader.text = "Someone gifted you Bitcoin"
        
        if let btc = Currencies.btc.instance {
            let displayAmount = Amount(tokenString: "\(gift.amount ?? 0)", currency: btc)
            total.text = displayAmount.tokenDescription
        }
        total.textAlignment = .right
        
        totalLabel.text = "Approximate Total"
        totalLabel.textAlignment = .right
        
        disclaimer.text = "A network fee will be deducted from the total when claimed. Actual value depends on the current price of bitcoin."
        disclaimer2.text = "Download the BRD app for iPhone or Android. For more information visit brd.com/gift"
        [disclaimer, disclaimer2].forEach {
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
            $0.textAlignment = .center
        }
        
        contentView.backgroundColor = Theme.primaryBackground
        contentView.layer.cornerRadius = 10.0
        contentView.layer.masksToBounds = true
        scrollView.backgroundColor = UIColor.clear
        
        share.tap = {
            self.didTapShare?()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ShareGiftViewController: UIViewController {
    
    private let shareView: ShareGiftView
    private let coordinator: GiftSharingCoordinator
    
    init(gift: Gift) {
        self.shareView = ShareGiftView(gift: gift)
        self.coordinator = GiftSharingCoordinator(gift: gift)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }
    
    override func loadView() {
        view = shareView
        if #available(iOS 13.0, *) {
            shareView.didTapShare = coordinator.showShare
            self.coordinator.parent = self
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
