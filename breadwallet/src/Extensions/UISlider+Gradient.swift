//
//  UISlider+Gradient.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-28.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UISlider {
    func addGradientTrack() {
        superview?.layoutIfNeeded()
        setMaximumTrackImage(imageForColors(colors: [UIColor.grayTextTint.cgColor, UIColor.grayTextTint.cgColor], offset: 4.0), for: .normal)
        setMinimumTrackImage(imageForColors(colors: [UIColor.gradientStart.cgColor, UIColor.gradientEnd.cgColor]), for: .normal)
    }

    private func imageForColors(colors: [CGColor], offset: CGFloat = 0.0) -> UIImage? {
        let layer = CAGradientLayer()
        layer.cornerRadius = bounds.height/2.0
        layer.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width - offset, height: bounds.height)
        layer.colors = colors
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.startPoint = CGPoint(x: 0.0, y: 1.0)

        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, 0.0)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let layerImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return layerImage?.resizableImage(withCapInsets: .zero)
    }
}
