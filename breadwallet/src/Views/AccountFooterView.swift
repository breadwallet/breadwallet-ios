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

    init() {
        super.init(frame: .zero)
    }

    override func layoutSubviews() {
        guard !hasSetup else { return }
        setup()
        hasSetup = true
    }

    private func setup() {
        let toolbar = UIToolbar()
        let separator = UIView(color: .secondaryShadow)
        
        let send = UIButton.rounded(title: S.Button.send)
        send.tintColor = .white
        send.backgroundColor = .orange
        send.addTarget(self, action: #selector(AccountFooterView.send), for: .touchUpInside)

        let receive = UIButton.rounded(title: S.Button.receive)
        receive.tintColor = .white
        receive.backgroundColor = .orange
        receive.addTarget(self, action: #selector(AccountFooterView.receive), for: .touchUpInside)

        let buy = UIButton.rounded(title: S.Button.buy)
        buy.tintColor = .white
        buy.backgroundColor = .orange
        buy.addTarget(self, action: #selector(AccountFooterView.buy), for: .touchUpInside)
        
        let padding = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        padding.width = C.padding[1]
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let sendButton = UIBarButtonItem(customView: send)
        let receiveButton = UIBarButtonItem(customView: receive)
        let buyButton = UIBarButtonItem(customView: buy)
        
        var buttonCount: Int
        
        // TODO: multi-currency support
        if BRAPIClient.featureEnabled(.buyBitcoin) {
            toolbar.items = [
                flexibleSpace,
                sendButton,
                padding,
                receiveButton,
                padding,
                buyButton,
                flexibleSpace,
            ]
            buttonCount = 3
        } else {
            toolbar.items = [
                flexibleSpace,
                sendButton,
                padding,
                receiveButton,
                flexibleSpace,
            ]
            buttonCount = 2
        }
        
        addSubview(toolbar)
        addSubview(separator)
        
        // constraints
        toolbar.constrain(toSuperviewEdges: nil)
        
        let buttonWidth = self.frame.width / CGFloat(buttonCount) - (padding.width * CGFloat(buttonCount+1))
        
        let constraints = [
            sendButton.customView?.widthAnchor.constraint(equalToConstant: buttonWidth),
            receiveButton.customView?.widthAnchor.constraint(equalToConstant: buttonWidth),
            buyButton.customView?.widthAnchor.constraint(equalToConstant: buttonWidth)
            ]
        NSLayoutConstraint.activate(constraints.flatMap{ $0 })
        
        separator.constrainTopCorners(height: 1.0)
    }

    @objc private func send() { sendCallback?() }
    @objc private func receive() { receiveCallback?() }
    @objc private func buy() {
        //TODO:BCH event name
        saveEvent("menu.didTapBuyBitcoin")
        buyCallback?()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
