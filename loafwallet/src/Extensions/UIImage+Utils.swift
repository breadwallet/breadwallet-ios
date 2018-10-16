//
//  UIImage+Utils.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-08.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import CoreGraphics

private let inputImageKey = "inputImage"

extension UIImage {
    static func qrCode(data: Data, color: CIColor) -> UIImage? {

        let qrFilter = CIFilter(name: "CIQRCodeGenerator")
        let maskFilter = CIFilter(name: "CIMaskToAlpha")
        let invertFilter = CIFilter(name: "CIColorInvert")
        let colorFilter = CIFilter(name: "CIFalseColor")
        var filter = colorFilter

        qrFilter?.setValue(data, forKey: "inputMessage")
        qrFilter?.setValue("L", forKey: "inputCorrectionLevel")

        if Double(color.alpha) > .ulpOfOne {
            invertFilter?.setValue(qrFilter?.outputImage, forKey: inputImageKey)
            maskFilter?.setValue(invertFilter?.outputImage, forKey: inputImageKey)
            invertFilter?.setValue(maskFilter?.outputImage, forKey: inputImageKey)
            colorFilter?.setValue(invertFilter?.outputImage, forKey: inputImageKey)
            colorFilter?.setValue(color, forKey: "inputColor0")
        } else {
            maskFilter?.setValue(qrFilter?.outputImage, forKey: inputImageKey)
            filter = maskFilter
        }

        // force software rendering for security (GPU rendering causes image artifacts on iOS 7 and is generally crashy)
        let context = CIContext(options: [kCIContextUseSoftwareRenderer: true])
        objc_sync_enter(context)
        defer { objc_sync_exit(context) }
        guard let outputImage = filter?.outputImage else { assert(false, "No qr output image"); return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { assert(false, "Could not create image."); return nil }
        return UIImage(cgImage: cgImage)
    }

    func resize(_ size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { assert(false, "Could not create image context"); return nil }
        guard let cgImage = self.cgImage else { assert(false, "No cgImage property"); return nil }

        context.interpolationQuality = .none
        context.rotate(by: π) // flip
        context.scaleBy(x: -1.0, y: 1.0) // mirror
        context.draw(cgImage, in: context.boundingBoxOfClipPath)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    static func imageForColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
