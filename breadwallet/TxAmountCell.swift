//
//  TxAmountCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-21.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxAmountCell: UITableViewCell, Subscriber {
    
    // MARK: - Accessors
    
    public var fiatAmount: String {
        get {
            return fiatAmountLabel.text ?? ""
        }
        set {
            fiatAmountLabel.text = newValue
        }
    }
    
    public var tokenAmount: String {
        get {
            return tokenAmountLabel.text ?? ""
        }
        set {
            tokenAmountLabel.text = newValue
        }
    }
    
    public var isBtcSwapped: Bool = false {
        didSet {
            swapCurrencyLabels(animated: true)
        }
    }
    
    public var store: Store? {
        didSet {
            if let store = store, !store.isEthLike { //FIXME - currency switching disabled for ethereum
                isBtcSwapped = store.state.isBtcSwapped
                let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
                container.addGestureRecognizer(gr)
                addSubscriptions()
            }
        }
    }

    // MARK: - Views
    
    private let largeFontSize: CGFloat = 26.0
    private let smallFontSize: CGFloat = 13.0
    
    private let container = UIView()
    private lazy var fiatAmountLabel = {
        UILabel(font: UIFont.customBold(size: largeFontSize))
    }()
    private lazy var tokenAmountLabel = {
        UILabel(font: UIFont.customMedium(size: largeFontSize))
    }()
    private let separator = UIView(color: .secondaryShadow)
    
    private var regularConstraints = [NSLayoutConstraint]()
    private var swappedConstraints = [NSLayoutConstraint]()
    
    // MARK: - Init
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }
    
    private func addSubviews() {
        contentView.addSubview(container)
        contentView.addSubview(separator)
        container.addSubview(fiatAmountLabel)
        container.addSubview(tokenAmountLabel)
    }
    
    private func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[2],
                                                           left: C.padding[2],
                                                           bottom: -C.padding[2],
                                                           right: -C.padding[2]))
        
        fiatAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        tokenAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // regular = token on top
        regularConstraints = [
            tokenAmountLabel.constraint(.top, toView: container),
            tokenAmountLabel.constraint(.leading, toView: container),
            tokenAmountLabel.constraint(.trailing, toView: container),
            fiatAmountLabel.constraint(toBottom: tokenAmountLabel, constant: -C.padding[1]),
            fiatAmountLabel.constraint(.leading, toView: container),
            fiatAmountLabel.constraint(.trailing, toView: container),
            fiatAmountLabel.constraint(.bottom, toView: container)
            ].flatMap { $0 }
        
        // swapped = fiat on top
        swappedConstraints = [
            fiatAmountLabel.constraint(.top, toView: container),
            fiatAmountLabel.constraint(.leading, toView: container),
            fiatAmountLabel.constraint(.trailing, toView: container),
            tokenAmountLabel.constraint(toBottom: fiatAmountLabel, constant: -C.padding[1]),
            tokenAmountLabel.constraint(.leading, toView: container),
            tokenAmountLabel.constraint(.trailing, toView: container),
            tokenAmountLabel.constraint(.bottom, toView: container)
            ].flatMap { $0 }
        
        swapCurrencyLabels(animated: false)
        
        separator.constrainBottomCorners(height: 0.5)
    }
    
    private func setupStyle() {
        fiatAmountLabel.textColor = .txListGreen
        fiatAmountLabel.textAlignment = .center
        tokenAmountLabel.textColor = .grayText
        tokenAmountLabel.textAlignment = .center
    }
    
    private func addSubscriptions() {
        store?.lazySubscribe(self,
                             selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                             callback: { self.isBtcSwapped = $0.isBtcSwapped })
    }
    
    deinit {
        store?.unsubscribe(self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Currency Switch
    
    private func shrink(view: UIView) {
        view.transform = .identity // must reset the view's transform before we calculate the next transform
        let scaleFactor: CGFloat = smallFontSize/largeFontSize
        let center = view.center
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        view.transform = scale
        view.center = center
    }
    
    @objc private func currencySwitchTapped() {
        store?.perform(action: CurrencyChange.toggle())
    }
    
    private func swapCurrencyLabels(animated: Bool) {
        layoutIfNeeded()
        UIView.spring(animated ? 0.7 : 0.0, animations: {
            if self.isBtcSwapped {
                self.fiatAmountLabel.transform = .identity
                self.fiatAmountLabel.textColor = .txListGreen
                self.tokenAmountLabel.textColor = .grayText
                self.shrink(view: self.tokenAmountLabel)
                NSLayoutConstraint.deactivate(self.regularConstraints)
                NSLayoutConstraint.activate(self.swappedConstraints)
            } else {
                self.tokenAmountLabel.transform = .identity
                self.tokenAmountLabel.textColor = .txListGreen
                self.fiatAmountLabel.textColor = .grayText
                self.shrink(view: self.fiatAmountLabel)
                NSLayoutConstraint.deactivate(self.swappedConstraints)
                NSLayoutConstraint.activate(self.regularConstraints)
            }
            self.layoutIfNeeded()
        }) { _ in }
    }
}
