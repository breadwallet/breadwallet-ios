//
//  CGContext+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-13.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension CGContext {
    func addLineThrough(_ points: [(CGFloat, CGFloat)]) {
        guard let first = points.first else { return }
        move(to: CGPoint(x: first.0, y: first.1))
        points.dropFirst().forEach {
            addLine(to: CGPoint(x: $0.0, y: $0.1))
        }
    }
}
