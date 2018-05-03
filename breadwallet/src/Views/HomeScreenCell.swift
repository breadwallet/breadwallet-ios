//
//  HomeScreenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class Background : UIView, GradientDrawable {

    var currency: CurrencyDef?

    override func layoutSubviews() {
        super.layoutSubviews()
        let maskLayer = CAShapeLayer()
        let corners: UIRectCorner = .allCorners
        maskLayer.path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 4.0, height: 4.0)).cgPath
        layer.mask = maskLayer
    }

    override func draw(_ rect: CGRect) {
        guard let currency = currency else { return }
        drawGradient(start: currency.colors.0, end: currency.colors.1, rect)
    }
}

class HomeScreenCell : UITableViewCell, Subscriber {
    
    static let cellIdentifier = "CurrencyCell"

    private let currencyName = UILabel(font: .customBold(size: 18.0), color: .white)
    private let price = UILabel(font: .customBold(size: 14.0), color: .transparentWhiteText)
    private let fiatBalance = UILabel(font: .customBold(size: 18.0), color: .white)
    private let tokenBalance = UILabel(font: .customBold(size: 14.0), color: .transparentWhiteText)
    private let syncIndicator = SyncingIndicator(style: .home)
    private let container = Background()
    
    private var isSyncIndicatorVisible: Bool = false {
        didSet {
            UIView.crossfade(tokenBalance, syncIndicator, toRight: isSyncIndicatorVisible, duration: isSyncIndicatorVisible == oldValue ? 0.0 : 0.3)
            fiatBalance.textColor = isSyncIndicatorVisible ? .disabledWhiteText : .white
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func set(viewModel: AssetListViewModel) {
        accessibilityIdentifier = viewModel.currency.name
        container.currency = viewModel.currency
        currencyName.text = viewModel.currency.name
        price.text = viewModel.exchangeRate
        fiatBalance.text = viewModel.fiatBalance
        tokenBalance.text = viewModel.tokenBalance
        container.setNeedsDisplay()
        
        Store.subscribe(self, selector: { $0[viewModel.currency]?.syncState != $1[viewModel.currency]?.syncState },
                        callback: { state in
                            guard let syncState = state[viewModel.currency]?.syncState else { return }
                            switch syncState {
                            case .connecting:
                                self.isSyncIndicatorVisible = true
                                self.syncIndicator.text = S.SyncingView.connecting
                            case .syncing:
                                self.isSyncIndicatorVisible = true
                                self.syncIndicator.text = S.SyncingView.syncing
                            case .success:
                                self.isSyncIndicatorVisible = false
                            }
        })
        
        Store.subscribe(self, selector: {
            return $0[viewModel.currency]?.lastBlockTimestamp != $1[viewModel.currency]?.lastBlockTimestamp },
                        callback: { state in
                            if let progress = state[viewModel.currency]?.syncProgress {
                                self.syncIndicator.progress = CGFloat(progress)
                            }
        })
    }
    
    func refreshAnimations() {
        syncIndicator.pulse()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }

    private func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(currencyName)
        container.addSubview(price)
        container.addSubview(fiatBalance)
        container.addSubview(tokenBalance)
        container.addSubview(syncIndicator)
        
        syncIndicator.isHidden = true
    }

    private func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1]*0.5,
                                                           left: C.padding[2],
                                                           bottom: -C.padding[1],
                                                           right: -C.padding[2]))
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            currencyName.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])
            ])
        price.constrain([
            price.leadingAnchor.constraint(equalTo: currencyName.leadingAnchor),
            price.topAnchor.constraint(equalTo: currencyName.bottomAnchor),
            price.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])
            ])
        fiatBalance.constrain([
            fiatBalance.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            fiatBalance.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]),
            fiatBalance.leadingAnchor.constraint(greaterThanOrEqualTo: currencyName.trailingAnchor, constant: C.padding[1])
            ])
        tokenBalance.constrain([
            tokenBalance.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            tokenBalance.topAnchor.constraint(equalTo: fiatBalance.bottomAnchor),
            tokenBalance.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: C.padding[1]),
            tokenBalance.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])
            ])
        
        syncIndicator.constrain([
            syncIndicator.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            syncIndicator.topAnchor.constraint(equalTo: fiatBalance.bottomAnchor),
            syncIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: C.padding[1]),
            syncIndicator.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])
            ])
    }

    private func setupStyle() {
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    override func prepareForReuse() {
        Store.unsubscribe(self)
    }
    
    deinit {
        Store.unsubscribe(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
