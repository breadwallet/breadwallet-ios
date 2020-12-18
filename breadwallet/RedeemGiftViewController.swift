// 
//  RedeemGiftViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-25.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit
import WalletKit

class RedeemContainer: UIView {
    
    private var didLayout = false
    private var cornerRadius: CGFloat = 8.0
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didLayout else { return }
        didLayout = true
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = [UIColor.gradientStart.cgColor, UIColor.gradientEnd.cgColor] as [Any]
        gradient.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradient.startPoint = CGPoint(x: 1.0, y: 0.0)
        gradient.cornerRadius = cornerRadius
        layer.insertSublayer(gradient, at: 0)
        
        let shadowLayer = CAShapeLayer()
        shadowLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        shadowLayer.fillColor = UIColor.clear.cgColor
        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowPath = shadowLayer.path
        shadowLayer.shadowOffset = CGSize(width: 4.0, height: 4.0)
        shadowLayer.shadowOpacity = 0.25
        shadowLayer.shadowRadius = cornerRadius
        layer.insertSublayer(shadowLayer, at: 0)
    }
}

class RedeemGiftViewController: UIViewController, Subscriber {
    
    let container = RedeemContainer()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let close = UIButton.close
    private let titleLabel = UILabel(font: Theme.h3Accent, color: .white)
    private let separator = UIView(color: .white)
    private let icon = UIImageView()
    private let body = UILabel(font: Theme.body1, color: .white)
    private let redeem = BRDButton(title: "Redeem", type: .secondaryTransparent)
    private let statusCircle = LinkStatusCircle(colour: .white)
    private let confetti = ConfettiView()
    private let transitioner = RedeemTransitioningDelegate()
    private let qrCode: QRCode
    private let wallet: Wallet
    private let sweeperResult: Result<WalletSweeper, WalletSweeperError>
    
    init(qrCode: QRCode, wallet: Wallet, sweeperResult: Result<WalletSweeper, WalletSweeperError>) {
        self.qrCode = qrCode
        self.wallet = wallet
        self.sweeperResult = sweeperResult
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
        transitioningDelegate = transitioner
    }
    
    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        view.addSubview(blurView)
        view.addSubview(container)
        container.addSubview(close)
        container.addSubview(titleLabel)
        container.addSubview(separator)
        container.addSubview(icon)
        container.addSubview(body)
        container.addSubview(redeem)
        container.addSubview(statusCircle)
        view.addSubview(confetti)
    }
    
    private func addConstraints() {
        blurView.constrain(toSuperviewEdges: nil)
        container.constrain([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[4]),
            container.heightAnchor.constraint(equalToConstant: 265.0),
            container.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -C.padding[4]),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        close.constrain([
            close.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[1]/2.0),
            close.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[1]/2.0),
            close.widthAnchor.constraint(equalToConstant: 44.0),
            close.heightAnchor.constraint(equalToConstant: 44.0)])
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor)])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0)])
        icon.constrain([
            icon.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[2]),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 44.0),
            icon.heightAnchor.constraint(equalToConstant: 44.0)])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[4]),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[4]),
            body.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: C.padding[2])])
        redeem.constrain([
            redeem.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: C.padding[2]),
            redeem.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -C.padding[2]),
            redeem.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])])
        statusCircle.constrain([
            statusCircle.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[2]),
            statusCircle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            statusCircle.heightAnchor.constraint(equalToConstant: 44.0),
            statusCircle.widthAnchor.constraint(equalToConstant: 44.0) ])
        confetti.constrain(toSuperviewEdges: nil)
        confetti.isUserInteractionEnabled = false
    }
    
    private func setInitialData() {
        handleSweeperResult(result: sweeperResult)
        
        statusCircle.isHidden = true
        
        titleLabel.text = "Redeem Gift!"
        body.lineBreakMode = .byWordWrapping
        body.numberOfLines = 0
        body.textAlignment = .center
        icon.tintColor = .white
        close.tintColor = .white
        close.tap = {
            self.dismiss(animated: true, completion: nil)
            
        }
        
        redeem.layer.borderWidth = 1.0
        redeem.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        redeem.layer.cornerRadius = 8.0
        redeem.clipsToBounds = true
        
        redeem.tap = didTapRedeem
        
        if #available(iOS 13.0, *) {
            icon.image = UIImage(systemName: "gift")
        }
    }
    
    private func handleSweeperResult(result: Result<WalletSweeper, WalletSweeperError>) {
        DispatchQueue.main.async {
            switch result {
            case .success(let sweeper):
                self.handleGetBalance(amount: sweeper.balance)
            case .failure:
                self.setErrorMessageState("This gift has already been redeemed.")
            }
        }
    }
    
    private func handleGetBalance(amount: WalletKit.Amount?) {
        guard let amount = amount else { return }
        let fiatAmount = Amount(cryptoAmount: amount, currency: Currencies.btc.instance!)
        UIView.animate(withDuration: 0.2, animations: {
            self.body.text = "You have been gifted \(fiatAmount.fiatDescription) worth of Bitcoin. Tap below to redeem it."
            self.icon.isHidden = false
            self.statusCircle.isHidden = true
            self.redeem.isHidden = false
        })
    }
    
    private func didTapRedeem() {
        self.icon.isHidden = true
        self.statusCircle.isHidden = false
        self.body.text = "Redeeming..."
        self.statusCircle.drawCircleWithRepeat()
        
        guard case .success(let sweeper) = sweeperResult else { return }
        sweeper.estimate(fee: wallet.feeForLevel(level: .regular)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let feeBasis):
                    self.submit(sweeper: sweeper, fee: feeBasis)
                case .failure:
                    self.setErrorMessageState("There was an error estimating the fee.")
                }
            }
        }
    }
    
    private func setErrorMessageState(_ message: String) {
        body.text = message
        redeem.title = "OK"
        redeem.tap = { self.dismiss(animated: true, completion: nil) }
    }
    
    private func submit(sweeper: WalletSweeper, fee: TransferFeeBasis) {
        guard let transfer = sweeper.submit(estimatedFeeBasis: fee) else { return }
        wallet.subscribe(self) { event in
            guard case .transferSubmitted(let eventTransfer, _) = event,
                eventTransfer.hash == transfer.hash else { return }
            guard let kvStore = Backend.kvStore else { return }
            let tx = Transaction(transfer: eventTransfer, wallet: self.wallet, kvStore: Backend.kvStore, rate: nil)
            tx.createMetaData(rate: nil,
                              comment: "Gift",
                              feeRate: nil,
                              tokenTransfer: nil,
                              isReceivedGift: true,
                              kvStore: kvStore)
            DispatchQueue.main.async {
                self.redeem.tap = self.showConfetti
                self.redeemSuccess()
            }
        }
    }
    
    private func redeemSuccess() {
        statusCircle.drawCheckBox()
        UIView.animate(withDuration: 0.2, animations: {
            self.body.text = "Your gift has been successfully redeemed. It will appear in your bitcoin wallet."
            self.redeem.title = "OK"
        })
    }
    
    private func showConfetti() {
        let duration = 3.0
        confetti.emit(for: duration, completion: {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        })
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard #available(iOS 13.0, *) else { return .default }
        return .lightContent
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let kAnimationLayerKey = "com.nshipster.animationLayer"

final class ConfettiView: UIView {
    func emit(for duration: TimeInterval = 3.0, completion: @escaping () -> Void) {
        let layer = ConfettiLayer()
        layer.setup()
        layer.frame = self.bounds
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer(layer)
        let animation = CAKeyframeAnimation(keyPath: #keyPath(CAEmitterLayer.birthRate))
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        animation.values = [1, 0, 0]
        animation.keyTimes = [0, 0.5, 1]
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.birthRate = 1.0

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 1
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.setValue(layer, forKey: kAnimationLayerKey)
            transition.isRemovedOnCompletion = false
            layer.add(transition, forKey: nil)
            layer.opacity = 0
            completion()
        }
        layer.add(animation, forKey: nil)
        CATransaction.commit()
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        guard let superview = newSuperview else { return }
        frame = superview.bounds
    }
}

private final class ConfettiLayer: CAEmitterLayer {
    func setup() {
        emitterCells = (0...5).map {_ in ["💸", "💰", "🤑", "💵"].randomElement()! }.map { character in
            let cell = CAEmitterCell()
            cell.birthRate = 2
            cell.lifetime = 5.0
            cell.velocity = 150.0
            cell.velocityRange = cell.velocity / 2
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spinRange = .pi * 6
            cell.scaleRange = 0.25
            cell.scale = 1.0 - cell.scaleRange
            cell.contents = character.image().cgImage
            return cell
        }
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        emitterShape = .line
        emitterSize = CGSize(width: frame.size.width, height: 1.0)
        emitterPosition = CGPoint(x: frame.size.width / 2.0, y: 0)
    }
}

fileprivate extension String {
    func image(with font: UIFont = UIFont.systemFont(ofSize: 16.0)) -> UIImage {
        let string = NSString(string: "\(self)")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let size = string.size(withAttributes: attributes)

        return UIGraphicsImageRenderer(size: size).image { _ in
            string.draw(at: .zero, withAttributes: attributes)
        }
    }
}
