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
        
        let sendItem = UIBarButtonItem(customView: send)
        let receiveItem = UIBarButtonItem(customView: receive)
        let buyItem = UIBarButtonItem(customView: buy)
        
        var buttonCount: Int
        
        if BRAPIClient.featureEnabled(.buyBitcoin) {
            toolbar.items = [
                flexibleSpace,
                sendItem,
                padding,
                receiveItem,
                padding,
                buyItem,
                flexibleSpace,
            ]
            buttonCount = 3
        } else {
            toolbar.items = [
                flexibleSpace,
                sendItem,
                padding,
                receiveItem,
                flexibleSpace,
            ]
            buttonCount = 2
        }
        
        addSubview(toolbar)
        addSubview(separator)
        
        // constraints
        toolbar.constrain(toSuperviewEdges: nil)
        
        let buttonWidth: CGFloat = self.frame.width / CGFloat(buttonCount) - (padding.width * 2.0)
        
        let constraints = [
            sendItem.customView?.widthAnchor.constraint(equalToConstant: buttonWidth),
            receiveItem.customView?.widthAnchor.constraint(equalToConstant: buttonWidth),
            buyItem.customView?.widthAnchor.constraint(equalToConstant: buttonWidth)
            ]
        NSLayoutConstraint.activate(constraints.flatMap{ $0 })
        
        separator.constrainTopCorners(height: 1.0)
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
