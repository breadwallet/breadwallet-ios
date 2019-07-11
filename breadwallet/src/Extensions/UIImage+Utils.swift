//
//  UIImage+Utils.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-08.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import CoreGraphics

private let inputImageKey = "inputImage"

extension UIImage {
    static func qrCode(data: Data,
                       color: CIColor = .black,
                       backgroundColor: CIColor = .white) -> UIImage? {
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator"),
            let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }

        qrFilter.setDefaults()
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("L", forKey: "inputCorrectionLevel")

        colorFilter.setDefaults()
        colorFilter.setValue(qrFilter.outputImage, forKey: "inputImage")
        colorFilter.setValue(color, forKey: "inputColor0")
        colorFilter.setValue(backgroundColor, forKey: "inputColor1")

        guard let outputImage = colorFilter.outputImage else { return nil }
        guard let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func resize(_ size: CGSize, inset: CGFloat = 6.0) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { assert(false, "Could not create image context"); return nil }
        guard let cgImage = self.cgImage else { assert(false, "No cgImage property"); return nil }

        context.interpolationQuality = .none
        context.rotate(by: π) // flip
        context.scaleBy(x: -1.0, y: 1.0) // mirror
        context.draw(cgImage, in: context.boundingBoxOfClipPath.insetBy(dx: inset, dy: inset))
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
    
    func image(withInsets insets: UIEdgeInsets) -> UIImage? {
        let width = self.size.width + insets.left + insets.right
        let height = self.size.height + insets.top + insets.bottom
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, self.scale)
        let origin = CGPoint(x: insets.left, y: insets.top)
        self.draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithInsets?.withRenderingMode(renderingMode)
    }
    
    func tinted(with color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        color.set()
        withRenderingMode(.alwaysTemplate)
            .draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    static func fetchAsync(from imageUrl: String, callback: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: imageUrl) else {
            callback(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? Data(contentsOf: url)
            
            if let imageData = data, let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    callback(image)
                }
            } else {
                DispatchQueue.main.async {
                    callback(nil)
                }
            }
        }
    }

}
