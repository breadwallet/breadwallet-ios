//
//  ScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import AVFoundation

class ScanViewController : UIViewController {

    static var isCameraAllowed: Bool {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) != .denied
    }

    var completion: ((String) -> Void)?
    fileprivate let guide = CameraGuideView()

    override func viewDidLoad() {
        view.backgroundColor = .white

        let toolbar = UIView()
        toolbar.backgroundColor = .white
        view.addSubview(toolbar)
        toolbar.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        toolbar.constrain([
            toolbar.constraint(.height, constant: 48.0) ])

        let close = UIButton.close
        let flash = UIButton.smallIcon(image: #imageLiteral(resourceName: "Flash"), accessibilityLabel: NSLocalizedString("Camera Flash", comment: "Scan bitcoin address camera flash toggle"))
        toolbar.addSubview(close)
        toolbar.addSubview(flash)

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

        close.addTarget(self, action: #selector(ScanViewController.closeTapped), for: .touchUpInside)

        view.addSubview(guide)
        guide.constrain([
            guide.constraint(.leading, toView: view, constant: C.padding[6]),
            guide.constraint(.trailing, toView: view, constant: -C.padding[6]),
            guide.constraint(.centerY, toView: view),
            NSLayoutConstraint(item: guide, attribute: .width, relatedBy: .equal, toItem: guide, attribute: .height, multiplier: 1.0, constant: 0.0) ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addCameraPreview()
    }

    private func addCameraPreview() {
        let session = AVCaptureSession()
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
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
            session.startRunning()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
}

extension ScanViewController : AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        if let data = metadataObjects as? [AVMetadataMachineReadableCodeObject] {
            data.forEach {
                if $0.stringValue.hasPrefix("bitcoin:") {
                    completion?($0.stringValue)
                }
            }
        }
    }
}
