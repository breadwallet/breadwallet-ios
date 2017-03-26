//
//  ScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import AVFoundation

typealias ScanCompletion = (PaymentRequest?) -> Void

class ScanViewController : UIViewController {

    static var isCameraAllowed: Bool {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) != .denied
    }

    let completion: ScanCompletion
    let isValidURI: (String) -> Bool

    fileprivate let guide = CameraGuideView()
    fileprivate let session = AVCaptureSession()
    private let toolbar = UIView()
    private let close = UIButton.close
    private let flash = UIButton.icon(image: #imageLiteral(resourceName: "Flash"), accessibilityLabel: S.Scanner.flashButtonLabel)
    fileprivate var currentUri = ""

    init(completion: @escaping ScanCompletion, isValidURI: @escaping (String) -> Bool) {
        self.completion = completion
        self.isValidURI = isValidURI
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
        toolbar.constrain([
            toolbar.constraint(.height, constant: 48.0) ])

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

        guide.constrain([
            guide.constraint(.leading, toView: view, constant: C.padding[6]),
            guide.constraint(.trailing, toView: view, constant: -C.padding[6]),
            guide.constraint(.centerY, toView: view),
            NSLayoutConstraint(item: guide, attribute: .width, relatedBy: .equal, toItem: guide, attribute: .height, multiplier: 1.0, constant: 0.0) ])
        guide.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)

        close.tap = {
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

    private func addCameraPreview() {
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        guard let previewLayer = AVCaptureVideoPreviewLayer(session: session) else { assert(false); return }
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)

        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: .main)
        session.addOutput(output)

        if output.availableMetadataObjectTypes.contains(where: { objectType in
            return objectType as! String == AVMetadataObjectTypeQRCode
        }) {
            output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        } else {
            print("no qr code support")
        }

        DispatchQueue(label: "qrscanner").async {
            self.session.startRunning()
        }

        if device.hasTorch {
            flash.tap = {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = device.torchMode == .on ? .off : .on
                    device.unlockForConfiguration()
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
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        if let data = metadataObjects as? [AVMetadataMachineReadableCodeObject] {
            if data.count == 0 {
                guide.state = .normal
            } else {
                data.forEach {
                    guard let uri = $0.stringValue else { return }
                    if self.currentUri != uri {
                        self.currentUri = uri
                        if let paymentRequest = PaymentRequest(string: uri) {
                            guide.state = .positive
                            //Add a small delay so the green guide will be seen
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                                self.dismiss(animated: true, completion: {
                                    print("completion")
                                    self.completion(paymentRequest)
                                })
                            })
                        } else {
                            guide.state = .negative
                        }
                    }
                }
            }
        }
    }
}
