//
//  String+Keys.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-14.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

extension String {
    var isValidPrivateKey: Bool {
        return BRPrivKeyIsValid(self) != 0
    }

    var isValidBip38Key: Bool {
        return BRBIP38KeyIsValid(self) != 0
    }
}
