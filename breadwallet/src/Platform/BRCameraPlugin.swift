//
//  BRCameraPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 10/9/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import Foundation

@available(iOS 8.0, *)
@objc open class BRCameraPlugin: NSObject, BRHTTPRouterPlugin, UIImagePickerControllerDelegate,
                                   UINavigationControllerDelegate, CameraOverlayDelegate {
    
    let controller: UIViewController
    var response: BRHTTPResponse?
    var picker: UIImagePickerController?
    
    init(fromViewController: UIViewController) {
        self.controller = fromViewController
        super.init()
    }
    
    open func hook(_ router: BRHTTPRouter) {
        // GET /_camera/take_picture
        //
        // Optionally pass ?overlay=<id> (see overlay ids below) to show an overlay
        // in picture taking mode
        //
        // Status codes:
        //   - 200: Successful image capture
        //   - 204: User canceled image picker
        //   - 404: Camera is not available on this device
        //   - 423: Multiple concurrent take_picture requests. Only one take_picture request may be in flight at once.
        //
        router.get("/_camera/take_picture") { (request, match) -> BRHTTPResponse in
            if self.response != nil {
                print("[BRCameraPlugin] already taking a picture")
                return BRHTTPResponse(request: request, code: 423)
            }
            if !UIImagePickerController.isSourceTypeAvailable(.camera)
                || UIImagePickerController.availableCaptureModes(for: .rear) == nil {
                print("[BRCameraPlugin] no camera available")
                return BRHTTPResponse(request: request, code: 404)
            }
            let response = BRHTTPResponse(async: request)
            self.response = response
            
            DispatchQueue.main.async {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = .camera
                picker.cameraCaptureMode = .photo
                
                // set overlay
                if let overlay = request.query["overlay"] , overlay.count == 1 {
                    print(["BRCameraPlugin] overlay = \(overlay)"])
                    let screenBounds = UIScreen.main.bounds
                    if overlay[0] == "id" {
                        picker.showsCameraControls = false
                        picker.allowsEditing = false
                        picker.hidesBarsOnTap = true
                        picker.isNavigationBarHidden = true
                        
                        let overlay = IDCameraOverlay(frame: screenBounds)
                        overlay.delegate = self
                        overlay.backgroundColor = UIColor.clear
                        picker.cameraOverlayView = overlay
                    }
                }
                self.picker = picker
                self.controller.present(picker, animated: true, completion: nil)
            }
            
            return response
        }
        
        // GET /_camera/picture/(id)
        //
        // Return a picture as taken by take_picture
        //
        // Status codes:
        //   - 200: Successfully returned iamge
        //   - 404: Couldn't find image with that ID
        //
        router.get("/_camera/picture/(id)") { (request, match) -> BRHTTPResponse in
            var id: String!
            if let ids = match["id"] , ids.count == 1 {
                id = ids[0]
            } else {
                return BRHTTPResponse(request: request, code: 500)
            }
            let resp = BRHTTPResponse(async: request)
            do {
                let imgDat = try self.readImage(id)
                resp.provide(200, data: imgDat, contentType: "image/jpeg")
            } catch let e {
                print("[BRCameraPlugin] error reading image: \(e)")
                resp.provide(500)
            }
            return resp
        }
    }
    
    open func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        guard let resp = self.response else {
            return
        }
        defer {
            self.response = nil
            DispatchQueue.main.async {
                picker.dismiss(animated: true, completion: nil)
            }
        }
        resp.provide(204, json: nil)
    }
    
    open func imagePickerController(_ picker: UIImagePickerController,
                                    didFinishPickingMediaWithInfo info: [String : Any]) {
        defer {
            DispatchQueue.main.async {
                picker.dismiss(animated: true, completion: nil)
            }
        }
        guard let resp = self.response else {
            return
        }
        guard var img = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("[BRCameraPlugin] error picking image... original image doesnt exist. data: \(info)")
            resp.provide(500)
            response = nil
            return
        }
        resp.request.queue.async {
            defer {
                self.response = nil
            }
            do {
                if let overlay = self.picker?.cameraOverlayView as? CameraOverlay {
                    if let croppedImg = overlay.cropImage(img) {
                        img = croppedImg
                    }
                }
                let id = try self.writeImage(img)
                print(["[BRCameraPlugin] wrote image to \(id)"])
                resp.provide(200, json: ["id": id])
            } catch let e {
                print("[BRCameraPlugin] error writing image: \(e)")
                resp.provide(500)
            }
        }
    }
    
    func takePhoto() {
        self.picker?.takePicture()
    }
    
    func cancelPhoto() {
        if let picker = self.picker {
            self.imagePickerControllerDidCancel(picker)
        }
    }
    
    func readImage(_ name: String) throws -> [UInt8] {
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let picDirUrl = docsUrl.appendingPathComponent("pictures", isDirectory: true)
        let picUrl = picDirUrl.appendingPathComponent("\(name).jpeg")
        guard let dat = try? Data(contentsOf: picUrl) else {
            throw ImageError.couldntRead
        }
        let bp = (dat as NSData).bytes.bindMemory(to: UInt8.self, capacity: dat.count)
        return Array(UnsafeBufferPointer(start: bp, count: dat.count))
    }
    
    func writeImage(_ image: UIImage) throws -> String {
        guard let dat = UIImageJPEGRepresentation(image, 0.5) else {
            throw ImageError.errorConvertingImage
        }
        let name = (NSData(uInt256: (dat as NSData).sha256()) as NSData).base58String()
        
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let picDirUrl = docsUrl.appendingPathComponent("pictures", isDirectory: true)
        let picDirPath = picDirUrl.path
        var attrs = try? fm.attributesOfItem(atPath: picDirPath)
        if attrs == nil {
            try fm.createDirectory(atPath: picDirPath, withIntermediateDirectories: true, attributes: nil)
            attrs = try fm.attributesOfItem(atPath: picDirPath)
        }
        let picUrl = picDirUrl.appendingPathComponent("\(name).jpeg")
        try dat.write(to: picUrl, options: [])
        return name
    }
}

enum ImageError: Error {
    case errorConvertingImage
    case couldntRead
}

protocol CameraOverlayDelegate {
    func takePhoto()
    func cancelPhoto()
}

protocol CameraOverlay {
    func cropImage(_ image: UIImage) -> UIImage?
}

class IDCameraOverlay: UIView, CameraOverlay {
    var delegate: CameraOverlayDelegate?
    let takePhotoButton: UIButton
    let cancelButton: UIButton
    let overlayRect: CGRect
    
    override init(frame: CGRect) {
        overlayRect = CGRect(x: 0, y: 0, width: frame.width, height: frame.width * CGFloat(4.0/3.0))
        takePhotoButton = UIButton(type: .custom)
        takePhotoButton.setImage(UIImage(named: "camera-btn"), for: UIControlState())
        takePhotoButton.setImage(UIImage(named: "camera-btn-pressed"), for: .highlighted)
        takePhotoButton.frame = CGRect(x: 0, y: 0, width: 79, height: 79)
        takePhotoButton.center = CGPoint(
            x: overlayRect.midX,
            y: overlayRect.maxX + (frame.height - overlayRect.maxX) * 0.75
        )
        cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(NSLocalizedString("Cancel", comment: ""), for: UIControlState())
        cancelButton.frame = CGRect(x: 0, y: 0, width: 88, height: 44)
        cancelButton.center = CGPoint(x: takePhotoButton.center.x * 0.3, y: takePhotoButton.center.y)
        cancelButton.setTitleColor(UIColor.white, for: UIControlState())
        super.init(frame: frame)
        takePhotoButton.addTarget(self, action: #selector(IDCameraOverlay.doTakePhoto(_:)),
                                  for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(IDCameraOverlay.doCancelPhoto(_:)),
                               for: .touchUpInside)
        self.addSubview(cancelButton)
        self.addSubview(takePhotoButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not implemented")
    }
    
    func doTakePhoto(_ target: UIControl) {
        delegate?.takePhoto()
    }
    
    func doCancelPhoto(_ target: UIControl) {
        delegate?.cancelPhoto()
    }
    
     override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        UIColor.black.withAlphaComponent(0.92).setFill()
        UIRectFill(overlayRect)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        ctx.setBlendMode(.destinationOut)
        
        let width = rect.size.width * 0.9
        var cutout = CGRect(origin: overlayRect.origin,
                            size: CGSize(width: width, height: width * 0.65))
        cutout.origin.x = (overlayRect.size.width - cutout.size.width) * 0.5
        cutout.origin.y = (overlayRect.size.height - cutout.size.height) * 0.5
        let path = UIBezierPath(rect: cutout.integral)
        path.fill()
        
        ctx.setBlendMode(.normal)
        
        let str = NSLocalizedString("Center your ID in the box", comment: "") as NSString
        
        let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        style.alignment = .center
        let attr = [
            NSParagraphStyleAttributeName: style,
            NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17),
            NSForegroundColorAttributeName: UIColor.white
        ]
        
        str.draw(in: CGRect(x: 0, y: cutout.maxY + 14.0, width: rect.width, height: 22), withAttributes: attr)
    }
    
    func cropImage(_ image: UIImage) -> UIImage? {
        guard let cgimg = image.cgImage else {
            return nil
        }
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let width = rect.size.width * 0.9
        var cutout = CGRect(origin: rect.origin,
                            size: CGSize(width: width, height: width * 0.65))
        cutout.origin.x = (rect.size.width - cutout.size.width) * 0.5
        cutout.origin.y = (rect.size.height - cutout.size.height) * 0.5
        cutout = cutout.integral
        
        func rad(_ f: CGFloat) -> CGFloat {
            return f / 180.0 * CGFloat(M_PI)
        }
        
        var transform: CGAffineTransform!
        switch image.imageOrientation {
        case .left:
            transform = CGAffineTransform(rotationAngle: rad(90)).translatedBy(x: 0, y: -image.size.height)
        case .right:
            transform = CGAffineTransform(rotationAngle: rad(-90)).translatedBy(x: -image.size.width, y: 0)
        case .down:
            transform = CGAffineTransform(rotationAngle: rad(-180)).translatedBy(x: -image.size.width,
                                                                                 y: -image.size.height)
        default:
            transform = CGAffineTransform.identity
        }
        transform = transform.scaledBy(x: image.scale, y: image.scale)
        cutout = cutout.applying(transform)
        
        guard let retRef = cgimg.cropping(to: cutout) else {
            return nil
        }
        return UIImage(cgImage: retRef, scale: image.scale, orientation: image.imageOrientation)
    }
}
