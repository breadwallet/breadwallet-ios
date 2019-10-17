//
//  StartImportViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-13.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import BRCrypto

/**
 *  Screen that allows the user to scan a QR code corresponding to a private key.
 *
 *  It can be displayed in response to the "Redeem Private Key" menu item under Bitcoin
 *  preferences or in response to the user scanning a private key using the Scan QR Code
 *  item in the main menu. In the latter case, an initial QR code is passed to the init() method.
 */
class ImportKeyViewController: UIViewController, Subscriber {
    /**
     *  Initializer
     *
     *  walletManager - Bitcoin wallet manager
     *  initialQRCode - a QR code that was previously scanned, causing this import view controller to
     *                  be displayed
     */
    init(wallet: Wallet, initialQRCode: QRCode? = nil) {
        self.wallet = wallet
        self.initialQRCode = initialQRCode
        assert(wallet.currency.isBitcoin || wallet.currency.isBitcoinCash, "Importing only supports btc or bch")
        super.init(nibName: nil, bundle: nil)
    }

    private let wallet: Wallet
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
    
    // Previously scanned QR code passed to init()
    private var initialQRCode: QRCode?

    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let code = initialQRCode {
            handleScanResult(code)
            
            // Set this nil so that if the user tries to can another QR code via the
            // Scan Private Key button we don't end up trying to process the initial
            // code again. viewWillAppear() will get called again when the scanner/camera
            // is dismissed.
            initialQRCode = nil
        }
    }
    
    deinit {
        wallet.unsubscribe(self)
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

        // Set up the tap handler for the "Scan Private Key" button.
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
        guard !Key.isProtected(asPrivate: address) else {
            return unlock(address: address) { self.createTransaction(withPrivKey: $0) }
        }
        
        guard let key = Key.createFromString(asPrivate: address) else {
            showErrorMessage(S.Import.Error.notValid)
            return
        }

        createTransaction(withPrivKey: key)
        
    }
    
    private func createTransaction(withPrivKey key: Key) {
        present(balanceActivity, animated: true, completion: nil)
        wallet.createSweeper(forKey: key) { result in
            DispatchQueue.main.async {
                self.balanceActivity.dismiss(animated: true) {
                    switch result {
                    case .success(let sweeper):
                        self.importFrom(sweeper)
                    case .failure(let error):
                        self.handleError(error)
                    }
                }
            }
        }
    }
    
    private func importFrom(_ sweeper: WalletSweeper) {
        guard let balance = sweeper.balance else { return self.showErrorMessage(S.Import.Error.empty) }
        let balanceAmount = Amount(cryptoAmount: balance, currency: wallet.currency)
        guard !balanceAmount.isZero else { return self.showErrorMessage(S.Import.Error.empty) }
        sweeper.estimate(fee: wallet.feeForLevel(level: .regular)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let feeBasis):
                    self.confirmImport(fromSweeper: sweeper, fee: feeBasis)
                case .failure(let error):
                    self.handleEstimateFeeError(error)
                }
            }
        }
    }
    
    private func confirmImport(fromSweeper sweeper: WalletSweeper, fee: TransferFeeBasis) {
        let balanceAmount = Amount(cryptoAmount: sweeper.balance!, currency: wallet.currency)
        let feeAmount = Amount(cryptoAmount: fee.fee, currency: wallet.currency)
        let balanceText = "\(balanceAmount.fiatDescription) (\(balanceAmount.description))"
        let feeText = "\(feeAmount.fiatDescription)"
        let message = String(format: S.Import.confirm, balanceText, feeText)
        let alert = UIAlertController(title: S.Import.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.Import.importButton, style: .default, handler: { _ in
            self.present(self.importingActivity, animated: true)
            self.submit(sweeper: sweeper, fee: fee)
        }))
        present(alert, animated: true)
    }
    
    private func submit(sweeper: WalletSweeper, fee: TransferFeeBasis) {
        guard let transfer = sweeper.submit(estimatedFeeBasis: fee) else {
            importingActivity.dismiss(animated: true)
            return showErrorMessage(S.Alerts.sendFailure)
        }
        wallet.subscribe(self) { event in
            guard case .transferSubmitted(let eventTransfer, let success) = event,
                eventTransfer.hash == transfer.hash else { return }
            DispatchQueue.main.async {
                self.importingActivity.dismiss(animated: true) {
                    guard success else { return self.showErrorMessage(S.Import.Error.failedSubmit) }
                    self.showSuccess()
                }
            }
        }
    }
    
    private func handleError(_ error: WalletSweeperError) {
        switch error {
        case .unsupportedCurrency:
            showErrorMessage(S.Import.Error.unsupportedCurrency)
        case .invalidKey:
            showErrorMessage(S.Send.invalidAddressTitle)
        case .invalidSourceWallet:
            showErrorMessage(S.Send.invalidAddressTitle)
        case .insufficientFunds:
            showErrorMessage(S.Send.insufficientFunds)
        case .unableToSweep:
            showErrorMessage(S.Import.Error.sweepError)
        case .noTransfersFound:
            showErrorMessage(S.Import.Error.empty)
        case .unexpectedError:
            showErrorMessage(S.Alert.somethingWentWrong)
        case .queryError(let error):
            showErrorMessage(error.localizedDescription)
        }
    }
    
    private func handleEstimateFeeError(_ error: BRCrypto.Wallet.FeeEstimationError) {
        switch error {
        case .InsufficientFunds:
            showErrorMessage(S.Send.insufficientFunds)
        case .ServiceError:
            showErrorMessage(S.Import.Error.serviceError)
        case .ServiceUnavailable:
            showErrorMessage(S.Import.Error.serviceUnavailable)
        }
    }

    private func unlock(address: String, callback: @escaping (Key) -> Void) {
        let alert = UIAlertController(title: S.Import.title, message: S.Import.password, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = S.Import.passwordPlaceholder
            textField.isSecureTextEntry = true
            textField.returnKeyType = .done
        })
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { _ in
            self.unlock(alert: alert, address: address, callback: callback)
        }))
        present(alert, animated: true)
    }
    
    private func unlock(alert: UIAlertController, address: String, callback: @escaping (Key) -> Void) {
        present(self.unlockingActivity, animated: true, completion: {
            guard let password = alert.textFields?.first?.text,
                let key = Key.createFromString(asPrivate: address, withPassphrase: password) else {
                self.unlockingActivity.dismiss(animated: true, completion: {
                    self.showErrorMessage(S.Import.wrongPassword)
                })
                return
            }
            self.unlockingActivity.dismiss(animated: true, completion: {
                callback(key)
            })
        })
    }

    private func showSuccess() {
        Store.perform(action: Alert.Show(.sweepSuccess(callback: { [weak self] in
            guard let myself = self else { return }
            myself.dismiss(animated: true)
        })))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
