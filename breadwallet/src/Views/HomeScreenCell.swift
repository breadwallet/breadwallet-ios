//
//  HomeScreenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-28.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

protocol HighlightableCell {
    func highlight()
    func unhighlight()
}

enum HomeScreenCellIds: String {
    case regularCell        = "CurrencyCell"
    case highlightableCell  = "HighlightableCurrencyCell"
}

class Background: UIView, GradientDrawable {

    var currency: Currency?

    override func layoutSubviews() {
        super.layoutSubviews()
        let maskLayer = CAShapeLayer()
        let corners: UIRectCorner = .allCorners
        maskLayer.path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners,
                                      cornerRadii: CGSize(width: C.Sizes.homeCellCornerRadius,
                                                          height: C.Sizes.homeCellCornerRadius)).cgPath
        layer.mask = maskLayer
    }

    override func draw(_ rect: CGRect) {
        guard let currency = currency else { return }
        let colors = currency.isSupported ? currency.colors : (UIColor.disabledCellBackground, UIColor.disabledCellBackground)
        drawGradient(start: colors.0, end: colors.1, rect)
    }
}

class HomeScreenCell: UITableViewCell, Subscriber {
    
    private let iconContainer = UIView(color: .transparentIconBackground)
    private let icon = UIImageView()
    private let currencyName = UILabel(font: Theme.body1Accent, color: Theme.primaryText)
    private let price = UILabel(font: Theme.body2, color: Theme.secondaryText)
    private let fiatBalance = UILabel(font: Theme.body1Accent, color: Theme.primaryText)
    private let tokenBalance = UILabel(font: Theme.body2, color: Theme.secondaryText)
    private let syncIndicator = SyncingIndicator(style: .home)
    
    let container = Background()    // not private for inheritance
        
    private var isSyncIndicatorVisible: Bool = false {
        didSet {
            UIView.crossfade(tokenBalance, syncIndicator, toRight: isSyncIndicatorVisible, duration: isSyncIndicatorVisible == oldValue ? 0.0 : 0.3)
            fiatBalance.textColor = (isSyncIndicatorVisible || !(container.currency?.isSupported ?? false)) ? .disabledWhiteText : .white
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    static func cellIdentifier() -> String {
        return "CurrencyCell"
    }
    
    func set(viewModel: AssetListViewModel) {
        accessibilityIdentifier = viewModel.currency.name
        container.currency = viewModel.currency
        icon.image = viewModel.currency.imageNoBackground
        icon.tintColor = viewModel.currency.isSupported ? .white : .disabledBackground
        iconContainer.layer.cornerRadius = (iconContainer.frame.width / 2)
        currencyName.text = viewModel.currency.name
        currencyName.textColor = viewModel.currency.isSupported ? .white : .disabledWhiteText
        price.text = viewModel.exchangeRate
        fiatBalance.text = viewModel.fiatBalance
        fiatBalance.textColor = viewModel.currency.isSupported ? .white : .disabledWhiteText
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
    
    func setupViews() {
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
        
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: 0,
                                                           left: C.padding[2],
                                                           bottom: -10,
                                                           right: -C.padding[2]))
        iconContainer.constrain([
            iconContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            iconContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconContainer.widthAnchor.constraint(equalTo: iconContainer.heightAnchor)
            ])
        icon.constrain(toSuperviewEdges: .zero)
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: C.padding[2]),
            currencyName.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])
            ])
        price.constrain([
            price.leadingAnchor.constraint(equalTo: currencyName.leadingAnchor),
            price.topAnchor.constraint(equalTo: currencyName.bottomAnchor)
            ])
        fiatBalance.constrain([
            fiatBalance.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            fiatBalance.leadingAnchor.constraint(greaterThanOrEqualTo: currencyName.trailingAnchor, constant: padding[2]),
            fiatBalance.topAnchor.constraint(equalTo: currencyName.topAnchor)
            ])
        tokenBalance.constrain([
            tokenBalance.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            tokenBalance.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: C.padding[2]),
            tokenBalance.bottomAnchor.constraint(equalTo: price.bottomAnchor)
            ])
        fiatBalance.setContentCompressionResistancePriority(.required, for: .vertical)
        fiatBalance.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        syncIndicator.constrain([
            syncIndicator.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            syncIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: C.padding[2]),
            syncIndicator.bottomAnchor.constraint(equalTo: tokenBalance.bottomAnchor, constant: 5.0)
            ])
        layoutIfNeeded()
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
