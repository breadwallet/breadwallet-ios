//
//  LoginBackgroundTriangle.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-19.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LoginBackgroundTriangle : UIView {

    //MARK: - Public
    init(vertexLocation: CGFloat) {
        self.vertexLocation = vertexLocation
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    //MARK: - Private
    private let vertexLocation: CGFloat //A percentage value (0.0->1.0) of the right vertex's vertical location

    override func layoutSubviews() {
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: 0, y: 0))
        bezierPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.height*vertexLocation))
        bezierPath.addLine(to: CGPoint(x: 0, y: bounds.maxY))
        bezierPath.close()

        layer.shadowPath = bezierPath.cgPath
        layer.shadowColor = UIColor(white: 0.0, alpha: 0.15).cgColor
        layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        layer.shadowRadius = 4.0
        layer.shadowOpacity = 1.0
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: rect.maxX, y: bounds.height*vertexLocation))
        context.addLine(to: CGPoint(x: 0, y: rect.maxY))
        context.closePath()
        context.clip()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.gradientStart.cgColor, UIColor.gradientEnd.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: rect.width, y: 0.0), options: [])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
