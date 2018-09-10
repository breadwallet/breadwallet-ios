//
//  ScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import AVFoundation

typealias ScanCompletion = (QRCode?) -> Void

class ScanViewController : UIViewController, Trackable {

    static func presentCameraUnavailableAlert(fromRoot: UIViewController) {
        let alertController = UIAlertController(title: S.Send.cameraUnavailableTitle, message: S.Send.cameraUnavailableMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: S.Button.settings, style: .`default`, handler: { _ in
            if let appSettings = URL(string: UIApplicationOpenSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                UIApplication.shared.open(appSettings)
            }
        }))
        fromRoot.present(alertController, animated: true, completion: nil)
    }

    static var isCameraAllowed: Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video) != .denied
    }

    private let completion: ScanCompletion
    private let allowScanningPrivateKeysOnly: Bool
    /// scanner only accepts currency-specific payment request
    private let paymentRequestCurrencyRestriction: CurrencyDef?
    fileprivate let guide = CameraGuideView()
    fileprivate let session = AVCaptureSession()
    private let toolbar = UIView()
    private let close = UIButton.close
    private let flash = UIButton.icon(image: #imageLiteral(resourceName: "Flash"), accessibilityLabel: S.Scanner.flashButtonLabel)
    fileprivate var currentUri = ""
    private var toolbarHeightConstraint: NSLayoutConstraint?
    private let toolbarHeight: CGFloat = 48.0

    init(forPaymentRequestForCurrency currencyRestriction: CurrencyDef? = nil, forScanningPrivateKeys: Bool = false, completion: @escaping ScanCompletion) {
        self.completion = completion
        self.paymentRequestCurrencyRestriction = currencyRestriction
        self.allowScanningPrivateKeysOnly = forScanningPrivateKeys
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .black
        toolbar.backgroundColor = .secondaryButton

        view.addSubview(toolbar)
        toolbar.addSubview(close)
        toolbar.addSubview(flash)
        view.addSubview(guide)

        toolbar.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        toolbarHeightConstraint = toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight)
        toolbar.constrain([toolbarHeightConstraint])
        if E.isIPhoneX {
            close.constrain([
                close.constraint(.leading, toView: toolbar),
                close.constraint(.top, toView: toolbar, constant: 2.0),
                close.constraint(.width, constant: 44.0),
                close.constraint(.height, constant: 44.0) ])
            
            flash.constrain([
                flash.constraint(.trailing, toView: toolbar),
                flash.constraint(.top, toView: toolbar, constant: 2.0),
                flash.constraint(.width, constant: 44.0),
                flash.constraint(.height, constant: 44.0) ])
        } else {
            close.constrain([
                close.constraint(.leading, toView: toolbar),
                close.constraint(.top, toView: toolbar, constant: 2.0),
                close.constraint(.bottom, toView: toolbar, constant: -2.0),
                close.constraint(.width, constant: 44.0) ])
            
            flash.constrain([
                flash.constraint(.trailing, toView: toolbar),
                flash.constraint(.top, toView: toolbar, constant: 2.0),
                flash.constraint(.bottom, toView: toolbar, constant: -2.0),
                flash.constraint(.width, constant: 44.0) ])
        }

        guide.constrain([
            guide.constraint(.leading, toView: view, constant: C.padding[6]),
            guide.constraint(.trailing, toView: view, constant: -C.padding[6]),
            guide.constraint(.centerY, toView: view),
            NSLayoutConstraint(item: guide, attribute: .width, relatedBy: .equal, toItem: guide, attribute: .height, multiplier: 1.0, constant: 0.0) ])
        guide.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)

        close.tap = { [unowned self] in
            self.saveEvent("scan.dismiss")
            self.dismiss(animated: true, completion: {
                self.completion(nil)
            })
        }

        addCameraPreview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.spring(0.8, animations: {
            self.guide.transform = .identity
        }, completion: { _ in })
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        toolbarHeightConstraint?.constant = toolbarHeight + view.safeAreaInsets.bottom
    }

    private func addCameraPreview() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)

        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: .main)
        session.addOutput(output)

        if output.availableMetadataObjectTypes.contains(where: { objectType in
            return objectType == AVMetadataObject.ObjectType.qr
        }) {
            output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        } else {
            print("no qr code support")
        }

        DispatchQueue(label: "qrscanner").async {
            self.session.startRunning()
        }

        if device.hasTorch {
            flash.tap = { [weak self] in
                do {
                    try device.lockForConfiguration()
                    device.torchMode = device.torchMode == .on ? .off : .on
                    device.unlockForConfiguration()
                    if device.torchMode == .on {
                        self?.saveEvent("scan.torchOn")
                    } else {
                        self?.saveEvent("scan.torchOff")
                    }
                } catch let error {
                    print("Camera Torch error: \(error)")
                }
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ScanViewController : AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let data = metadataObjects as? [AVMetadataMachineReadableCodeObject] {
            if data.count == 0 {
                guide.state = .normal
            } else {
                data.forEach {
                    guard let uri = $0.stringValue else { return }
                    handleURI(uri)
                }
            }
        }
    }

    func handleURI(_ uri: String) {
        if self.currentUri != uri {
            print("QR content detected: \(uri)")
            self.currentUri = uri
            let result = QRCode(content: uri)
            guard .invalid != result else {
                guide.state = .negative
                return
            }
            
            if allowScanningPrivateKeysOnly {
                guard case .privateKey(_) = result else {
                    guide.state = .negative
                    return
                }
            }
            
            if let currencyRestriction = paymentRequestCurrencyRestriction {
                guard case .paymentRequest(let request) = result, request.currency.matches(currencyRestriction) else {
                    guide.state = .negative
                    return
                }
            }
            
            guide.state = .positive
            
            switch result {
            case .paymentRequest(let request):
                switch request.currency.code {
                case Currencies.bch.code:
                    saveEvent("scan.bCashAddr")
                case Currencies.btc.code:
                    saveEvent("scan.bitcoinUri")
                case Currencies.eth.code:
                    saveEvent("scan.ethAddress")
                default: break
                }
                
            case .privateKey(_):
                saveEvent("scan.privateKey")
                guard allowScanningPrivateKeysOnly else {
                    //TODO:QR support key import from universal scan
                    guide.state = .negative
                    return
                }
                
            case .deepLink(_):
                saveEvent("scan.deepLink")
            default:
                assertionFailure("unexpected result")
            }
            
            // add a small delay so the green guide will be seen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                self.dismiss(animated: true, completion: {
                    self.completion(result)
                })
            })
        }
    }
}
