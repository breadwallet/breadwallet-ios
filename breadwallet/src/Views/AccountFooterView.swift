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
    var giftCallback: (() -> Void)?
    
    private var hasSetup = false
    private let currency: Currency
    private let toolbar = UIToolbar()
    private var giftButton: UIButton?
    
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

    private func toRadian(value: Int) -> CGFloat {
        return CGFloat(Double(value) / 180.0 * .pi)
    }
    
    func jiggle() {
        guard let button = giftButton else { return }

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        rotation.values = [-10, 10, -5, 5, -3, 3, -2, 2, 0].map {
            self.toRadian(value: $0)
        }
        
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        scale.values = [1.4, 1.35, 1.3, 1.25, 1.2, 1.15, 1.1, 1.05, 1.0]
        
        let shakeGroup: CAAnimationGroup = CAAnimationGroup()
        shakeGroup.animations = [rotation, scale]
        shakeGroup.duration = 0.8
        button.imageView?.layer.add(shakeGroup, forKey: "jiggle")
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
        var buttons = [
            (S.Button.send, #selector(AccountFooterView.send)),
            (S.Button.receive, #selector(AccountFooterView.receive))
        ].compactMap { (title, selector) -> UIBarButtonItem in
            let button = UIButton.rounded(title: title)
            button.tintColor = .white
            button.backgroundColor = .transparentWhite
            button.addTarget(self, action: selector, for: .touchUpInside)
            return UIBarButtonItem(customView: button)
        }
        
        if currency.isGiftingEnabled {
            let giftButton = UIButton.rounded(image: "Gift")
            giftButton.tap = giftCallback
            self.giftButton = giftButton
            buttons.append(UIBarButtonItem(customView: giftButton))
        }
        
        let paddingWidth = C.padding[2]
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = C.padding[1]
        
        if currency.isGiftingEnabled {
            toolbar.items = [
                flexibleSpace,
                buttons[0],
                fixedSpace,
                buttons[1],
                fixedSpace,
                buttons[2],
                flexibleSpace
            ]
        } else {
            toolbar.items = [
                flexibleSpace,
                buttons[0],
                fixedSpace,
                buttons[1],
                flexibleSpace
            ]
        }
        
        if currency.isGiftingEnabled {
            let giftingButtonWidth: CGFloat = 44.0
            let buttonCount = 2
            let buttonWidth = (self.bounds.width - (paddingWidth * CGFloat(buttonCount+1))) / CGFloat(buttonCount) - (giftingButtonWidth)/2.0
            let buttonHeight = CGFloat(44.0)
            for (index, element) in buttons.enumerated() {
                if index != 2 {
                    element.customView?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
                } else {
                    element.customView?.frame = CGRect(x: 0, y: 0, width: giftingButtonWidth, height: buttonHeight)
                }
            }
        } else {
            let buttonWidth = (self.bounds.width - (paddingWidth * CGFloat(buttons.count+1))) / CGFloat(buttons.count)
            let buttonHeight = CGFloat(44.0)
            buttons.forEach {
                $0.customView?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
            }
        }

    }

    @objc private func send() { sendCallback?() }
    @objc private func receive() { receiveCallback?() }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
