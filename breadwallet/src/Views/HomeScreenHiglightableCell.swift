//
//  HomeScreenHiglightableCell.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-01.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/**
 *  A home screen wallet cell that has a custom highlight view. 
 */
class HomeScreenHiglightableCell: HomeScreenCell, HighlightableCell {

    static let homeScreenHighlightableCellId = "HighlightableCurrencyCell"

    private lazy var highlightView = HomeScreenCellHighlightView()
    
    override func setupViews() {
        super.setupViews()
        addHighlightView()
        highlightView.setUp()
    }
    
    private func addHighlightView() {
        container.addSubview(highlightView)
        highlightView.constrain([
            highlightView.topAnchor.constraint(equalTo: topAnchor),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor),
            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor)])
    }

    func highlight() {
        highlightView.highlight()
    }
    
    func unhighlight() {
        highlightView.unhighlight()
    }
}
