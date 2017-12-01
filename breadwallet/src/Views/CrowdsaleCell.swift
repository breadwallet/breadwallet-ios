//
//  CrowdsaleCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-30.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class CrowsaleCell : UITableViewCell {

    private let currencyName = UILabel(font: .customBody(size: 16.0), color: .white)
    private let balance = UILabel(font: .customBody(size: 16.0), color: .white)
    private let price = UILabel(font: .customBody(size: 14.0), color: .white)
    private let container = Background()
    private let status = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var endTime: Date? = nil

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func setData(currencyName: String, price: String, balance: String, store: Store) {
        self.currencyName.text = currencyName
        self.price.text = price
        self.balance.text = balance
        self.container.store = store
        self.container.setNeedsDisplay()

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
        self.status.text = "Crowdsale starts in \(diff.day!)d \(diff.hour!)h \(diff.minute!)m \(diff.second!)s"
    }

    @objc private func setLiveStatusLabel() {
        guard let endTime = endTime else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: endTime)
        status.text = "Crowdsale is live now\nEnds in \(diff.day!)d \(diff.hour!)h \(diff.minute!)m \(diff.second!)s"
    }

    private func setFinishedStatusLabel() {
        status.text = ""
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }

    private func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(currencyName)
        container.addSubview(price)
        container.addSubview(balance)
        container.addSubview(status)
    }

    private func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1], left: C.padding[2], bottom: -C.padding[1], right: -C.padding[2]))
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            currencyName.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]) ])
        price.constrain([
            price.leadingAnchor.constraint(equalTo: currencyName.leadingAnchor),
            price.topAnchor.constraint(equalTo: currencyName.bottomAnchor, constant: C.padding[2])])
        balance.constrain([
            balance.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            balance.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])])
        status.constrain([
            status.leadingAnchor.constraint(equalTo: price.leadingAnchor),
            status.topAnchor.constraint(equalTo: price.bottomAnchor, constant: C.padding[2]),
            status.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            status.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])])
    }

    private func setupStyle() {
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
