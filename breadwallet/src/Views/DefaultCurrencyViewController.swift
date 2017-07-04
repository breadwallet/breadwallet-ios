//
//  DefaultCurrencyViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class DefaultCurrencyViewController : UITableViewController, Subscriber, CustomTitleView {

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
        self.faq = .buildFaqButton(store: store, articleId: ArticleIds.defaultCurrency)
        super.init(style: .plain)
    }

    private let walletManager: WalletManager
    private let store: Store
    private let cellIdentifier = "CellIdentifier"
    private let faq: UIButton
    private var rates: [Rate] = [] {
        didSet {
            tableView.reloadData()
            setExchangeRateLabel()
        }
    }
    private var swipeGr = UISwipeGestureRecognizer()
    private var defaultCurrencyCode: String? = nil {
        didSet {
            //Grab index paths of new and old rows when the currency changes
            let paths: [IndexPath] = rates.enumerated().filter { $0.1.code == defaultCurrencyCode || $0.1.code == oldValue } .map { IndexPath(row: $0.0, section: 0) }
            tableView.beginUpdates()
            tableView.reloadRows(at: paths, with: .automatic)
            tableView.endUpdates()

            setExchangeRateLabel()
        }
    }
    private let rateLabel = UILabel(font: .customBody(size: 16.0), color: .darkText)
    private let swipeView = UIView()
    let titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
    let customTitle = S.DefaultCurrency.title

    deinit {
        store.unsubscribe(self)
    }

    override func viewDidLoad() {
        setHeader()
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        store.subscribe(self, selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode }, callback: {
            self.defaultCurrencyCode = $0.defaultCurrencyCode
        })
        store.subscribe(self, selector: { $0.maxDigits != $1.maxDigits }, callback: { _ in
            self.setExchangeRateLabel()
        })
        walletManager.apiClient?.exchangeRates { rates, error in
            self.rates = rates.filter { $0.code != C.btcCurrencyCode }
        }

        swipeGr.addTarget(self, action: #selector(swipe))
        swipeGr.delegate = self
        swipeGr.direction = .left
        swipeView.addGestureRecognizer(swipeGr)
        swipeView.isUserInteractionEnabled = true
    }

    private func setHeader() {
        let header = UIView(color: .whiteTint)
        let rateLabelTitle = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)

        header.addSubview(titleLabel)
        header.addSubview(rateLabelTitle)
        header.addSubview(rateLabel)
        header.addSubview(faq)
        header.addSubview(swipeView)

        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: C.padding[2]) ])
        rateLabelTitle.constrain([
            rateLabelTitle.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            rateLabelTitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]) ])
        rateLabel.constrain([
            rateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            rateLabel.topAnchor.constraint(equalTo: rateLabelTitle.bottomAnchor),
            rateLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -C.padding[2]) ])
        faq.constrain([
            faq.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            faq.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: 0.0),
            faq.constraint(.height, constant: 44.0),
            faq.constraint(.width, constant: 44.0)])
        swipeView.constrain([
            swipeView.leadingAnchor.constraint(equalTo: rateLabelTitle.leadingAnchor),
            swipeView.topAnchor.constraint(equalTo: rateLabelTitle.topAnchor),
            swipeView.bottomAnchor.constraint(equalTo: rateLabel.bottomAnchor),
            swipeView.trailingAnchor.constraint(equalTo: faq.leadingAnchor) ])

        titleLabel.text = S.DefaultCurrency.title
        rateLabelTitle.text = S.DefaultCurrency.rateLabel

        //This is a hack so that autolayout gets the right size for the header
        rateLabel.text = "blah blah"
        rateLabel.textColor = .white

        tableView.tableHeaderView = header
        tableView.backgroundColor = .whiteTint
        tableView.separatorStyle = .none

        header.constrain([
            header.widthAnchor.constraint(equalTo: view.widthAnchor) ])
        addCustomTitle()
    }

    private func setExchangeRateLabel() {
        if let currentRate = rates.filter({ $0.code == defaultCurrencyCode }).first {
            let amount = Amount(amount: C.satoshis, rate: currentRate, maxDigits: store.state.maxDigits)
            let bitsAmount = Amount(amount: C.satoshis, rate: currentRate, maxDigits: store.state.maxDigits)
            rateLabel.textColor = .darkText
            rateLabel.text = "\(amount.string(forLocal: currentRate.locale)) = \(bitsAmount.bits)"
        }
    }

    @objc private func swipe() {
        let newDigits = (((store.state.maxDigits - 2)/3 + 1) % 3)*3 + 2 //cycle through 2, 5, 8
        store.perform(action: MaxDigits.set(newDigits))
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rates.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let rate = rates[indexPath.row]
        cell.textLabel?.text = "\(rate.code) (\(rate.currencySymbol))"

        if rate.code == defaultCurrencyCode {
            let check = UIImageView(image: #imageLiteral(resourceName: "CircleCheck").withRenderingMode(.alwaysTemplate))
            check.tintColor = C.defaultTintColor
            cell.accessoryView = check
        } else {
            cell.accessoryView = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rate = rates[indexPath.row]
        store.perform(action: DefaultCurrency.setDefault(rate.code))
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScrollForCustomTitle(yOffset: scrollView.contentOffset.y)
    }

    override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollViewWillEndDraggingForCustomTitle(yOffset: targetContentOffset.pointee.y)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DefaultCurrencyViewController : UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
