//
//  HomeScreenViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class HomeScreenViewController : UIViewController, Subscriber {
    init() {
        self.currencyList = AssetListTableView()
        super.init(nibName: nil, bundle: nil)
    }

    private let currencyList: AssetListTableView
    private let subHeaderView = UIView()
    private let logo = UIImageView(image:#imageLiteral(resourceName: "LogoGradient"))
    private let total = UILabel(font: .customMedium(size: 18.0), color: .darkText)
    private let totalHeader = UILabel(font: .customMedium(size: 14.0))

    var didSelectCurrency : ((CurrencyDef) -> Void)?

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(subHeaderView)
        let height: CGFloat = 46.0
        if #available(iOS 11.0, *) {
            subHeaderView.constrain([
                subHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                subHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0.0),
                subHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                subHeaderView.heightAnchor.constraint(equalToConstant: height) ])
        } else {
            subHeaderView.constrain([
                subHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                subHeaderView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 0.0),
                subHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                subHeaderView.heightAnchor.constraint(equalToConstant: height) ])
        }

        subHeaderView.backgroundColor = .white

        addChildViewController(currencyList, layout: {
            currencyList.view.constrain([
                currencyList.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                currencyList.view.topAnchor.constraint(equalTo: subHeaderView.bottomAnchor),
                currencyList.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                currencyList.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        })
        currencyList.didSelectCurrency = { [weak self] currency in
            self?.didSelectCurrency?(currency)
        }
        subHeaderView.clipsToBounds = false
        subHeaderView.addSubview(logo)
        logo.constrain([
            logo.leadingAnchor.constraint(equalTo: subHeaderView.leadingAnchor, constant: C.padding[2]),
            logo.bottomAnchor.constraint(equalTo: subHeaderView.bottomAnchor, constant: -C.padding[2]),
            logo.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25),
            logo.heightAnchor.constraint(equalTo: logo.widthAnchor, multiplier: 230.0/772.0)])

        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.shadowImage = #imageLiteral(resourceName: "TransparentPixel")
        navigationController?.navigationBar.setBackgroundImage(#imageLiteral(resourceName: "TransparentPixel"), for: .default)

//        stores[0].lazySubscribe(self, selector: { $0.walletState.balance != $1.walletState.balance }, callback: { _ in
//            self.updateTotalAssets()
//        })
//
//        stores.forEach {
//            $0.lazySubscribe(self, selector: { $0.walletState.bigBalance?.getString(10) != $1.walletState.bigBalance?.getString(10) }, callback: { _ in
//                self.updateTotalAssets()
//            })
//        }
//
//        stores.forEach {
//            $0.lazySubscribe(self, selector: { $0.currentRate != $1.currentRate }, callback: { _ in
//                self.updateTotalAssets()
//            })
//        }

        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        subHeaderView.addSubview(totalHeader)
        subHeaderView.addSubview(total)
    }

    private func addConstraints() {
        total.constrain([
            total.trailingAnchor.constraint(equalTo: subHeaderView.trailingAnchor, constant: -C.padding[2]),
            total.bottomAnchor.constraint(equalTo: subHeaderView.bottomAnchor, constant: -C.padding[2]) ])
        totalHeader.constrain([
            totalHeader.trailingAnchor.constraint(equalTo: total.trailingAnchor),
            totalHeader.bottomAnchor.constraint(equalTo: total.topAnchor, constant: 0.0) ])
    }

    private func setInitialData() {
        totalHeader.text = "total assets"
        totalHeader.textAlignment = .left
        total.textAlignment = .left
        total.text = "$0"
        title = ""
        navigationItem.titleView = UIView()
        updateTotalAssets()
    }

    private func updateTotalAssets() {
//        guard let bitcoinBalance = stores[0].state.walletState.balance else { return }
//        guard let bitcoinRate = stores[0].state.currentRate else { return }
//        let bitcoinAmount = Amount(amount: bitcoinBalance, rate: bitcoinRate, maxDigits: stores[0].state.maxDigits, store: stores[0]).localAmount
//
//        guard let ethBalance = stores[1].state.walletState.bigBalance else { return }
//        guard let ethRate = stores[1].state.currentRate else { return }
//        var decimal = Decimal(string: ethBalance.getString(10)) ?? Decimal(0)
//        var amount: Decimal = 0.0
//        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
//        let eth = NSDecimalNumber(decimal: amount)
//        let ethValue = eth.doubleValue*ethRate.rate
//
//        let total = bitcoinAmount + ethValue
//
//        let format = NumberFormatter()
//        format.isLenient = true
//        format.numberStyle = .currency
//        format.generatesDecimalNumbers = true
//        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
//        format.currencySymbol = stores[0].state.currentRate!.currencySymbol
//        self.total.text = format.string(from: NSNumber(value: total))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

