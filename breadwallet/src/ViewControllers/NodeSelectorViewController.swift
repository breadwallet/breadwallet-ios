//
//  NodeSelectorViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-08-03.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

//TODO:CRYPTO node selection
/*
class NodeSelectorViewController: UIViewController, Trackable {

    private let titleLabel = UILabel(font: .customBold(size: 22.0), color: .white)
    private let nodeLabel = UILabel(font: .customBody(size: 14.0), color: .white)
    private let node = UILabel(font: .customBody(size: 14.0), color: .white)
    private let statusLabel = UILabel(font: .customBody(size: 14.0), color: .white)
    private let status = UILabel(font: .customBody(size: 14.0), color: .white)
    private let button: BRDButton
    private let walletManager: BTCWalletManager
    private var okAction: UIAlertAction?
    private var timer: Timer?
    private let decimalSeparator = NumberFormatter().decimalSeparator ?? "."

    init(walletManager: BTCWalletManager) {
        self.walletManager = walletManager
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
        status.text = walletManager.peerManager?.connectionStatus.description
        node.text = walletManager.peerManager?.downloadPeerName
    }

    private func switchToAuto() {
        guard UserDefaults.customNodeIP != nil else { return } //noop if custom node is already nil
        saveEvent("nodeSelector.switchToAuto")
        UserDefaults.customNodeIP = nil
        UserDefaults.customNodePort = nil
        button.title = S.NodeSelector.manualButton
        DispatchQueue.walletQueue.async {
            self.walletManager.peerManager?.setFixedPeer(address: 0, port: 0)
            self.walletManager.peerManager?.connect()
        }
    }

    private func switchToManual() {
        let alert = UIAlertController(title: S.NodeSelector.enterTitle, message: S.NodeSelector.enterBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        let okAction = UIAlertAction(title: S.Button.ok, style: .default, handler: { [weak self] _ in
            guard let myself = self else { return }
            guard let ip = alert.textFields?.first, let port = alert.textFields?.last else { return }
            if let addressText = ip.text?.replacingOccurrences(of: myself.decimalSeparator, with: ".") {
                myself.saveEvent("nodeSelector.switchToManual")
                var address = in_addr()
                ascii2addr(AF_INET, addressText, &address)
                UserDefaults.customNodeIP = Int(address.s_addr)
                if let portText = port.text {
                    UserDefaults.customNodePort = Int(portText)
                }
                DispatchQueue.walletQueue.async {
                    myself.walletManager.peerManager?.connect()
                }
                myself.button.title = S.NodeSelector.automaticButton
            }
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
    
    private var keyboardType: UIKeyboardType {
        return decimalSeparator == "." ? .decimalPad : .numbersAndPunctuation
    }

    private func setCustomNodeText() {
        if var customNode = UserDefaults.customNodeIP {
            if let buf = addr2ascii(AF_INET, &customNode, Int32(MemoryLayout<in_addr_t>.size), nil) {
                node.text = String(cString: buf)
            }
        }
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
*/
