//
//  PriceChangeView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-04-01.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

enum PriceChangeViewStyle {
    case percentOnly
    case percentAndAbsolute
}

class PriceChangeView: UIView, Subscriber {
    
    var currency: Currency? = nil {
        didSet {
            subscribeToPriceChange()
        }
    }
    
    private let percentLabel = UILabel(font: Theme.body3)
    private let absoluteLabel = UILabel(font: Theme.body3)
    private let image = UIImageView(image: UIImage(named: "PriceArrow"))
    private let separator = UIView(color: UIColor.white.withAlphaComponent(0.6))
    
    private var priceInfo: FiatPriceInfo? {
        didSet {
            handlePriceChange()
        }
    }
    
    private var currencyNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = Rate.symbolMap[Store.state.defaultCurrencyCode]
        return formatter
    }
    
    private let style: PriceChangeViewStyle
    
    init(style: PriceChangeViewStyle) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubviews()
        setupConstraints()
        setInitialData()
    }
    
    private func setupConstraints() {
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Padding.half),
            separator.topAnchor.constraint(equalTo: topAnchor, constant: 4.0),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4.0),
            separator.widthAnchor.constraint(equalToConstant: 1.0)])
        image.constrain([
            image.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: Padding.half),
            image.centerYAnchor.constraint(equalTo: centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 6.0),
            image.heightAnchor.constraint(equalToConstant: 5.0)])
        percentLabel.constrain([
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentLabel.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 3.0)])
        absoluteLabel.constrain([
            absoluteLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            absoluteLabel.leadingAnchor.constraint(equalTo: percentLabel.trailingAnchor, constant: C.padding[1]/2.0),
            absoluteLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[1])])
        if style == .percentOnly {
            percentLabel.constrain([
                percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4.0)])
        }
    }
    
    private func addSubviews() {
        addSubview(separator)
        addSubview(percentLabel)
        addSubview(image)
        addSubview(absoluteLabel)
    }
    
    private func setInitialData() {
        separator.alpha = 0.0
        image.alpha = 0.0
        percentLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        absoluteLabel.textColor = UIColor.white.withAlphaComponent(0.6)
    }
    
    private func handlePriceChange() {
        guard let priceChange = priceInfo else { return }
        
        //Set label text
        let percentText = String(format: "%.2f%%", fabs(priceChange.changePercentage24Hrs))
        if style == .percentAndAbsolute, let absoluteString = currencyNumberFormatter.string(from: NSNumber(value: abs(priceChange.change24Hrs))) {
            absoluteLabel.text = "(\(absoluteString))"
            percentLabel.text = percentText
            layoutIfNeeded()
        } else if style == .percentOnly {
            percentLabel.fadeToText(percentText)
        }
        
        //Fade separator and image
        self.image.transform = priceChange.changePercentage24Hrs > 0 ? .identity : CGAffineTransform(rotationAngle: .pi)
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.separator.alpha = self.style == .percentAndAbsolute ? 0.0 : 1.0
            self.image.alpha = 1.0
        })
    }
    
    private func subscribeToPriceChange() {
        guard let currency = currency else { return }
        Store.subscribe(self, selector: { $0[currency]?.fiatPriceInfo != $1[currency]?.fiatPriceInfo }, callback: {
            self.priceInfo = $0[currency]?.fiatPriceInfo
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private extension UILabel {
    
    func fadeToText(_ text: String) {
        fadeTransition(C.animationDuration)
        self.text = text
    }
    
    func fadeTransition(_ duration: CFTimeInterval) {
        let animation = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
            CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = .fade
        animation.duration = duration
        layer.add(animation, forKey: animation.type.rawValue)
    }
}
