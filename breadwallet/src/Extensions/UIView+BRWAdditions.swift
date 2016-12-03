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
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return}
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
                NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: toSuperviewEdges?.left ?? 0.0),
                NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: toSuperviewEdges?.top ?? 0.0),
                NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: toSuperviewEdges?.right ?? 0.0),
                NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: toSuperviewEdges?.bottom ?? 0.0)
            ])
    }

    func constrain(_ constraints: [NSLayoutConstraint?]) {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints.flatMap{ $0 })
    }

    func constraint(_ attribute: NSLayoutAttribute, toView: UIView, constant: CGFloat?) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil}
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: toView, attribute: attribute, multiplier: 1.0, constant: constant ?? 0.0)
    }

    func constraint(_ attribute: NSLayoutAttribute, toView: UIView) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil}
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: toView, attribute: attribute, multiplier: 1.0, constant: 0.0)
    }

    //TODO - restrict this to width and height attributes
    func constraint(_ attribute: NSLayoutAttribute, constant: CGFloat) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil }
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: constant)
    }

    func constraint(toBottom: UIView, constant: CGFloat) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil }
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: toBottom, attribute: .bottom, multiplier: 1.0, constant: constant)
    }

    func pinToBottom(to: UIView, height: CGFloat) {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.width, toView: to),
                constraint(toBottom: to, constant: 0.0),
                constraint(.height, constant: height)
            ])
    }

    func constraint(toTop: UIView, constant: CGFloat) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil }
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: toTop, attribute: .top , multiplier: 1.0, constant: constant)
    }

    func constraint(toTrailing: UIView, constant: CGFloat) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil }
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: toTrailing, attribute: .trailing , multiplier: 1.0, constant: constant)
    }

    func constraint(toLeading: UIView, constant: CGFloat) -> NSLayoutConstraint? {
        guard superview != nil else { assert(false, "Superview cannot be nil when adding contraints"); return nil }
        translatesAutoresizingMaskIntoConstraints = false
        return NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: toLeading, attribute: .leading , multiplier: 1.0, constant: constant)
    }

    func constrainTopCorners(sidePadding: CGFloat, topPadding: CGFloat, topLayoutGuide: UILayoutSupport) {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.leading, toView: view, constant: sidePadding),
                NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: topPadding),
                constraint(.trailing, toView: view, constant: -sidePadding)
            ])
    }

    func constrainTopCorners(sidePadding: CGFloat, topPadding: CGFloat) {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.leading, toView: view, constant: sidePadding),
                constraint(.top, toView: view, constant: topPadding),
                constraint(.trailing, toView: view, constant: -sidePadding)
            ])
    }

    func constrainTopCorners(height: CGFloat) {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.leading, toView: view),
                constraint(.top, toView: view),
                constraint(.trailing, toView: view),
                constraint(.height, constant: height)
            ])
    }

    func constrainBottomCorners(sidePadding: CGFloat, bottomPadding: CGFloat) {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.leading, toView: view, constant: sidePadding),
                constraint(.bottom, toView: view, constant: -bottomPadding),
                constraint(.trailing, toView: view, constant: -sidePadding)
            ])
    }

    func constrainBottomCorners(height: CGFloat) {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.leading, toView: view),
                constraint(.bottom, toView: view),
                constraint(.trailing, toView: view),
                constraint(.height, constant: height)
            ])
    }

    func constrainLeadingCorners() {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.top, toView: view),
                constraint(.leading, toView: view),
                constraint(.bottom, toView: view),
            ])
    }

    func constrainTrailingCorners() {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
                constraint(.top, toView: view),
                constraint(.trailing, toView: view),
                constraint(.bottom, toView: view)
            ])
    }

    func constrainToCenter() {
        guard let view = superview else { assert(false, "Superview cannot be nil when adding contraints"); return }
        constrain([
            constraint(.centerX, toView: view),
            constraint(.centerY, toView: view)
        ])
    }
}
