//
//  UIView+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIView {

    func constrain(toSuperviewEdges: UIEdgeInsets?) {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints") }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
                NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: toSuperviewEdges?.left ?? 0.0),
                NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: toSuperviewEdges?.top ?? 0.0),
                NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: toSuperviewEdges?.right ?? 0.0),
                NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: toSuperviewEdges?.bottom ?? 0.0)
            ])
    }

    func constrain(_ constraints: [NSLayoutConstraint]) {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints") }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
    }

    func constraint(_ attribute: NSLayoutAttribute, toView: UIView, constant: CGFloat?) -> NSLayoutConstraint {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints") }
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: toView, attribute: attribute, multiplier: 1.0, constant: constant ?? 0.0)
    }

}
