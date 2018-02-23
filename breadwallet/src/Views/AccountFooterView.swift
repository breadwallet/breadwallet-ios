//
//  AccountFooterView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountFooterView: UIView, Trackable {

    var sendCallback: (() -> Void)?
    var receiveCallback: (() -> Void)?
    var buyCallback: (() -> Void)?
    
    private var hasSetup = false
    private let currency: CurrencyDef

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
        let toolbar = UIToolbar()
        let separator = UIView(color: .separatorGray)
        addSubview(toolbar)
        addSubview(separator)
        
        toolbar.clipsToBounds = true // to remove separator line
        toolbar.isOpaque = true
        
        // buttons
        var buttonCount: Int
        
        let send = UIButton.rounded(title: S.Button.send)
        send.tintColor = .white
        send.backgroundColor = currency.colors.0
        send.addTarget(self, action: #selector(AccountFooterView.send), for: .touchUpInside)
        let sendButton = UIBarButtonItem(customView: send)

        let receive = UIButton.rounded(title: S.Button.receive)
        receive.tintColor = .white
        receive.backgroundColor = currency.colors.0
        receive.addTarget(self, action: #selector(AccountFooterView.receive), for: .touchUpInside)
        let receiveButton = UIBarButtonItem(customView: receive)

        let buy = UIButton.rounded(title: S.Button.buy)
        buy.tintColor = .white
        buy.backgroundColor = currency.colors.0
        buy.addTarget(self, action: #selector(AccountFooterView.buy), for: .touchUpInside)
        let buyButton = UIBarButtonItem(customView: buy)
        
        let paddingWidth = C.padding[2]
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        if currency.matches(Currencies.btc) && BRAPIClient.featureEnabled(.buyBitcoin) {
            toolbar.items = [
                flexibleSpace,
                sendButton,
                flexibleSpace,
                receiveButton,
                flexibleSpace,
                buyButton,
                flexibleSpace,
            ]
            buttonCount = 3
        } else {
            toolbar.items = [
                flexibleSpace,
                sendButton,
                flexibleSpace,
                receiveButton,
                flexibleSpace,
            ]
            buttonCount = 2
        }
        
        // constraints
        toolbar.constrain(toSuperviewEdges: nil)
        separator.constrainTopCorners(height: 0.5)
        
        let buttonWidth = (self.bounds.width - (paddingWidth * CGFloat(buttonCount+1))) / CGFloat(buttonCount)
        let buttonHeight = CGFloat(44.0)
        [sendButton, receiveButton, buyButton].forEach {
            $0.customView?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        }
    }

    @objc private func send() { sendCallback?() }
    @objc private func receive() { receiveCallback?() }
    @objc private func buy() {
        saveEvent("menu.didTapBuyBitcoin")
        buyCallback?()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
