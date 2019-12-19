//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private let largeFontSize: CGFloat = 28.0
private let smallFontSize: CGFloat = 14.0
private let historyPeriodPillAlpha: CGFloat = 0.3

class AccountHeaderView: UIView, GradientDrawable, Subscriber, Trackable {
    
    // MARK: - Views
    private let intrinsicSizeView = UIView()
    private let currencyName = UILabel(font: .customBody(size: 18.0))
    private let exchangeRateLabel = UILabel(font: .customBody(size: 28.0))
    private let modeLabel = UILabel(font: .customBody(size: 12.0), color: .transparentWhiteText) // debug info
    private var delistedTokenView: DelistedTokenView?
    private let chartView: ChartView
    private let priceChangeView = PriceChangeView(style: .percentAndAbsolute)
    private let priceDateLabel = UILabel(font: .customBody(size: 14.0))
    private let balanceSeparator = UIView(color: UIColor.white.withAlphaComponent(0.2))
    private let balanceCell: BalanceCell
    private var graphButtons: [HistoryPeriodButton] = HistoryPeriod.allCases.map { HistoryPeriodButton(historyPeriod: $0) }
    private let graphButtonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = C.padding[1]
        stackView.layoutMargins = UIEdgeInsets(top: 4.0, left: C.padding[2], bottom: 4.0, right: C.padding[2])
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    private let priceInfoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    private let historyPeriodPill: UIView = {
        let view = UIView(color: UIColor.white.withAlphaComponent(0.6))
        view.layer.cornerRadius = 8.0
        view.layer.masksToBounds = true
        view.alpha = historyPeriodPillAlpha
        return view
    }()
    
    // MARK: Constraints
    private var headerHeight: NSLayoutConstraint?
    private var historyPeriodPillX: NSLayoutConstraint?
    private var historyPeriodPillY: NSLayoutConstraint?
    
    // MARK: Properties
    static let headerViewMaxHeight: CGFloat = 375.0
    static let headerViewMinHeight: CGFloat = 160.0
    private let currency: Currency
    private var isChartHidden = false
    private var shouldLockExpandingChart = false
    private var isScrubbing = false
    var setHostContentOffset: ((CGFloat) -> Void)?
    
    // MARK: Init
    
    init(currency: Currency) {
        self.currency = currency
        self.balanceCell = BalanceCell(currency: currency)
        self.chartView = ChartView(currency: currency)
        if currency.isSupported == false {
            self.delistedTokenView = DelistedTokenView(currency: currency)
        }
        super.init(frame: CGRect())
        setup()
    }
    
    // MARK: Setup
    
    private func setup() {
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        addSubview(intrinsicSizeView)
        addSubview(chartView)
        addSubview(currencyName)
        
        addSubview(priceInfoStackView)
        priceInfoStackView.addSubview(historyPeriodPill)
        priceInfoStackView.addArrangedSubview(exchangeRateLabel)
        priceInfoStackView.addArrangedSubview(priceChangeView)
        priceInfoStackView.addArrangedSubview(priceDateLabel)
        addSubview(modeLabel)
        addSubview(graphButtonStackView)
        addSubview(balanceSeparator)
        addSubview(balanceCell)
        if let delistedTokenView = delistedTokenView {
            addSubview(delistedTokenView)
        }
        graphButtons.forEach {
            graphButtonStackView.addArrangedSubview($0.button)
        }
    }
    
    private func addConstraints() {
        headerHeight = intrinsicSizeView.heightAnchor.constraint(equalToConstant: AccountHeaderView.headerViewMaxHeight)
        intrinsicSizeView.constrain(toSuperviewEdges: nil)
        intrinsicSizeView.constrain([headerHeight])
        chartView.constrain([
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chartView.heightAnchor.constraint(equalToConstant: 100.0),
            chartView.bottomAnchor.constraint(equalTo: graphButtonStackView.topAnchor, constant: -C.padding[1])])
        currencyName.constrain([
            currencyName.constraint(.leading, toView: self, constant: C.padding[2]),
            currencyName.constraint(.trailing, toView: self, constant: -C.padding[2]),
            currencyName.constraint(.top, toView: self, constant: E.isIPhoneX ? C.padding[7] : C.padding[5])])
        priceInfoStackView.constrain([
            priceInfoStackView.centerXAnchor.constraint(equalTo: currencyName.centerXAnchor),
            priceInfoStackView.topAnchor.constraint(equalTo: currencyName.bottomAnchor, constant: C.padding[2])])
        modeLabel.constrain([
            modeLabel.centerXAnchor.constraint(equalTo: priceInfoStackView.centerXAnchor),
            modeLabel.topAnchor.constraint(equalTo: priceInfoStackView.bottomAnchor)])
        if let delistedTokenView = delistedTokenView {
            delistedTokenView.constrain([
                delistedTokenView.topAnchor.constraint(equalTo: priceInfoStackView.topAnchor),
                delistedTokenView.bottomAnchor.constraint(equalTo: balanceCell.topAnchor),
                delistedTokenView.widthAnchor.constraint(equalTo: widthAnchor),
                delistedTokenView.leadingAnchor.constraint(equalTo: leadingAnchor)])
        }
        graphButtonStackView.constrain([
            graphButtonStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52.0),
            graphButtonStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52.0),
            graphButtonStackView.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 0),
            graphButtonStackView.bottomAnchor.constraint(equalTo: balanceCell.topAnchor, constant: -C.padding[1]),
            graphButtonStackView.heightAnchor.constraint(equalToConstant: 30.0)])
        graphButtonStackView.clipsToBounds = true
        graphButtonStackView.layer.masksToBounds = true
        balanceSeparator.constrain([
            balanceSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            balanceSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            balanceSeparator.bottomAnchor.constraint(equalTo: balanceCell.topAnchor),
            balanceSeparator.heightAnchor.constraint(equalToConstant: 1.0)])
        balanceCell.constrain([
            balanceCell.leadingAnchor.constraint(equalTo: leadingAnchor),
            balanceCell.trailingAnchor.constraint(equalTo: trailingAnchor),
            balanceCell.bottomAnchor.constraint(equalTo: bottomAnchor),
            balanceCell.heightAnchor.constraint(equalToConstant: 64.0)])
        
        historyPeriodPillX = historyPeriodPill.centerXAnchor.constraint(equalTo: graphButtons[4].button.centerXAnchor)
        historyPeriodPillY = historyPeriodPill.centerYAnchor.constraint(equalTo: graphButtons[4].button.centerYAnchor)
        
        historyPeriodPill.constrain([
            historyPeriodPillX,
            historyPeriodPillY,
            historyPeriodPill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.1),
            historyPeriodPill.heightAnchor.constraint(equalToConstant: 28.0)])
        
    }

    private func setInitialData() {
        currencyName.textColor = .white
        currencyName.textAlignment = .center
        currencyName.text = currency.name
        
        exchangeRateLabel.textColor = Theme.primaryText
        exchangeRateLabel.textAlignment = .center

        modeLabel.isHidden = true

        if (E.isDebug || E.isTestFlight) && !E.isScreenshots {
            var modeName = ""
            if let mode = currency.wallet?.connectionMode {
                modeName = "\(mode)"
            }
            modeLabel.text = "\(modeName) \(E.isTestnet ? "(Testnet)" : "")"
            modeLabel.isHidden = false
        }

        priceChangeView.currency = currency
        priceDateLabel.textColor = Theme.tertiaryText
        priceDateLabel.textAlignment = .center
        priceDateLabel.alpha = 0.0
        
        graphButtons.forEach {
            $0.callback = { [unowned self] button, period in
                self.chartView.historyPeriod = period
                self.didTap(button: button)
            }
        }
        
        if let initiallySelected = graphButtons.first(where: { return $0.hasInitialHistoryPeriod }) {
            self.updateHistoryPeriodPillPosition(button: initiallySelected.button)
        }
                
        Store.subscribe(self,
                        selector: { [weak self] oldState, newState in
                            guard let `self` = self else { return false }
                            return oldState[self.currency]?.currentRate != newState[self.currency]?.currentRate },
                        callback: { [weak self] in
                            guard let `self` = self, let rate = $0[self.currency]?.currentRate, !self.isScrubbing else { return }
                            self.exchangeRateLabel.text = rate.localString(forCurrency: self.currency)
        })
        setGraphViewScrubbingCallbacks()
        chartView.shouldHideChart = { [weak self] in
            guard let `self` = self else { return }
            self.shouldLockExpandingChart = true
            self.collapseHeader()
        }
    }
    
    private func setGraphViewScrubbingCallbacks() {
        chartView.scrubberDidUpdateToValues = { [unowned self] in
            //We can receive a scrubberDidUpdateToValues call after scrubberDidEnd
            //so we need to guard against updating the scrubber labels
            guard self.isScrubbing else { return }
            self.exchangeRateLabel.text = $0
            self.priceDateLabel.text = $1
        }
        chartView.scrubberDidEnd = { [unowned self] in
            self.isScrubbing = false
            UIView.animate(withDuration: C.animationDuration, animations: {
                self.priceChangeView.alpha = 1.0
                self.priceChangeView.isHidden = false
                self.priceDateLabel.alpha = 0.0
            })
            self.exchangeRateLabel.text = Store.state[self.currency]?.currentRate?.localString(forCurrency: self.currency)
        }
        
        chartView.scrubberDidBegin = { [unowned self] in
            self.saveEvent(self.makeEventName([EventContext.wallet.name, self.currency.code, Event.scrubbed.name]))
            self.isScrubbing = true
            UIView.animate(withDuration: C.animationDuration, animations: {
                self.priceChangeView.alpha = 0.0
                self.priceChangeView.isHidden = true
                self.priceDateLabel.alpha = 1.0
            })
        }
    }
    
    // MARK: Stretchy Header
    
    private func showChart() {
        isChartHidden = false
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.chartView.alpha = 1.0
            self.exchangeRateLabel.alpha = 1.0
            self.priceChangeView.alpha = 1.0
            self.graphButtonStackView.alpha = 1.0
            self.historyPeriodPill.alpha = historyPeriodPillAlpha
        })
    }
    
    private func hideChart() {
        isChartHidden = true
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.chartView.alpha = 0.0
            self.exchangeRateLabel.alpha = 0.0
            self.priceChangeView.alpha = 0.0
            self.graphButtonStackView.alpha = 0.0
            self.historyPeriodPill.alpha = 0.0
        })
    }
    
    func setOffset(_ offset: CGFloat) {
        guard delistedTokenView == nil, !shouldLockExpandingChart else { return } //Disable expanding/collapsing header when delistedTokenView is shown
        guard headerHeight?.isActive == true else { return }
        guard let headerHeight = headerHeight else { return }
        let newHeaderViewHeight: CGFloat = headerHeight.constant - offset
        
        if newHeaderViewHeight > AccountHeaderView.headerViewMaxHeight {
            headerHeight.constant = AccountHeaderView.headerViewMaxHeight
        } else if newHeaderViewHeight < AccountHeaderView.headerViewMinHeight {
            headerHeight.constant = AccountHeaderView.headerViewMinHeight
        } else {
            headerHeight.constant = newHeaderViewHeight
            setHostContentOffset?(0)
            if !isChartHidden && newHeaderViewHeight < 300.0 {
                hideChart()
            } else if isChartHidden && newHeaderViewHeight > 305.0 {
                showChart()
            }
        }
    }
    
    func didStopScrolling() {
        guard delistedTokenView == nil, !shouldLockExpandingChart else { return } //Disable expanding/collapsing header when delistedTokenView is shown
        guard headerHeight?.isActive == true else { return }
        guard let currentHeight = headerHeight?.constant else { return }
        let range = AccountHeaderView.headerViewMaxHeight - AccountHeaderView.headerViewMinHeight
        let mid = AccountHeaderView.headerViewMinHeight + (range/2.0)
        if currentHeight > mid {
            expandHeader()
        } else {
            collapseHeader()
        }
    }
    
    private func expandHeader() {
        headerHeight?.constant = AccountHeaderView.headerViewMaxHeight
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.superview?.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.showChart()
        })
    }
    
    //Needs to be public so that it can be hidden
    //when the rewards view is expanded on the iPhone5
    func collapseHeader() {
        headerHeight?.constant = AccountHeaderView.headerViewMinHeight
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.superview?.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.hideChart()
        })
    }
    
    func stopHeightConstraint() {
        headerHeight?.isActive = false
    }
    
    func resumeHeightConstraint() {
        headerHeight?.isActive = true
    }
    
    private func updateHistoryPeriodPillPosition(button: UIButton) {
        historyPeriodPillX?.isActive = false
        historyPeriodPillY?.isActive = false
        historyPeriodPillX = historyPeriodPill.centerXAnchor.constraint(equalTo: button.centerXAnchor)
        historyPeriodPillY = historyPeriodPill.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        NSLayoutConstraint.activate([historyPeriodPillX!, historyPeriodPillY!])
        UIView.spring(C.animationDuration, animations: {
            self.layoutIfNeeded()
        }, completion: {_ in})
        
        button.setTitleColor(.white, for: .normal)
        graphButtons.forEach {
            if $0.button != button {
                $0.button.setTitleColor(Theme.tertiaryText, for: .normal)
            }
        }
    }
    
    private func didTap(button: UIButton) {
        saveEvent(makeEventName([EventContext.wallet.name, currency.code, Event.axisToggle.name]))
        updateHistoryPeriodPillPosition(button: button)
    }

    override func draw(_ rect: CGRect) {
        drawGradient(start: currency.colors.0, end: currency.colors.1, rect)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
