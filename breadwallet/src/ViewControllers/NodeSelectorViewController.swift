//
//  NodeSelectorViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-08-03.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class NodeSelectorViewController: UIViewController, Trackable {

    private let titleLabel = UILabel(font: .customBold(size: 22.0), color: .white)
    private let nodeLabel = UILabel(font: .customBody(size: 14.0), color: .white)
    private let node = UILabel(font: .customBody(size: 14.0), color: .white)
    private let statusLabel = UILabel(font: .customBody(size: 14.0), color: .white)
    private let status = UILabel(font: .customBody(size: 14.0), color: .white)
    private let button: BRDButton
    private let wallet: Wallet
    private var okAction: UIAlertAction?
    private var timer: Timer?
    private let decimalSeparator = NumberFormatter().decimalSeparator ?? "."

    init(wallet: Wallet) {
        self.wallet = wallet
        if UserDefaults.customNodeIP == nil {
            button = BRDButton(title: S.NodeSelector.manualButton, type: .primary)
        } else {
            button = BRDButton(title: S.NodeSelector.automaticButton, type: .primary)
        }
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(nodeLabel)
        view.addSubview(node)
        view.addSubview(statusLabel)
        view.addSubview(status)
        view.addSubview(button)
    }

    private func addConstraints() {
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[6]),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        nodeLabel.pinTopLeft(toView: titleLabel, topPadding: C.padding[2])
        node.pinTopLeft(toView: nodeLabel, topPadding: 0)
        statusLabel.pinTopLeft(toView: node, topPadding: C.padding[2])
        status.pinTopLeft(toView: statusLabel, topPadding: 0)
        button.constrain([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            button.topAnchor.constraint(equalTo: status.bottomAnchor, constant: C.padding[2]),
            button.heightAnchor.constraint(equalToConstant: 44.0) ])
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        titleLabel.text = S.NodeSelector.title
        nodeLabel.text = S.NodeSelector.nodeLabel
        statusLabel.text = S.NodeSelector.statusLabel
        button.tap = strongify(self) { myself in
            if UserDefaults.customNodeIP == nil {
                myself.switchToManual()
            } else {
                myself.switchToAuto()
            }
        }
        setStatusText()
        timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(setStatusText), userInfo: nil, repeats: true)
    }

    @objc private func setStatusText() {
        switch wallet.manager.state {
        case .disconnected, .deleted:
            status.text = S.NodeSelector.notConnected
        case .created:
            status.text = S.NodeSelector.connecting
        case .connected:
            status.text = S.NodeSelector.connected
        default:
            status.text = S.NodeSelector.connected
        }
        
        if let ip = UserDefaults.customNodeIP {
            node.text = "\(ip):\(UserDefaults.customNodePort ?? C.standardPort)"
        } else {
            node.text = S.NodeSelector.automaticLabel
        }
    }

    private func switchToAuto() {
        guard UserDefaults.customNodeIP != nil else { return } //noop if custom node is already nil
        saveEvent("nodeSelector.switchToAuto")
        UserDefaults.customNodeIP = nil
        UserDefaults.customNodePort = nil
        button.title = S.NodeSelector.manualButton
        reconnectWalletManager()
    }

    private func switchToManual() {
        let alert = UIAlertController(title: S.NodeSelector.enterTitle, message: S.NodeSelector.enterBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        let okAction = UIAlertAction(title: S.Button.ok, style: .default, handler: { [weak self] _ in
            guard let `self` = self else { return }
            guard let ip = alert.textFields?.first,
                let port = alert.textFields?.last,
                let addressText = ip.text?.replacingOccurrences(of: self.decimalSeparator, with: ".") else { return }
            self.saveEvent("nodeSelector.switchToManual")
            UserDefaults.customNodeIP = addressText
            if let portText = port.text {
                UserDefaults.customNodePort = Int(portText)
            }
            self.reconnectWalletManager()
            self.button.title = S.NodeSelector.automaticButton
        })
        self.okAction = okAction
        self.okAction?.isEnabled = false
        alert.addAction(okAction)
        alert.addTextField { [unowned self] textField in
            textField.placeholder = "192.168.0.1"
            textField.keyboardType = self.keyboardType
            textField.addTarget(self, action: #selector(self.ipAddressDidChange(textField:)), for: .editingChanged)
        }
        alert.addTextField { [unowned self] textField in
            textField.placeholder = "8333"
            textField.keyboardType = self.keyboardType
        }
        present(alert, animated: true, completion: nil)
    }
    
    private func reconnectWalletManager() {
        DispatchQueue.global(qos: .userInitiated).async {
            let manager = self.wallet.manager
            manager.connect(using: manager.customPeer)
        }
    }
    
    private var keyboardType: UIKeyboardType {
        return decimalSeparator == "." ? .decimalPad : .numbersAndPunctuation
    }

    @objc private func ipAddressDidChange(textField: UITextField) {
        if let text = textField.text?.replacingOccurrences(of: decimalSeparator, with: ".") {
            if text.components(separatedBy: ".").count == 4 && ascii2addr(AF_INET, text, nil) > 0 {
                self.okAction?.isEnabled = true
                return
            }
        }
        self.okAction?.isEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
