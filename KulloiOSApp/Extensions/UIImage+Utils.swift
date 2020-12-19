/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit
import CoreImage

extension UIImage {
    private func middleHorizontalSlice() -> UIImage {
        return cropped(CGRect(x: size.width/4, y: 0, width: size.width/2, height: size.height))
    }

    class func combineImages(_ images: [UIImage], targetSize: CGSize) -> UIImage {
        
        // create square image context with integral size
        let rect = CGRect(x: 0.0, y: 0.0, width: targetSize.width, height: targetSize.height).integral
        let outWidth = rect.width
        let outHeight = rect.height
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        
        switch images.count {
        case 0:
            break

        case 1:
            return images[0].squareImageWithSize(targetSize)

        case 2:
            // image1 | image2
            let image1 = images[0].squareImageWithSize(targetSize).middleHorizontalSlice()
            let image2 = images[1].squareImageWithSize(targetSize).middleHorizontalSlice()

            image1.draw(at: CGPoint.zero)
            image2.draw(at: CGPoint(x: rect.width/2, y: 0))
            
        case 3:
            // image1 | image2
            //        | image3
            let image1 = images[0].squareImageWithSize(targetSize).middleHorizontalSlice()
            let image2 = images[1].squareImageWithSize(targetSize/2)
            let image3 = images[2].squareImageWithSize(targetSize/2)

            image1.draw(at: CGPoint.zero)
            image2.draw(at: CGPoint(x: outWidth/2, y: 0))
            image3.draw(at: CGPoint(x: outWidth/2, y: outHeight/2))

        default:
            // image1 | image2
            // image3 | image4
            let image1 = images[0].squareImageWithSize(targetSize/2)
            let image2 = images[1].squareImageWithSize(targetSize/2)
            let image3 = images[2].squareImageWithSize(targetSize/2)
            let image4 = images[3].squareImageWithSize(targetSize/2)

            image1.draw(at: CGPoint.zero)
            image2.draw(at: CGPoint(x: outWidth/2, y: 0))
            image3.draw(at: CGPoint(x: 0, y: outHeight/2))
            image4.draw(at: CGPoint(x: outWidth/2, y: outHeight/2))
        }
        
        // clean up
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
        
    }
    
    class func imageWithColor(_ color: UIColor, size: CGSize) -> UIImage {

        // create square image context with integral size
        let rect = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height).integral

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)

        // fill image with color
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(rect)

        // clean up
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    func drawTextToImageCentered(_ drawText: String) -> UIImage{
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.center
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        let textFontAttributes: [NSAttributedString.Key: Any] = [
            .font: fontAvatarInitials!,
            .foregroundColor: colorAvatarInitials,
            .paragraphStyle: paraStyle,
        ]
        
        let textSize = drawText.size(withAttributes: textFontAttributes)
        
        let imageRect = CGRect(x: 0, y: 0, width: size.width, height: size.height).integral
        draw(in: imageRect)
        
        let textRect = CGRect(x: 0, y: imageRect.size.height/2 - textSize.height/2, width: imageRect.size.width, height: imageRect.size.height).integral
        drawText.draw(in: textRect, withAttributes: textFontAttributes)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func cropped(_ rect: CGRect) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)

        draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()!

        UIGraphicsEndImageContext()
        return croppedImage
    }
    
    func squareImageWithSize(_ size: CGSize) -> UIImage {
        return croppedToSquare().resized(size)
    }
    
    func croppedToSquare() -> UIImage {
        let originalWidth  = size.width
        let originalHeight = size.height

        if originalWidth == originalHeight {
            return self
        }

        let shorterEdge = min(originalWidth, originalHeight)
        let posX = (originalWidth  - shorterEdge) / 2.0
        let posY = (originalHeight - shorterEdge) / 2.0
        return cropped(CGRect(x: posX, y: posY, width: shorterEdge, height: shorterEdge))
    }
    
    func resized(_ bounds: CGSize) -> UIImage {
        if size == bounds || size.height <= 0 || size.width <= 0 {
            return self
        }

        // Resulting image is `scalingFactor` times its current size.
        // `min` means fitting the image into the bounds, not necessarily filling them.
        let scalingFactor = min(bounds.width / size.width, bounds.height / size.height)
        let newSize = CGSize(width: size.width * scalingFactor, height: size.height * scalingFactor)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)

        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!

        UIGraphicsEndImageContext()
        return newImage
    }
    
}
