//
//  SyncingIndicator.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-02-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum SyncingIndicatorStyle {
    case home
    case account
}

/// Small syncing progress indicator
class SyncingIndicator: UIView {
    
    // MARK: Vars
    private let style: SyncingIndicatorStyle
    private let label = UILabel()

    var progress: Float = 0.0 {
        didSet {
            updateTextLabel()
        }
    }

    var syncState: SyncState = .success {
        didSet {
            switch syncState {
            case .connecting:
                switch style {
                case .home:
                    self.text = S.SyncingView.connecting
                case .account:
                    self.text = ""
                }
                setNeedsLayout()
            case .syncing:
                self.text = S.SyncingView.syncing
                setNeedsLayout()
            case .success:
                self.text = ""
            case .failed:
                self.text = S.SyncingView.failed
            }
        }
    }

    private var text: String = S.SyncingView.syncing {
        didSet {
            updateTextLabel()
        }
    }
    
    private lazy var syncProgressNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    // MARK: Init
    
    init(style: SyncingIndicatorStyle) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubview(label)
        setupConstraints()
        
        label.font = (style == .home) ? .customBold(size:12.0) : .customBody(size: 14.0)
        label.textColor = (style == .home) ? .transparentWhiteText : UIColor(red: 0.08, green: 0.07, blue: 0.2, alpha: 0.4)
        label.textAlignment = .right
        label.text = text
    }
    
    private func setupConstraints() {
        label.constrain([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor)]
        )
    }

    private func updateTextLabel() {
        guard progress > 0.0 else {
            label.text = text
            return
        }
        
        if syncState == .syncing, let percent = syncProgressNumberFormatter.string(from: NSNumber(value: progress)) {
            label.text = "\(text) \(percent)"
        } else {
            label.text = text
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
