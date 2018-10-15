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

    private let iconContainer = UIView(color: .transparentIconBackground)
    private let icon = UIImageView()
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
        icon.image = viewModel.currency.imageNoBackground
        currencyName.text = viewModel.currency.name
        price.text = viewModel.exchangeRate
        fiatBalance.text = viewModel.fiatBalance
        tokenBalance.text = viewModel.tokenBalance
        container.setNeedsDisplay()
        
        Store.subscribe(self, selector: { $0[viewModel.currency]?.syncState != $1[viewModel.currency]?.syncState },
                        callback: { state in
                            guard let syncState = state[viewModel.currency]?.syncState else { return }
                            self.syncIndicator.syncState = syncState
                            switch syncState {
                            case .connecting:
                                self.isSyncIndicatorVisible = true
                            case .syncing:
                                self.isSyncIndicatorVisible = true
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
    
    func refreshAnimations() {}

    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }

    private func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(iconContainer)
        iconContainer.addSubview(icon)
        container.addSubview(currencyName)
        container.addSubview(price)
        container.addSubview(fiatBalance)
        container.addSubview(tokenBalance)
        container.addSubview(syncIndicator)
        
        syncIndicator.isHidden = true
    }

    private func addConstraints() {
        let padding = Padding(increment: 5.0)
        
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: padding[1],
                                                           left: padding[2],
                                                           bottom: -padding[1],
                                                           right: -padding[2]))
        iconContainer.constrain([
            iconContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding[2]),
            iconContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),
            iconContainer.widthAnchor.constraint(equalTo: iconContainer.heightAnchor)
            ])
        icon.constrain(toSuperviewEdges: UIEdgeInsets(top: 2.0, left: 2.0, bottom: -2.0, right: -2.0))
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: padding[2]),
            currencyName.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: -2.0)
            ])
        price.constrain([
            price.leadingAnchor.constraint(equalTo: currencyName.leadingAnchor),
            price.topAnchor.constraint(equalTo: currencyName.bottomAnchor),
            price.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 1.0)
            ])
        fiatBalance.constrain([
            fiatBalance.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding[2]),
            fiatBalance.leadingAnchor.constraint(greaterThanOrEqualTo: currencyName.trailingAnchor, constant: padding[2]),
            fiatBalance.topAnchor.constraint(equalTo: currencyName.topAnchor),
            ])
        tokenBalance.constrain([
            tokenBalance.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            tokenBalance.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: padding[2]),
            tokenBalance.bottomAnchor.constraint(equalTo: price.bottomAnchor)
            ])
        fiatBalance.setContentCompressionResistancePriority(.required, for: .vertical)
        fiatBalance.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        syncIndicator.constrain([
            syncIndicator.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            syncIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: padding[2]),
            syncIndicator.bottomAnchor.constraint(equalTo: tokenBalance.bottomAnchor, constant: 5.0)
            ])
    }

    private func setupStyle() {
        selectionStyle = .none
        backgroundColor = .clear
        iconContainer.layer.cornerRadius = 6.0
        iconContainer.clipsToBounds = true
        icon.tintColor = .white
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
