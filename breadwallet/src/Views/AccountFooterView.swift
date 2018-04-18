//
//  AccountFooterView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountFooterView: UIView, Subscriber, Trackable {

    var sendCallback: (() -> Void)?
    var receiveCallback: (() -> Void)?
    var buyCallback: (() -> Void)?
    var sellCallback: (() -> Void)?
    
    private var hasSetup = false
    private let currency: CurrencyDef
    private let toolbar = UIToolbar()
    
    init(currency: CurrencyDef) {
        self.currency = currency
        super.init(frame: .zero)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasSetup else { return }
        setup()
        hasSetup = true
    }

    private func setup() {
        let separator = UIView(color: .separatorGray)
        addSubview(toolbar)
        addSubview(separator)
        
        toolbar.clipsToBounds = true // to remove separator line
        toolbar.isOpaque = true
        
        // constraints
        toolbar.constrain(toSuperviewEdges: nil)
        separator.constrainTopCorners(height: 0.5)
        
        setupToolbarButtons()
        
        Store.subscribe(self, name: .didUpdateFeatureFlags) { [weak self] _ in
            self?.setupToolbarButtons()
        }
    }
    
    private func setupToolbarButtons() {
        
        let buttons = [(S.Button.send, #selector(AccountFooterView.send)),
                       (S.Button.receive, #selector(AccountFooterView.receive)),
                       (S.Button.buy, #selector(AccountFooterView.buy)),
                       (S.Button.sell, #selector(AccountFooterView.sell))].map { (title, selector) -> UIBarButtonItem in
                        let button = UIButton.rounded(title: title)
                        button.tintColor = .white
                        button.backgroundColor = currency.colors.1
                        button.addTarget(self, action: selector, for: .touchUpInside)
                        return UIBarButtonItem(customView: button)
        }
        
        let paddingWidth = C.padding[2]
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            flexibleSpace,
            buttons[0],
            flexibleSpace,
            buttons[1],
            flexibleSpace,
            buttons[2],
            flexibleSpace,
            buttons[3],
            flexibleSpace
        ]
        
        let buttonWidth = (self.bounds.width - (paddingWidth * CGFloat(buttons.count+1))) / CGFloat(buttons.count)
        let buttonHeight = CGFloat(44.0)
        buttons.forEach {
            $0.customView?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        }
    }

    @objc private func send() { sendCallback?() }
    @objc private func receive() { receiveCallback?() }
    @objc private func buy() {
        saveEvent("currency.didTapBuyBitcoin", attributes: ["currency": currency.code.lowercased()])
        buyCallback?()
    }
    @objc private func sell() {
        saveEvent("currency.didTapSellBitcoin", attributes: ["currency": currency.code.lowercased()])
        sellCallback?()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
