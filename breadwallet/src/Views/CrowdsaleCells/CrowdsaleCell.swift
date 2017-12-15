//
//  CrowdsaleCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-14.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class CrowdsaleCell : UITableViewCell {

    var shouldRetry: (() -> Void)?
    var shouldResumeIdentityVerification: (() -> Void)?
    var shouldPresentLegal: (() -> Void)?
    private let header = UILabel.wrapping(font: .customBody(size: 16.0))
    private let button = ShadowButton(title: S.Crowdsale.buyButton, type: .primary)
    private let footer = UILabel.wrapping(font: .customBody(size: 16.0))
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var endTime: Date? = nil
    private var kycStatus: KYCStatus?
    private var store: Store?
    private var buttonHeight: NSLayoutConstraint?

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    private func setupViews() {
        selectionStyle = .none
        addSubviews()
        addConstraints()
    }

    private func addSubviews() {
        contentView.addSubview(header)
        contentView.addSubview(button)
        contentView.addSubview(footer)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[2])
        buttonHeight = button.heightAnchor.constraint(equalToConstant: 44.0)
        button.constrain([
            button.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonHeight])
        footer.constrain([
            footer.topAnchor.constraint(equalTo: button.bottomAnchor, constant: C.padding[2]) ])
        footer.constrainBottomCorners(sidePadding: C.padding[2], bottomPadding: C.padding[2])
    }

    func setData(store: Store, status: KYCStatus) {
        self.store = store
        self.kycStatus = status
        if let crowdsale = store.state.walletState.crowdsale {
            if UserDefaults.hasCompletedKYC(forContractAddress: crowdsale.contract.address) {
                kycStatus = .complete
            }
        }
        header.textAlignment = .center
        footer.textAlignment = .center
        button.tap = strongify(self) { myself in
            if myself.kycStatus == .complete {
                if !UserDefaults.hasAgreedToCrowdsaleTerms {
                    myself.shouldPresentLegal?()
                } else {
                    store.perform(action: RootModalActions.Present(modal: .send))
                }
            } else if myself.kycStatus == .failed {
                myself.shouldRetry?()
            } else if myself.kycStatus == .incomplete {
                myself.shouldResumeIdentityVerification?()
            }
        }
        setStatusLabel()
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(setStatusLabel), userInfo: nil, repeats: true)
        }
    }

    @objc private func setStatusLabel() {
        guard let store = store else { return }
        guard let startTime = store.state.walletState.crowdsale?.startTime, let endTime = store.state.walletState.crowdsale?.endTime else { return }
        self.startTime = startTime
        self.endTime = endTime
        let now = Date()
        if now < startTime {
            setPreLiveStatusLabel()
        } else if now > startTime && now < endTime {
            setLiveStatusLabel()
        } else if now > endTime {
            setFinishedStatusLabel()
        }
        if kycStatus == .failed {
            button.title = S.Crowdsale.retry
        } else if kycStatus == .incomplete {
            button.title = S.Crowdsale.resume
        } else {
            button.title = S.Crowdsale.buyButton
        }

        if now > startTime && now < endTime && kycStatus == .complete {
            buttonHeight?.constant = 44.0
        } else if kycStatus == .retry && now < endTime {
            buttonHeight?.constant = 44.0
        } else if kycStatus == .incomplete && now < endTime {
            buttonHeight?.constant = 44.0
        } else {
            buttonHeight?.constant = 0.0
        }
    }

    @objc private func setPreLiveStatusLabel() {
        guard let startTime = startTime else { return }
        guard let kycStatus = kycStatus else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: startTime)
        header.text = "\(kycStatus.description)"
        footer.text = "Crowdsale starts in \(diff.day!)d \(diff.hour!)h \(diff.minute!)m \(diff.second!)s"
    }

    @objc private func setLiveStatusLabel() {
        guard let endTime = endTime else { return }
        guard let kycStatus = kycStatus else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: endTime)
        header.text = "Crowdsale is now live. \(kycStatus.description)"
        footer.text = "Ends in \(diff.day!)d \(diff.hour!)h \(diff.minute!)m \(diff.second!)s"
    }

    private func setFinishedStatusLabel() {
        buttonHeight?.constant = 0.0
        header.text = "Crowdsale is Finished"
        footer.text = ""
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
