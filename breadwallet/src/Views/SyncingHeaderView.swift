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
    private let syncIndicator = SyncingIndicator(style: .account)
    private let date = UILabel(font: Theme.body2, color: UIColor(red: 0.08, green: 0.07, blue: 0.2, alpha: 0.4))
    private let separator = UIView(color: UIColor.fromHex("#EFEFF2"))
    private let lineLoadingView = LineLoadingView(style: .sync)
    private let currency: Currency
    private var syncState: SyncState = .success {
        didSet {
            updateText()
            syncIndicator.syncState = syncState
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
        
        // For languages such as German, the date string can be long and can overlap the sync'ing indicator.
        date.minimumScaleFactor = 0.75
        date.adjustsFontSizeToFitWidth = true
    }

    private func addSubviews() {
        addSubview(date)
        addSubview(syncIndicator)
        addSubview(separator)
        addSubview(lineLoadingView)
    }

    private func addConstraints() {
        syncIndicator.constrain([
            syncIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[1]),
            syncIndicator.topAnchor.constraint(equalTo: topAnchor),
            syncIndicator.bottomAnchor.constraint(equalTo: bottomAnchor)])
        date.constrain([
            date.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[1]),
            date.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1]),
            date.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1]),
            date.trailingAnchor.constraint(equalTo: syncIndicator.leadingAnchor, constant: -C.padding[1])])
        separator.constrainBottomCorners(height: 1.0)
        lineLoadingView.constrain([
            lineLoadingView.heightAnchor.constraint(equalTo: separator.heightAnchor),
            lineLoadingView.centerXAnchor.constraint(equalTo: separator.centerXAnchor),
            lineLoadingView.centerYAnchor.constraint(equalTo: separator.centerYAnchor),
            lineLoadingView.widthAnchor.constraint(equalTo: separator.widthAnchor)])
    }
    
    private func setInitialState() {
        backgroundColor = .white
        
        Store.subscribe(self,
                        selector: { [weak self] oldState, newState in
                            guard let `self` = self else { return false }
                            return oldState[self.currency]?.syncState != newState[self.currency]?.syncState },
                        callback: { [weak self] state in
                            guard let `self` = self,
                                let syncState = state[self.currency]?.syncState else { return }
                            self.syncState = syncState
        })
        
        Store.subscribe(self,
                        selector: { [weak self] oldState, newState in
                            guard let `self` = self else { return false }
                            return oldState[self.currency]?.syncProgress != newState[self.currency]?.syncProgress ||
                                oldState[self.currency]?.lastBlockTimestamp != newState[self.currency]?.lastBlockTimestamp
            },
                        callback: { [weak self] state in
                            guard let `self` = self else { return }
                            self.lastBlockTimestamp = state[self.currency]?.lastBlockTimestamp ?? 0
                            if let progress = state[self.currency]?.syncProgress {
                                self.syncIndicator.progress = progress
                            }
        })
    }

    private func updateText() {
        switch syncState {
        case .connecting:
            date.text = S.SyncingView.connecting
            lineLoadingView.isHidden = false
            syncIndicator.isHidden = false
        case .syncing:
            lineLoadingView.isHidden = false
            syncIndicator.isHidden = false
            if lastBlockTimestamp == 0 {
                self.date.text = ""
            } else {
                let date = Date(timeIntervalSince1970: Double(self.lastBlockTimestamp))
                let dateString = DateFormatter.mediumDateFormatter.string(from: date)
                self.date.text = String(format: S.SyncingView.syncedThrough, dateString)
            }
        case .success:
            date.text = S.SyncingView.activity
            lineLoadingView.isHidden = true
            syncIndicator.isHidden = true
        case .failed:
            date.text = ""
            lineLoadingView.isHidden = true
            syncIndicator.isHidden = false
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
