//
//  CrowdsaleCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-30.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class CrowsaleHomeCell : UITableViewCell {

    private let currencyName = UILabel(font: .customBody(size: 16.0), color: .white)
    private let balance = UILabel(font: .customBody(size: 16.0), color: .white)
    private let price = UILabel(font: .customBody(size: 14.0), color: .white)
    private let container = Background()
    private let status = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var endTime: Date? = nil
    private var store: Store? = nil

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
        self.store = store
        setStatusLabel()
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(setStatusLabel), userInfo: nil, repeats: true)
        }
    }

    @objc private func setStatusLabel() {
        if let isSoldOut = store?.state.walletState.crowdsale?.isSoldOut, isSoldOut == true {
            self.status.text = "Sold Out!"
        } else if let startTime = store?.state.walletState.crowdsale?.startTime, let endTime = store?.state.walletState.crowdsale?.endTime {
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
        }
    }

    private func setPreLiveStatusLabel() {
        guard let startTime = startTime else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: startTime)
        guard let day = diff.day, let hour = diff.hour, let minute = diff.minute, let second = diff.second else { return }
        if day > 0 {
            self.status.text = "Crowdsale starts in \(day)d \(hour)h \(minute)m \(second)s"
        } else if hour > 0 {
            self.status.text = "Crowdsale starts in \(hour)h \(minute)m \(second)s"
        } else {
            self.status.text = "Crowdsale starts in \(minute)m \(second)s"
        }
    }

    private func setLiveStatusLabel() {
        guard let endTime = endTime else { return }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: endTime)
        guard let day = diff.day, let hour = diff.hour, let minute = diff.minute, let second = diff.second else { return }
        if day > 0 {
            status.text = "Crowdsale is live now\nEnds in \(day)d \(hour)h \(minute)m \(second)s"
        } else if hour > 0 {
            status.text = "Crowdsale is live now\nEnds in \(hour)h \(minute)m \(second)s"
        } else {
            status.text = "Crowdsale is live now\nEnds in \(minute)m \(second)s"
        }
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
