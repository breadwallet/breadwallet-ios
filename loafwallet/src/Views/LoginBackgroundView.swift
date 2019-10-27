//
//  LoginBackgroundView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LoginBackgroundView : UIView {

    init() {
        super.init(frame: .zero)
    }

    private var hasSetup = false

    override func layoutSubviews() {
        guard !hasSetup else { return }
        self.backgroundColor = .liteWalletBlue
    }
 
    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
