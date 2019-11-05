//
//  HistoryPeriodButton.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-07-04.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

class HistoryPeriodButton {
    
    private let historyPeriod: HistoryPeriod
    let button: UIButton
    var callback: ((UIButton, HistoryPeriod) -> Void)? {
        didSet {
            button.tap = {
                self.callback?(self.button, self.historyPeriod)
                self.historyPeriod.saveMostRecent()
            }
        }
    }
    
    var hasInitialHistoryPeriod: Bool {
        return historyPeriod == HistoryPeriod.defaultPeriod
    }
    
    init(historyPeriod: HistoryPeriod) {
        self.historyPeriod = historyPeriod
        self.button = UIButton(type: .system)
        button.setTitle(historyPeriod.buttonLabel, for: .normal)
        let color = historyPeriod == HistoryPeriod.defaultPeriod ? Theme.primaryText : Theme.tertiaryText
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = Theme.body1
    }
    
}
