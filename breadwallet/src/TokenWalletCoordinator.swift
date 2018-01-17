//
//  TokenWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class TokenWalletCoordinator {

    private let store: Store
    private let btcStore: Store
    private let gethManager: GethManager
    private var timer: Timer? = nil
    private var longTimer: Timer? = nil
    private let apiClient: BRAPIClient

    init(store: Store, gethManager: GethManager, apiClient: BRAPIClient, btcStore: Store) {
        self.store = store
        self.gethManager = gethManager
        self.apiClient = apiClient
        self.btcStore = btcStore
        store.perform(action: WalletChange.set(store.state.walletState.mutate(receiveAddress: gethManager.address.getHex())))
        self.refresh()
        self.longRefresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        self.longTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func longRefresh() {
        if let address = store.state.walletState.crowdsale?.contract.address {
            DispatchQueue.global(qos: .utility).async {
                if let weiRaised = self.gethManager.getWeiRaised(forContractAddress: address), let cap = self.gethManager.getCap(forContractAddress: address), let minContribution = self.gethManager.getMinContribution(forContractAddress: address), let maxContribution = self.gethManager.getMaxContribution(forContractAddress: address){
                    DispatchQueue.main.async {
                        if let crowdsale = self.store.state.walletState.crowdsale {
                            let newCrowdsale = Crowdsale(startTime: crowdsale.startTime, endTime: crowdsale.endTime, minContribution: minContribution, maxContribution: maxContribution, contract: crowdsale.contract, rate: crowdsale.rate, verificationCountryCode: crowdsale.verificationCountryCode, weiRaised: weiRaised, cap: cap)
                            self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(crowdSale: newCrowdsale)))
                        }
                    }
                }
            }
        }
    }

    @objc private func refresh() {
        guard let token = store.state.walletState.token,
            let receiveAddress = store.state.walletState.receiveAddress else { return }
        let tokenAddress = token.address

        apiClient.tokenBalance(tokenAddress: tokenAddress, address: store.state.walletState.receiveAddress!, callback: { balance in
            DispatchQueue.main.async {
                self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(bigBalance: balance)))
            }
        })

        apiClient.tokenHistory(tokenAddress: tokenAddress, ethAddress: receiveAddress) { events in
            let newViewModels = events.sorted { $0.timeStamp > $1.timeStamp }.map {
                ERC20Transaction(event: $0, address: receiveAddress, token: token)
            }

            let oldViewModels = self.store.state.walletState.transactions
            let oldCompleteViewModels = oldViewModels.filter { $0.status != .pending }
            let oldPendingViewModels = oldViewModels.filter { $0.status == .pending }

            let mergedViewModels: [Transaction]
            if oldPendingViewModels.count > 0 {
                if (oldPendingViewModels.count + oldCompleteViewModels.count) == newViewModels.count {
                    mergedViewModels = newViewModels
                } else {
                    mergedViewModels = oldPendingViewModels + newViewModels
                }
            } else {
                mergedViewModels = newViewModels
            }

            DispatchQueue.main.async {
                self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(transactions: mergedViewModels)))
            }
        }

        if let crowdsale = store.state.walletState.crowdsale {
            if crowdsale.startTime == nil || crowdsale.endTime == nil {
                if let start = gethManager.getStartTime(forContractAddress: crowdsale.contract.address), let end = gethManager.getEndTime(forContractAddress: crowdsale.contract.address) {
                    let newCrowdsale = Crowdsale(startTime: start, endTime: end, minContribution: crowdsale.minContribution, maxContribution: crowdsale.maxContribution, contract: crowdsale.contract, rate: crowdsale.rate, verificationCountryCode: crowdsale.verificationCountryCode, weiRaised: crowdsale.weiRaised, cap: crowdsale.cap)
                    store.perform(action: WalletChange.set(store.state.walletState.mutate(crowdSale: newCrowdsale)))
                }
            }

            if crowdsale.rate == nil {
                if let rate = gethManager.getRate(forContractAddress: crowdsale.contract.address) {
                    let newCrowdsale = Crowdsale(startTime: crowdsale.startTime, endTime: crowdsale.endTime, minContribution: crowdsale.minContribution, maxContribution: crowdsale.maxContribution, contract: crowdsale.contract, rate: rate, verificationCountryCode: crowdsale.verificationCountryCode, weiRaised: crowdsale.weiRaised, cap: crowdsale.cap)
                    store.perform(action: WalletChange.set(store.state.walletState.mutate(crowdSale: newCrowdsale)))
                }
            } else if store.state.rates.count == 0 {
                apiClient.ethExchangeRate { ethRate in
                    if let ethBtcRate = Double(ethRate.ethbtc), let crowdsaleRate = crowdsale.rate {
                        let rateValue = (Decimal(string: crowdsaleRate.stringValue)! as NSDecimalNumber).doubleValue
                        let ethRates = self.btcStore.state.rates.map { btcRate in
                            return Rate(code: btcRate.code, name: btcRate.name, rate: btcRate.rate*ethBtcRate/rateValue, reciprocalCode: self.store.state.walletState.token!.code)
                        }
                        DispatchQueue.main.async {
                            guard let currentRate = ethRates.first( where: { $0.code == self.store.state.defaultCurrencyCode }) else { return }
                            self.store.perform(action: ExchangeRates.setRates(currentRate: currentRate, rates: ethRates))
                        }
                    }
                }
            }
        }

    }

}
