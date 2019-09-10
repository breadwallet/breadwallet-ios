//
//  UpdatingLabel.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-15.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class UpdatingLabel: UILabel {

    var formatter: NumberFormatter {
        didSet {
            setFormattedText(forValue: value)
        }
    }

    init(formatter: NumberFormatter) {
        self.formatter = formatter
        super.init(frame: .zero)
        text = self.formatter.string(from: 0 as NSNumber)
    }

    var completion: (() -> Void)?
    private var value: Decimal = 0.0

    func setValue(_ value: Decimal) {
        self.value = value
        setFormattedText(forValue: value)
    }

    func setValueAnimated(_ endingValue: Decimal, completion: @escaping () -> Void) {
        self.completion = completion
        guard let currentText = text else { return }
        guard let startingValue = formatter.number(from: currentText)?.decimalValue else { return }
        self.startingValue = startingValue
        self.endingValue = endingValue

        timer?.invalidate()
        lastUpdate = CACurrentMediaTime()
        progress = 0.0

        startTimer()
    }

    private let duration = 0.6
    private var easingRate: Double = 3.0
    private var timer: CADisplayLink?
    private var startingValue: Decimal = 0.0
    private var endingValue: Decimal = 0.0
    private var progress: Double = 0.0
    private var lastUpdate: CFTimeInterval = 0.0

    private func startTimer() {
        timer = CADisplayLink(target: self, selector: #selector(UpdatingLabel.update))
        timer?.preferredFramesPerSecond = 30
        timer?.add(to: .main, forMode: RunLoop.Mode.default)
        timer?.add(to: .main, forMode: RunLoop.Mode.tracking)
    }

    @objc private func update() {
        let now = CACurrentMediaTime()
        progress += (now - lastUpdate)
        lastUpdate = now
        if progress >= duration {
            timer?.invalidate()
            timer = nil
            setFormattedText(forValue: endingValue)
            completion?()
        } else {
            let percentProgress = progress/duration
            let easedVal = 1.0-pow((1.0-percentProgress), easingRate)
            setFormattedText(forValue: startingValue + (Decimal(easedVal) * (endingValue - startingValue)))
        }
    }

    private func setFormattedText(forValue: Decimal) {
        value = forValue
        text = formatter.string(from: value as NSDecimalNumber)
        sizeToFit()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
