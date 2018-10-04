//
//  LoginBackgroundView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LoginBackgroundView : UIView, GradientDrawable {

    init() {
        super.init(frame: .zero)
    }

    private var hasSetup = false

    override func layoutSubviews() {
        guard !hasSetup else { return }
        setupTriangles()
    }

    private func setupTriangles() {
        guard !E.isIPhone4 && !E.isIPhone5 else { return }
        let top = LoginBackgroundTriangle(vertexLocation: 0.0)
        let bottom = LoginBackgroundTriangle(vertexLocation: 70.0/418.0)
        let topHeightMultiplier: CGFloat = 148.0/568.0
        addSubview(top)
        addSubview(bottom)
        top.constrain([
            top.leadingAnchor.constraint(equalTo: leadingAnchor),
            top.topAnchor.constraint(equalTo: topAnchor),
            top.trailingAnchor.constraint(equalTo: trailingAnchor),
            top.heightAnchor.constraint(equalTo: heightAnchor, multiplier: topHeightMultiplier) ])
        bottom.constrain([
            bottom.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottom.topAnchor.constraint(equalTo: top.bottomAnchor),
            bottom.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: bottomAnchor) ])
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
