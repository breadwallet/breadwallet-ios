//
//  MultiframeAnimation.swift
//  breadwallet
//
//  Created by David Seitz Jr on 1/30/19.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/// A view that can be animated based on a collection of image frames.
class MultiframeAnimation: UIView {

    /// Prepares image frames required for this multiframe animation.
    /// Depending on the number of images needed for this animation, it may
    /// need to be called well aheaded of time before the animation is needed.
    /// - Parameter fileName: The name used in each image's file name, excluding count and file type. Example: `"AnimationFrame-"`
    /// - Parameter count: The number of image frames to be used in this animation, used to retrieve each image's file name.
    /// - Parameter fileType: The file type or extension of each image frame.
    /// - Parameter completion: An opportunity to execute code when all animation frames have been prepared.
    func setUpAnimationFrames(fileName: String, count: Int, repeatFirstFrameCount: Int, fileType: String, completion: ((_ animationFrames: [UIImage]) -> Void)? = nil) {

        var images = [UIImage]()

        /// Call the instantiation logic on a background thread to prevent disrupting the user experience.
        DispatchQueue.global(qos: .background).async {

            for number in 1...count {
                let name = "\(fileName)\(number)"
                guard
                    let location = Bundle.main.path(forResource: name, ofType: "\(fileType)"),
                    let frameImage = UIImage(contentsOfFile: location) else {
                        return assertionFailure("Missing animation frame file: \(name)")
                }

                // Setting up images this way with UIGraphics is much faster than using UIImage(named:).
                UIGraphicsBeginImageContext(frameImage.size)
                let rect = CGRect(x: 0, y: 0, width: frameImage.size.width, height: frameImage.size.height)
                frameImage.draw(in: rect)
                guard let renderedImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
                UIGraphicsEndImageContext()
                images.append(renderedImage)
                
                if number == 1 {
                    for _ in 0..<repeatFirstFrameCount {
                        images.append(renderedImage)
                    }
                }
            }

            DispatchQueue.main.async {
                completion?(images)
            }
        }
    }
}
