//
//  UIImage+Utils.m
//  BreadWallet
//
//  Created by Aaron Voisine on 11/8/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "UIImage+Utils.h"
#import <Accelerate/Accelerate.h>

@implementation UIImage (Utils)

+ (instancetype)imageWithQRCodeData:(NSData *)data color:(CIColor *)color
{
    UIImage *image;
    CGImageRef cgImg;
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"],
             *maskFilter = [CIFilter filterWithName:@"CIMaskToAlpha"],
             *invertFilter = [CIFilter filterWithName:@"CIColorInvert"],
             *colorFilter = [CIFilter filterWithName:@"CIFalseColor"],
             *filter = colorFilter;
    
    [qrFilter setValue:data forKey:@"inputMessage"];
    [qrFilter setValue:@"L" forKey:@"inputCorrectionLevel"];

    if (color.alpha > DBL_EPSILON) {
        [invertFilter setValue:qrFilter.outputImage forKey:@"inputImage"];
        [maskFilter setValue:invertFilter.outputImage forKey:@"inputImage"];
        [invertFilter setValue:maskFilter.outputImage forKey:@"inputImage"];
        [colorFilter setValue:invertFilter.outputImage forKey:@"inputImage"];
        [colorFilter setValue:color forKey:@"inputColor0"];
    }
    else {
        [maskFilter setValue:qrFilter.outputImage forKey:@"inputImage"];
        filter = maskFilter;
    }
    
    @synchronized ([CIContext class]) {
        // force software rendering for security (GPU rendering causes image artifacts on iOS 7 and is generally crashy)
        CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}];
        
        if (! context) context = [CIContext context];
        cgImg = [context createCGImage:filter.outputImage fromRect:filter.outputImage.extent];
    }

    image = [UIImage imageWithCGImage:cgImg];
    CGImageRelease(cgImg);
    return image;
}

- (UIImage *)resize:(CGSize)size withInterpolationQuality:(CGInterpolationQuality)quality
{
    UIGraphicsBeginImageContext(size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIImage *image = nil;
    
    if (context) {
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextRotateCTM(context, M_PI); // flip
        CGContextScaleCTM(context, -1.0, 1.0); // mirror
        CGContextDrawImage(context, CGContextGetClipBoundingBox(context), self.CGImage);
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    
    UIGraphicsEndImageContext();
    return image;
}

@end
