//
//  TxDetailCollectionViewCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxDetailCollectionViewCell : UICollectionViewCell {

    private let header = ModalHeaderView(title: S.TransactionDetails.title, style: .dark)

    var closeCallback: (() -> Void)? {
        didSet { header.closeCallback = closeCallback }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func set(info: TxDetailInfo) {

    }

    private func setup() {
        addSubViews()
        addConstraints()
        setInitialData()
    }

    private func addSubViews() {
        contentView.addSubview(header)
    }

    private func addConstraints() {
        header.constrainTopCorners(height: C.Sizes.headerHeight)
    }

    private func setInitialData() {

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
