//
//  AccountFooterView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class AccountFooterView: UIView, Subscriber, Trackable {
    
    static let height: CGFloat = 67.0

    var sendCallback: (() -> Void)?
    var receiveCallback: (() -> Void)?
    var buyCallback: (() -> Void)?
    var sellCallback: (() -> Void)?
    
    private var hasSetup = false
    private let currency: Currency
    private let toolbar = UIToolbar()
    
    init(currency: Currency) {
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
        
        backgroundColor = currency.colors.1
        
        toolbar.clipsToBounds = true // to remove separator line
        toolbar.isOpaque = true
        toolbar.isTranslucent = false
        toolbar.barTintColor = backgroundColor
        
        // constraints
        toolbar.constrainTopCorners(height: AccountFooterView.height)
        separator.constrainTopCorners(height: 0.5)
        
        setupToolbarButtons()
    }
    
    private func setupToolbarButtons() {
        
        let buttons = [(S.Button.send, #selector(AccountFooterView.send)),
                       (S.Button.receive, #selector(AccountFooterView.receive))].map { (title, selector) -> UIBarButtonItem in
                        let button = UIButton.rounded(title: title)
                        button.tintColor = .white
                        button.backgroundColor = .transparentWhite
                        button.addTarget(self, action: selector, for: .touchUpInside)
                        return UIBarButtonItem(customView: button)
        }
        
        let paddingWidth = C.padding[2]
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = C.padding[1]
        
        toolbar.items = [
            flexibleSpace,
            buttons[0],
            fixedSpace,
            buttons[1],
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
