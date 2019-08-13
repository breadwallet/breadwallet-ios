//
//  BezierView.swift
//  breadwallet
//
//  Modified by Adrian Corscadden on 2019-06-01.
//
//  original: https://github.com/Ramshandilya/Bezier

import UIKit
import Foundation

protocol BezierViewDataSource: class {
    var bezierViewDataPoints: [CGPoint] { get }
}

class BezierView: UIView {
   
    private let kStrokeAnimationKey = "StrokeAnimationKey"
    private let kFadeAnimationKey = "FadeAnimationKey"
    
    weak var dataSource: BezierViewDataSource?
    private let lineColor = Theme.primaryText
    private var animates = true
    private var lineLayer = CAShapeLayer()
    private var graphPath: UIBezierPath?
    
    var didFinishAnimation: (() -> Void)?
    
    private var dataPoints: [CGPoint]? {
		return self.dataSource?.bezierViewDataPoints
    }
    
    private let cubicCurveAlgorithm = CubicCurveAlgorithm()
    
    func drawBezierCurve() {
        self.layer.sublayers?.forEach({ (layer: CALayer) -> Void in
            layer.removeFromSuperlayer()
        })
        cubicCurveAlgorithm.reset()
        drawSmoothLines()
        animateLine()
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        
        //Draw gradient
        guard let linePath = graphPath else { return }
        guard let points = dataPoints, !points.isEmpty else { return }
        guard let clippingPath = linePath.copy() as? UIBezierPath else { return }
        clippingPath.addLine(to: CGPoint(x: points[points.count-1].x, y: bounds.height))
        clippingPath.addLine(to: CGPoint(x: points[0].x, y: bounds.height))
        clippingPath.close()
        clippingPath.addClip()
        
        let graphStartPoint = CGPoint(x: 0, y: 0)
        let graphEndPoint = CGPoint(x: 0, y: rect.height)
        
        let colors = [UIColor.white.withAlphaComponent(0.06).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace,
                                  colors: colors as CFArray,
                                  locations: colorLocations)!
        lineColor.setFill()
        lineColor.setStroke()
        let context = UIGraphicsGetCurrentContext()!
        context.drawLinearGradient(gradient, start: graphStartPoint, end: graphEndPoint, options: [])
    }
    
    private func drawSmoothLines() {
        guard let points = dataPoints, !points.isEmpty else { return }
		let controlPoints = cubicCurveAlgorithm.controlPointsFromPoints(dataPoints: points)
        let linePath = UIBezierPath()
		
		for i in 0..<points.count {
			let point = points[i]
			
			if i==0 {
				linePath.move(to: point)
			} else {
				let segment = controlPoints[i-1]
				linePath.addCurve(to: point, controlPoint1: segment.controlPoint1, controlPoint2: segment.controlPoint2)
			}
		}
        graphPath = linePath
        lineLayer = CAShapeLayer()
		lineLayer.path = linePath.cgPath
		lineLayer.fillColor = UIColor.clear.cgColor
		lineLayer.strokeColor = lineColor.cgColor
        lineLayer.lineWidth = 1.0
        
        self.layer.addSublayer(lineLayer)
        
        if animates {
            lineLayer.strokeEnd = 0
        }
    }
    
    func animateLine() {
        let growAnimation = CABasicAnimation(keyPath: "strokeEnd")
        growAnimation.toValue = 1
        growAnimation.beginTime = CACurrentMediaTime()
        growAnimation.duration = 0.4
        growAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        growAnimation.fillMode = CAMediaTimingFillMode.forwards
        growAnimation.isRemovedOnCompletion = false
        growAnimation.delegate = self
        lineLayer.add(growAnimation, forKey: kStrokeAnimationKey)
    }
}

extension BezierView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            didFinishAnimation?()
        }
    }
}
