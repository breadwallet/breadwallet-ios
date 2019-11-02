//
//  UITableViewController+CustomTitleView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-08.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

protocol CustomTitleView {
    var customTitle: String { get }
    var titleLabel: UILabel { get }
    var navigationItem: UINavigationItem { get }
}

private struct AssociatedKeys {
    static var label = "label"
    static var yPosition = "yPosition"
}

private let restingLabelPosition: CGFloat = 60.0

extension CustomTitleView {

    var label: UILabel {
        get {
             
            var textColor: UIColor
            
            if #available(iOS 11.0, *) {
                textColor = UIColor(named: "labelTextColor")!
                
            } else {
                textColor = .darkText
            }
            
            guard let label = objc_getAssociatedObject(self, &AssociatedKeys.label) as? UILabel else {
                let newLabel = UILabel(font: .customBold(size: 17.0), color: textColor)
                objc_setAssociatedObject(self, &AssociatedKeys.label, newLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return newLabel
            }
            return label
        }
    }

    var yPosition: NSLayoutConstraint? {
        get {
            guard let yPosition = objc_getAssociatedObject(self, &AssociatedKeys.yPosition) as? NSLayoutConstraint else {
                return nil
            }
            return yPosition
        }
        set {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.yPosition, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }


    func addCustomTitle() {
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))

        if #available(iOS 11.0, *) {
            titleView.backgroundColor = UIColor(named: "lfBackgroundColor")
            label.textColor = UIColor(named: "labelTextColor")
       } else {
            titleView.backgroundColor = .clear
            label.textColor = .darkText
       }
        
        titleView.clipsToBounds = true
        label.text = customTitle
        titleView.addSubview(label)
        let newYPosition = label.centerYAnchor.constraint(equalTo: titleView.centerYAnchor)
        newYPosition.constant = restingLabelPosition
        objc_setAssociatedObject(self, &AssociatedKeys.yPosition, newYPosition, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        label.constrain([
            yPosition,
            label.centerXAnchor.constraint(equalTo: titleView.centerXAnchor) ])
        navigationItem.titleView = titleView
    }

    func didScrollForCustomTitle(yOffset: CGFloat) {
        let progress = min(yOffset/restingLabelPosition, 1.0)
        titleLabel.alpha = 1.0 - progress
        yPosition?.constant = restingLabelPosition - (restingLabelPosition*progress)
    }

    func scrollViewWillEndDraggingForCustomTitle(yOffset: CGFloat) {
        let progress = min(yOffset/restingLabelPosition, 1.0)
        if progress > 0.2 {
            UIView.animate(withDuration: 0.3, animations: {
                self.yPosition?.constant = 0.0
                self.titleLabel.alpha = 0.0
                self.titleLabel.superview?.layoutIfNeeded()
            })
        }
    }
}
