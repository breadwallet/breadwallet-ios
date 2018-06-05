//
//  SyncingHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-05-29.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class SyncingHeaderView : UIView, Subscriber {

    static let height: CGFloat = 40.0
    let syncIndicator = SyncingIndicator(style: .account)
    private let date = UILabel(font: .customBody(size: 12.0), color: .lightText)
    private let currency: CurrencyDef

    init(currency: CurrencyDef) {
        self.currency = currency
        super.init(frame: .zero)
        setupViews()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setInitialState()
    }

    private func addSubviews() {
        addSubview(date)
        addSubview(syncIndicator)
    }

    private func addConstraints() {
        date.constrain([
            date.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[1]),
            date.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1]),
            date.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])])
        syncIndicator.constrain([
            syncIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[1]),
            syncIndicator.topAnchor.constraint(equalTo: topAnchor),
            syncIndicator.bottomAnchor.constraint(equalTo: bottomAnchor)])
    }

    private func setInitialState() {
        backgroundColor = .syncingBackground
        Store.subscribe(self, selector: {
            return $0[self.currency]?.lastBlockTimestamp != $1[self.currency]?.lastBlockTimestamp
        }, callback: {
            let date = Date(timeIntervalSince1970: Double($0[self.currency]?.lastBlockTimestamp ?? 0))
            let dateString = DateFormatter.mediumDateFormatter.string(from: date)
            self.date.text = String(format: S.SyncingView.syncedThrough, dateString)
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
