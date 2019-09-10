//
//  RetryTimer.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-09-10.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

class RetryTimer {

    var callback: (() -> Void)?
    private var timer: Timer?
    private var fibA: TimeInterval = 0.0
    private var fibB: TimeInterval = 1.0

    func start() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(retry), userInfo: nil, repeats: false)
    }

    func stop() {
        timer?.invalidate()
    }

    @objc private func retry() {
        callback?()
        timer?.invalidate()
        let newInterval = fibA + fibB
        fibA = fibB
        fibB = newInterval
        timer = Timer.scheduledTimer(timeInterval: newInterval, target: self, selector: #selector(retry), userInfo: nil, repeats: false)
    }

}
