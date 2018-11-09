//
//  StartImportViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-13.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

class StartImportViewController: UIViewController {

    init(walletManager: BTCWalletManager, scanResult: QRCode? = nil) {
        self.walletManager = walletManager
        self.currency = walletManager.currency
        self.scanResult = scanResult
        assert(walletManager.currency is Bitcoin, "Importing only supports bitcoin")
        super.init(nibName: nil, bundle: nil)
    }

    private let walletManager: BTCWalletManager
    private let currency: Currency
    private let header = RadialGradientView(backgroundColor: .blue, offset: 64.0)
    private let illustration = UIImageView(image: #imageLiteral(resourceName: "ImportIllustration"))
    private let message = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    private let warning = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    private let button = BRDButton(title: S.Import.scan, type: .primary)
    private let bullet = UIImageView(image: #imageLiteral(resourceName: "deletecircle"))
    private let leftCaption = UILabel.wrapping(font: .customMedium(size: 13.0), color: .darkText)
    private let rightCaption = UILabel.wrapping(font: .customMedium(size: 13.0), color: .darkText)
    private let balanceActivity = BRActivityViewController(message: S.Import.checking)
    private let importingActivity = BRActivityViewController(message: S.Import.importing)
    private let unlockingActivity = BRActivityViewController(message: S.Import.unlockingActivity)
    private let scanResult: QRCode?

    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if walletManager.peerManager?.connectionStatus == BRPeerStatusDisconnected {
            DispatchQueue.walletQueue.async { [weak self] in
                self?.walletManager.peerManager?.connect()
            }
        }
        
        if let scanResult = scanResult {
            handleScanResult(scanResult)
        }
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(illustration)
        header.addSubview(leftCaption)
        header.addSubview(rightCaption)
        view.addSubview(message)
        view.addSubview(button)
        view.addSubview(bullet)
        view.addSubview(warning)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
            header.constraint(.height, constant: E.isIPhoneX ? 250.0 : 220.0) ])
        illustration.constrain([
            illustration.constraint(.width, constant: 64.0),
            illustration.constraint(.height, constant: 84.0),
            illustration.constraint(.centerX, toView: header, constant: 0.0),
            illustration.constraint(.centerY, toView: header, constant: E.isIPhoneX ? 4.0 : -C.padding[1]) ])
        leftCaption.constrain([
            leftCaption.topAnchor.constraint(equalTo: illustration.bottomAnchor, constant: C.padding[1]),
            leftCaption.trailingAnchor.constraint(equalTo: header.centerXAnchor, constant: -C.padding[2]),
            leftCaption.widthAnchor.constraint(equalToConstant: 80.0)])
        rightCaption.constrain([
            rightCaption.topAnchor.constraint(equalTo: illustration.bottomAnchor, constant: C.padding[1]),
            rightCaption.leadingAnchor.constraint(equalTo: header.centerXAnchor, constant: C.padding[2]),
            rightCaption.widthAnchor.constraint(equalToConstant: 80.0)])
        message.constrain([
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            message.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        bullet.constrain([
            bullet.leadingAnchor.constraint(equalTo: message.leadingAnchor),
            bullet.topAnchor.constraint(equalTo: message.bottomAnchor, constant: C.padding[4]),
            bullet.widthAnchor.constraint(equalToConstant: 16.0),
            bullet.heightAnchor.constraint(equalToConstant: 16.0) ])
        warning.constrain([
            warning.leadingAnchor.constraint(equalTo: bullet.trailingAnchor, constant: C.padding[2]),
            warning.topAnchor.constraint(equalTo: bullet.topAnchor, constant: 0.0),
            warning.trailingAnchor.constraint(equalTo: message.trailingAnchor) ])
        button.constrain([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[3]),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[4]),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3]),
            button.constraint(.height, constant: C.Sizes.buttonHeight) ])
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        illustration.contentMode = .scaleAspectFill
        message.text = S.Import.importMessage
        leftCaption.text = S.Import.leftCaption
        leftCaption.textAlignment = .center
        rightCaption.text = S.Import.rightCaption
        rightCaption.textAlignment = .center
        warning.text = S.Import.importWarning

        button.tap = strongify(self) { myself in
            let scan = ScanViewController(forScanningPrivateKeys: true, completion: { result in
                if let result = result {
                    myself.handleScanResult(result)
                }
            })
            myself.parent?.present(scan, animated: true, completion: nil)
        }
    }
    
    private func handleScanResult(_ result: QRCode) {
        switch result {
        case .privateKey(let key):
            didReceiveAddress(key)
        default:
            break
        }
    }

    private func didReceiveAddress(_ address: String) {
        if address.isValidPrivateKey {
            if let key = BRKey(privKey: address) {
                checkBalance(key: key)
            }
        } else if address.isValidBip38Key {
            unlock(address: address, callback: { key in
                self.checkBalance(key: key)
            })
        }
    }

    private func unlock(address: String, callback: @escaping (BRKey) -> Void) {
        let alert = UIAlertController(title: S.Import.title, message: S.Import.password, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = S.Import.passwordPlaceholder
            textField.isSecureTextEntry = true
            textField.returnKeyType = .done
        })
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { _ in
            self.present(self.unlockingActivity, animated: true, completion: {
                if let password = alert.textFields?.first?.text {
                    if let key = BRKey(bip38Key: address, passphrase: password) {
                        self.unlockingActivity.dismiss(animated: true, completion: {
                            callback(key)
                        })
                        return
                    }
                }
                self.unlockingActivity.dismiss(animated: true, completion: {
                    self.showErrorMessage(S.Import.wrongPassword)
                })
            })
        }))
        present(alert, animated: true, completion: nil)
    }

    private func checkBalance(key: BRKey) {
        present(balanceActivity, animated: true, completion: {
            var key = key
            guard let address = key.address() else {
                self.balanceActivity.dismiss(animated: true) {
                    self.showErrorMessage(S.Import.Error.notValid)
                }
                return
            }
            Backend.apiClient.fetchUTXOS(address: address, currency: self.currency, completion: { data in
                guard let data = data else {
                    self.balanceActivity.dismiss(animated: true) {
                        self.showErrorMessage(S.Alert.timedOut)
                    }
                    return
                }
                self.handleData(data: data, key: key)
            })
        })
    }

    private func handleData(data: [[String: Any]], key: BRKey) {
        var key = key
        guard let tx = UnsafeMutablePointer<BRTransaction>() else { return }
        guard let wallet = walletManager.wallet else { return }
        guard let address = key.address() else { return }
        guard let fees = Currencies.btc.state?.fees else { return }
        guard !wallet.containsAddress(address) else {
            return showErrorMessage(S.Import.Error.duplicate)
        }
        let outputs = data.compactMap { SimpleUTXO(json: $0) }
        let balance = outputs.map { $0.satoshis }.reduce(0, +)
        outputs.forEach { output in
            tx.addInput(txHash: output.hash, index: output.index, amount: output.satoshis, script: output.script)
        }

        let pubKeyLength = key.pubKey()?.count ?? 0
        walletManager.wallet?.feePerKb = fees.regular
        let fee = wallet.feeForTxSize(tx.size + 34 + (pubKeyLength - 34)*tx.inputs.count)
        balanceActivity.dismiss(animated: true, completion: {
            guard !outputs.isEmpty && balance > 0 else {
                return self.showErrorMessage(S.Import.Error.empty)
            }
            guard fee + wallet.minOutputAmount <= balance else {
                return self.showErrorMessage(S.Import.Error.highFees)
            }
            guard let rate = Currencies.btc.state?.currentRate else { return }
            let balanceAmount = Amount(amount: UInt256(balance), currency: Currencies.btc, rate: rate)
            let feeAmount = Amount(amount: UInt256(fee), currency: Currencies.btc, rate: rate)
            let balanceText = Store.state.isBtcSwapped ? balanceAmount.fiatDescription : balanceAmount.tokenDescription
            let feeText = Store.state.isBtcSwapped ? feeAmount.fiatDescription : feeAmount.tokenDescription
            let message = String(format: S.Import.confirm, balanceText, feeText)
            let alert = UIAlertController(title: S.Import.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: S.Import.importButton, style: .default, handler: { _ in
                self.publish(tx: tx, balance: balance, fee: fee, key: key)
            }))
            self.present(alert, animated: true, completion: nil)
        })
    }

    private func publish(tx: UnsafeMutablePointer<BRTransaction>, balance: UInt64, fee: UInt64, key: BRKey) {
        guard let wallet = walletManager.wallet, let currency = currency as? Bitcoin else { return }
        guard let script = BRAddress(string: wallet.receiveAddress)?.scriptPubKey else { return }
        guard walletManager.peerManager?.connectionStatus != BRPeerStatusDisconnected else { return }
        present(importingActivity, animated: true, completion: {
            tx.addOutput(amount: balance - fee, script: script)
            var keys = [key]
            _ = tx.sign(forkId: currency.forkId, keys: &keys)
                guard tx.isSigned else {
                    self.importingActivity.dismiss(animated: true, completion: {
                        self.showErrorMessage(S.Import.Error.signing)
                    })
                    return
                }
                self.walletManager.peerManager?.publishTx(tx, completion: { [weak self] _, error in
                    guard let myself = self else { return }
                    myself.importingActivity.dismiss(animated: true, completion: {
                        DispatchQueue.main.async {
                            if let error = error {
                                myself.showErrorMessage(error.localizedDescription)
                                return
                            }
                            myself.showSuccess()
                        }
                    })
                })
        })
    }

    private func showSuccess() {
        Store.perform(action: Alert.Show(.sweepSuccess(callback: { [weak self] in
            guard let myself = self else { return }
            myself.dismiss(animated: true, completion: nil)
        })))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension Data {
    var reverse: Data {
        let tempBytes = Array(([UInt8](self)).reversed())
        return Data(bytes: tempBytes)
    }
}
