// 
//  ExtendedTouchArea.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-09-09.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class ExtendedTouchArea: UIView {
    
    var delegateView: UIView?
    var ignoringView: UIView?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard ignoringView?.point(inside: convert(point, to: ignoringView), with: event) == false else { return nil }
        return self.point(inside: point, with: event) ? delegateView : nil
    }
    
}
