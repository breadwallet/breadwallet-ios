//
//  CurrencySlider.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-18.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let buttonSize = CGSize(width: 80.0, height: 32.0)

class CurrencySlider : UIView {

    init(rates: [Rate]) {
        self.rates = rates
        super.init(frame: .zero)
        setupViews()
    }

    var didSelectCurrency: ((Rate) -> Void)?

    private let rates: [Rate]
    private var buttons = [ShadowButton]()

    private func setupViews() {
        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.constrain(toSuperviewEdges: nil)

        var previous: ShadowButton?
        rates.forEach { rate in
            let button = ShadowButton(title: "\(rate.code) (\(rate.currencySymbol))", type: .tertiary)
            button.isToggleable = true
            buttons.append(button)

            if rate.currencySymbol == "BTC" {
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
            if rates.last == rate {
                trailingConstraint = button.constraint(.trailing, toView: scrollView, constant: -C.padding[1])
            }
            button.constrain([
                leadingConstraint,
                button.constraint(.centerY, toView: scrollView),
                button.constraint(.width, constant: buttonSize.width),
                button.constraint(.height, constant: buttonSize.height),
                trailingConstraint ])

            previous = button


            button.tap = {
                //Disable unselecting a selected button
                //because we have to have at least one currency selected
                if !button.isSelected {
                    button.isSelected = true
                    return
                }
                self.buttons.forEach {
                    if button != $0 {
                        $0.isSelected = false
                    }
                }
                self.didSelectCurrency?(rate)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
