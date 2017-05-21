//
//  CurrencySlider.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-18.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let popularCodes = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CNY", "CHF", "SEK", "NZD", "KRW"]
private let buttonHeight: CGFloat = 32.0

class CurrencySlider : UIView {

    init(rates: [Rate], defaultCode: String, isBtcSwapped: Bool) {

        var tempRates: [Rate] = []
        if isBtcSwapped {
            tempRates = rates.filter({ $0.code == defaultCode })
            tempRates += rates.filter({ $0.code == C.btcCurrencyCode })
        } else {
            tempRates = rates.filter({ $0.code == C.btcCurrencyCode })
            tempRates += rates.filter({ $0.code == defaultCode })
        }
        //At this stage, the rates array looks like [USD, BTC] or [BTC, USD]
        //We now need to add the remaining unique popular codes
        tempRates += rates.filter({ popularCodes.contains($0.code) && $0.code != defaultCode })
        self.rates = tempRates
        self.defaultCode = defaultCode
        self.isBtcSwapped = isBtcSwapped
        
        super.init(frame: .zero)
    }

    func load() {
        setupViews()
    }

    var didSelectCurrency: ((Rate) -> Void)?

    private let rates: [Rate]
    private var buttons = [ShadowButton]()
    private let defaultCode: String
    private let isBtcSwapped: Bool

    private func setupViews() {
        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.constrain(toSuperviewEdges: nil)

        var previous: ShadowButton?
        rates.forEach { rate in
            let button = ShadowButton(title: "\(rate.code) (\(rate.currencySymbol))", type: .tertiary)
            button.isToggleable = true
            buttons.append(button)

            if isBtcSwapped {
                if rate.code == defaultCode {
                    button.isSelected = true
                }
            } else {
                if rate.code == C.btcCurrencyCode {
                    button.isSelected = true
                }
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
                button.constraint(.height, constant: buttonHeight),
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
