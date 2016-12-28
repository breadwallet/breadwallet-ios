//
//  CurrencySlider.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-18.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let buttonSize = CGSize(width: 64.0, height: 32.0)

class CurrencySlider : UIView {

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    var didSelectCurrency: ((String) -> Void)?

    private let currencies = ["USD ($)", "BTC (b)", "EUR (€)", "GBP (£)", "AUD ($)"]
    private var buttons = [ShadowButton]()

    private func setupViews() {
        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.constrain(toSuperviewEdges: nil)

        var previous: ShadowButton?
        currencies.forEach {
            let button = ShadowButton(title: $0, type: .tertiary)
            button.addTarget(self, action: #selector(CurrencySlider.tapped(sender:)), for: .touchUpInside)
            button.isToggleable = true
            buttons.append(button)
            if $0 == "USD ($)" {
                button.isSelected = true
            }
            scrollView.addSubview(button)

            let leadingConstraint: NSLayoutConstraint
            if let previous = previous {
                leadingConstraint = button.constraint(toTrailing: previous, constant: C.padding[1])!
            } else {
                leadingConstraint = button.constraint(.leading, toView: scrollView, constant: C.padding[1])!
            }

            var trailingConstraint: NSLayoutConstraint?
            if currencies.last == $0 {
                trailingConstraint = button.constraint(.trailing, toView: scrollView, constant: -C.padding[1])
            }
            button.constrain([
                leadingConstraint,
                button.constraint(.centerY, toView: scrollView),
                button.constraint(.width, constant: buttonSize.width),
                button.constraint(.height, constant: buttonSize.height),
                trailingConstraint ])

            previous = button
        }
    }

    @objc private func tapped(sender: ShadowButton) {
        //Disable unselecting a selected button
        //because we have to have at least one currency selected
        if !sender.isSelected {
            sender.isSelected = true
            return
        }
        buttons.forEach {
            if sender != $0 {
                $0.isSelected = false
            }
        }
        didSelectCurrency?(sender.title)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
