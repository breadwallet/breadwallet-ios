//
//  FeeManager.swift
//  litewallet
//
//  Created by Kerry Washington on 2/29/20.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.

import Foundation
import UIKit
import FirebaseAnalytics
 
// this is the default that matches the mobile-api if the server is unavailable
fileprivate let defaultEconomyFeePerKB: UInt64 = 2500 // From legacy minimum. default min is 1000 as on
fileprivate let defaultRegularFeePerKB: UInt64 = 25000
fileprivate let defaultLuxuryFeePerKB: UInt64 = 66746
fileprivate let defaultTimestamp: UInt64 = 1583015199122

struct Fees {
    let luxury: UInt64
    let regular: UInt64
    let economy: UInt64
    let timestamp: UInt64
    
    static var defaultFees: Fees {
        return Fees(luxury: defaultLuxuryFeePerKB, regular: defaultRegularFeePerKB, economy: defaultRegularFeePerKB, timestamp: defaultTimestamp)
    }
}

enum FeeType {
    case regular
    case economy
    case luxury
}

class FeeUpdater : Trackable {
    
    //MARK: - Private
    private let walletManager: WalletManager
    private let store: Store
    private let feeKey = "FEE_PER_KB"
    private let txFeePerKb: UInt64 = 1000
    private lazy var minFeePerKB: UInt64 = {
        return Fees.defaultFees.economy
    }()
    private let maxFeePerKB = Fees.defaultFees.luxury
    private var timer: Timer?
    private let feeUpdateInterval: TimeInterval = 15
    
    //MARK: - Public
    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
    }

    func refresh(completion: @escaping () -> Void) {
        walletManager.apiClient?.feePerKb { newFees, error in
            
            guard error == nil else {
                let properties: [String : String] = ["ERROR_MESSAGE":String(describing: error),"ERROR_TYPE":self.feeKey]
                LWAnalytics.logEventWithParameters(itemName: ._20200112_ERR, properties: properties)
                completion();
                return
            }
            
            guard newFees.luxury < self.maxFeePerKB && newFees.economy > self.minFeePerKB else {
                LWAnalytics.logEventWithParameters(itemName: ._20200301_DUDFPK)
                self.saveEvent("wallet.didUseDefaultFeePerKB")
                return
            }
            self.store.perform(action: UpdateFees.set(newFees))
            completion()
        }

        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: feeUpdateInterval, target: self, selector: #selector(intervalRefresh), userInfo: nil, repeats: true)
        }
    }

    func refresh() {
        refresh(completion: {})
    }

    @objc func intervalRefresh() {
        refresh(completion: {})
    }
}

class FeeSelector : UIView {

    init(store: Store) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
    }

    var didUpdateFee: ((FeeType) -> Void)?

    func removeIntrinsicSize() {
        guard let bottomConstraint = bottomConstraint else { return }
        NSLayoutConstraint.deactivate([bottomConstraint])
    }

    func addIntrinsicSize() {
        guard let bottomConstraint = bottomConstraint else { return }
        NSLayoutConstraint.activate([bottomConstraint])
    }

    private let store: Store
    private let header = UILabel(font: .customMedium(size: 16.0), color: .darkText)
    private let subheader = UILabel(font: .customBody(size: 14.0), color: .grayTextTint)
    private let feeMessageLabel = UILabel.wrapping(font: .customBody(size: 14.0), color: .red)
    private let control = UISegmentedControl(items: [S.FeeSelector.regular, S.FeeSelector.economy, S.FeeSelector.luxury])
    private var bottomConstraint: NSLayoutConstraint?

    private func setupViews() {
        addSubview(control)
        addSubview(header)
        addSubview(subheader)
        addSubview(feeMessageLabel)
        
        control.tintColor = .liteWalletBlue
        
        

        header.constrain([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1]) ])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subheader.topAnchor.constraint(equalTo: header.bottomAnchor) ])

        bottomConstraint = feeMessageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])
        feeMessageLabel.constrain([
            feeMessageLabel.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            feeMessageLabel.topAnchor.constraint(equalTo: control.bottomAnchor, constant: 4.0),
            feeMessageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        header.text = S.FeeSelector.title
        subheader.text = S.FeeSelector.regularLabel
        control.constrain([
            control.leadingAnchor.constraint(equalTo: feeMessageLabel.leadingAnchor),
            control.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: 4.0),
            control.widthAnchor.constraint(equalTo: widthAnchor, constant: -C.padding[4]) ])

        control.valueChanged = strongify(self) { myself in
            
            switch myself.control.selectedSegmentIndex {
            case 0:
                myself.didUpdateFee?(.regular)
                myself.subheader.text = S.FeeSelector.regularLabel
                myself.feeMessageLabel.text = ""
            case 1:
                myself.didUpdateFee?(.economy)
                myself.subheader.text = S.FeeSelector.economyLabel
                myself.feeMessageLabel.text = S.FeeSelector.economyWarning
                myself.feeMessageLabel.textColor = .red
            case 2:
                myself.didUpdateFee?(.luxury)
                myself.subheader.text = S.FeeSelector.luxuryLabel
                myself.feeMessageLabel.text = S.FeeSelector.luxuryMessage
                myself.feeMessageLabel.textColor = .grayTextTint
            default:
                myself.didUpdateFee?(.regular)
                myself.subheader.text = S.FeeSelector.regularLabel
                myself.feeMessageLabel.text = ""
            }
        }

        control.selectedSegmentIndex = 0
        clipsToBounds = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
