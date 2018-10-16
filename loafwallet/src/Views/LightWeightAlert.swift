//
//  LightWeightAlert.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LightWeightAlert : UIView {

    init(message: String) {
        super.init(frame: .zero)
        self.label.text = message
        setup()
    }

    let effect = UIBlurEffect(style: .dark)
    let background = UIVisualEffectView()
    let container = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark)))
    private let label = UILabel(font: .customBold(size: 16.0))

    private func setup() {
        addSubview(background)
        background.constrain(toSuperviewEdges: nil)
        background.contentView.addSubview(container)
        container.contentView.addSubview(label)
        container.constrain(toSuperviewEdges: nil)
        label.constrain(toSuperviewEdges: UIEdgeInsetsMake(C.padding[2], C.padding[2], -C.padding[2], -C.padding[2]))
        layer.cornerRadius = 4.0
        layer.masksToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
