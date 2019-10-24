//
//  ModalDisplayable.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

protocol ModalDisplayable {
    var modalTitle: String { get }
    var faqArticleId: String? { get }
    var faqCurrency: Currency? { get }
}

protocol ModalPresentable {
    var parentView: UIView? { get set }
}
