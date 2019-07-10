//
//  UnEditableTextView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class UnEditableTextView: UITextView {
    override var canBecomeFirstResponder: Bool {
        return false
    }
}
