// 
//  AnimatedBlockSetLogo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-09-08.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class AnimatedBlockSetLogo: UIView {
    
    private let imageView = UIImageView()
    private let containers: [UIView] = (0...3).map { _ in UIView() }
    private let containerSize = CGSize(width: 22.0, height: 175.0)
    
    var isOn: Bool = false {
        didSet {
            isOn ? showDots() : hideDots()
        }
    }
    
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubviews()
        addConstraints()
        bindData()
    }
    
    private func addSubviews() {
        addSubview(imageView)
    }
    
    private func addConstraints() {
        imageView.constrain(toSuperviewEdges: nil)
        containers.forEach {
            addSubview($0)
            $0.pin(toSize: containerSize)
            $0.constrain([
                $0.topAnchor.constraint(equalTo: imageView.topAnchor, constant: -100.0),
                $0.centerXAnchor.constraint(equalTo: imageView.centerXAnchor)])
        }
        
        //Rotate each container so that it fits over the blockset logo image
        //in the right direction
        containers[0].transform = CGAffineTransform(rotationAngle: deg2rad(-60.0))
            .concatenating(CGAffineTransform(translationX: -142.0, y: 59.0))
        containers[1].transform = CGAffineTransform(rotationAngle: deg2rad(-120.0))
            .concatenating(CGAffineTransform(translationX: -150, y: 227))
        containers[2].transform = CGAffineTransform(rotationAngle: deg2rad(60.0))
            .concatenating(CGAffineTransform(translationX: 148, y: 55.0))
    }
    
    private func bindData() {
        imageView.image = UIImage(named: "blockset")
    }
    
    func showDots() {
        if containers.first?.subviews.isEmpty == true {
            containers.forEach {
                $0.alpha = 1.0 //alpha might have been set to 0 if they were previously hidden
                self.addDotsTo($0)
            }
        } else {
            containers.forEach { container in
                UIView.animate(withDuration: 2.0, animations: {
                    container.alpha = 1.0
                }, completion: { _ in })
            }
        }
    }
    
    func hideDots() {
        containers.forEach { container in
            UIView.animate(withDuration: 2.0, animations: {
                container.alpha = 0.0
            }, completion: { _ in })
        }
    }
    
    func addDotsTo(_ view: UIView) {
        (0...4).forEach { _ in
            let dot = Dot()
            dot.addTo(view)
            DispatchQueue.main.async {
                dot.animate(withDelay: TimeInterval(CGFloat.random(min: 0, max: 4.0)))
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private func deg2rad(_ number: CGFloat) -> CGFloat {
    return number * .pi / 180
}
