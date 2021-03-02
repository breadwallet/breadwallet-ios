// 
//  LogoStyleExtension.swift
//  breadwalletWidgetExtension
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

extension LogoStyle {
    
    func isImageStyle() -> Bool {
        return self == .iconNoBackground || self == .iconWithBackground
    }
}
