//
//  SyncingHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-05-29.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class SyncingHeaderView: UIView, Subscriber {

    static let height: CGFloat = 40.0
    let syncIndicator = SyncingIndicator(style: .account)
    private let date = UILabel(font: .customBody(size: 12.0), color: .lightText)
    private let currency: Currency
    private var syncState: SyncState = .success {
        didSet {
            updateText()
        }
    }
    private var lastBlockTimestamp: UInt32 = 0 {
        didSet {
            updateText()
        }
    }
    init(currency: Currency) {
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

        Store.subscribe(self, selector: { $0[self.currency]?.syncState != $1[self.currency]?.syncState },
                        callback: { state in
                            guard let syncState = state[self.currency]?.syncState else { return }
                            self.syncState = syncState
        })

        Store.subscribe(self, selector: {
            return $0[self.currency]?.lastBlockTimestamp != $1[self.currency]?.lastBlockTimestamp
        }, callback: {
            self.lastBlockTimestamp = $0[self.currency]?.lastBlockTimestamp ?? 0
        })
    }

    private func updateText() {
        switch syncState {
        case .connecting:
            self.date.text = S.SyncingView.connecting
        case .syncing:
            if lastBlockTimestamp == 0 {
                self.date.text = ""
            } else {
                let date = Date(timeIntervalSince1970: Double(self.lastBlockTimestamp))
                let dateString = DateFormatter.mediumDateFormatter.string(from: date)
                self.date.text = String(format: S.SyncingView.syncedThrough, dateString)
            }
        case .success:
            self.date.text = ""
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
