//
//  CrowdsaleView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class CrowdsaleView : UIView {

    private let header = UILabel.wrapping(font: .customBody(size: 16.0))
    private let button = ShadowButton(title: "Buy Tokens", type: .primary)
    private let footer = UILabel.wrapping(font: .customBody(size: 16.0))
    private let store: Store
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var endTime: Date? = nil

    init(store: Store) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        addSubview(header)
        addSubview(button)
        addSubview(footer)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[2])
        button.constrain([
            button.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            button.centerXAnchor.constraint(equalTo: centerXAnchor)])
        footer.constrain([
            footer.topAnchor.constraint(equalTo: button.bottomAnchor, constant: C.padding[2]) ])
        footer.constrainBottomCorners(sidePadding: C.padding[2], bottomPadding: C.padding[2])
    }

    private func setInitialData() {
        header.textAlignment = .center
        footer.textAlignment = .center
        button.tap = strongify(self) { myself in
            myself.store.perform(action: RootModalActions.Present(modal: .send))
        }
        if let startTime = store.state.walletState.crowdsale?.startTime, let endTime = store.state.walletState.crowdsale?.endTime {
            self.startTime = startTime
            self.endTime = endTime
            let now = Date()
            if now < startTime {
                setPreLiveStatusLabel()
                if timer == nil {
                    timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(setPreLiveStatusLabel), userInfo: nil, repeats: true)
                }
            } else if now > startTime && now < endTime {
                setLiveStatusLabel()
                if timer == nil {
                    timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(setLiveStatusLabel), userInfo: nil, repeats: true)
                }
            } else if now > endTime {
                setFinishedStatusLabel()
            }
        }
    }

    @objc private func setPreLiveStatusLabel() {
        guard let startTime = startTime else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: startTime)
        header.text = "Crowdsale is now live"
        footer.text = "Crowdsale starts in \(diff.day!)d \(diff.hour!)h \(diff.minute!)m \(diff.second!)s"
    }

    @objc private func setLiveStatusLabel() {
        guard let endTime = endTime else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: endTime)
        header.text = "Crowdsale is now live"
        footer.text = "Ends in \(diff.day!)d \(diff.hour!)h \(diff.minute!)m \(diff.second!)s"
    }

    private func setFinishedStatusLabel() {
        header.text = "Crowdsale is Finished"
        footer.text = ""
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
