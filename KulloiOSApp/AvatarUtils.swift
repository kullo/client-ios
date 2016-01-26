/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import CoreImage

extension UIImageView {
    
    func showAsCircle() {
        self.layer.borderWidth = 0.0
        self.layer.masksToBounds = false
        self.layer.cornerRadius = self.frame.size.width/2
        self.clipsToBounds = true
    }
}

extension UIImage {
    
    class func combineImages(images: [UIImage], targetSize: CGSize) -> UIImage {
        
        // create square image context with integral size
        let rect = CGRectIntegral(CGRectMake(0.0, 0.0, targetSize.width, targetSize.height))
        let outWidth = rect.width
        let outHeight = rect.height
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        
        switch images.count {
        case 0:
            break
        case 1:
            return images[0]
        case 2:
            let image1 = images[0].squareImageWithSize(targetSize)
            let image2 = images[1].squareImageWithSize(targetSize)
           
            let cropRect1 = CGRectMake(image1.size.width/4, image1.size.height/4, image1.size.width/2, image1.size.height/2)
            let cropRect2 = CGRectMake(image2.size.width/4, image2.size.height/4, image2.size.width/2, image2.size.height/2)
            
            image1.crop(cropRect1)
            image2.crop(cropRect2)
            
            let dstLeft = CGRectMake(-outWidth/4, 0, outWidth, outHeight)
            let dstRight = CGRectMake(outWidth/2, 0, outWidth, outHeight)
            
            image1.drawInRect(dstLeft)
            image2.drawInRect(dstRight)
            
        case 3:
            let originalImage1 = images[0]
            let originalImage2 = images[1]
            let originalImage3 = images[2]
            
            let image1 = originalImage1.squareImageWithSize(targetSize)
            let image2 = originalImage2.squareImageWithSize(targetSize)
            let image3 = originalImage3.squareImageWithSize(targetSize)
            
            let cropRect1 = CGRectMake(image1.size.width/4, image1.size.height/4, image1.size.width/2, image1.size.height/2)
            let cropRect2 = CGRectMake(image2.size.width/4, image2.size.height/4, image2.size.width/2, image2.size.height/2)
            let cropRect3 = CGRectMake(image3.size.width/4, image3.size.height/4, image3.size.width/2, image3.size.height/2)
            
            image1.crop(cropRect1)
            image2.crop(cropRect2)
            image3.crop(cropRect3)
            
            let dstLeft = CGRectMake(-outWidth/4, 0, outWidth, outHeight)
            let dstRightTop = CGRectMake(outWidth/2, 0, outWidth/2, outHeight/2)
            let dstRightBottom = CGRectMake(outWidth/2, outWidth/2, outWidth/2, outHeight/2)
            
            image1.drawInRect(dstLeft)
            image2.drawInRect(dstRightTop)
            image3.drawInRect(dstRightBottom)
            
        default:
            let originalImage1 = images[0]
            let originalImage2 = images[1]
            let originalImage3 = images[2]
            let originalImage4 = images[3]
            
            let image1 = originalImage1.squareImageWithSize(targetSize)
            let image2 = originalImage2.squareImageWithSize(targetSize)
            let image3 = originalImage3.squareImageWithSize(targetSize)
            let image4 = originalImage4.squareImageWithSize(targetSize)

            let cropRect1 = CGRectMake(image1.size.width/4, image1.size.height/4, image1.size.width/2, image1.size.height/2)
            let cropRect2 = CGRectMake(image2.size.width/4, image2.size.height/4, image2.size.width/2, image2.size.height/2)
            let cropRect3 = CGRectMake(image3.size.width/4, image3.size.height/4, image3.size.width/2, image3.size.height/2)
            let cropRect4 = CGRectMake(image4.size.width/4, image4.size.height/4, image4.size.width/2, image4.size.height/2)
            
            image1.crop(cropRect1)
            image2.crop(cropRect2)
            image3.crop(cropRect3)
            image4.crop(cropRect4)
            
            let dstLeftTop = CGRectMake(0, 0, outWidth/2, outHeight/2)
            let dstLeftBottom = CGRectMake(0, outHeight/2, outWidth/2, outHeight/2)
            let dstRightTop = CGRectMake(outWidth/2, 0, outWidth/2, outHeight/2)
            let dstRightBottom = CGRectMake(outWidth/2, outHeight/2, outWidth/2, outHeight/2)
            
            image1.drawInRect(dstLeftTop)
            image2.drawInRect(dstRightTop)
            image3.drawInRect(dstLeftBottom)
            image4.drawInRect(dstRightBottom)
        }
        
        // clean up
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
        
    }
    
    class func imageWithColor(color: UIColor, size: CGSize) -> UIImage {

        // create square image context with integral size
        let rect = CGRectIntegral(CGRectMake(0.0, 0.0, size.width, size.height))

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)

        // fill image with color
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, rect)

        // clean up
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func drawTextToImageCentered(drawText: NSString) -> UIImage{
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.Center
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        let textFontAttributes = [
            NSFontAttributeName: fontAvatarInitials!,
            NSForegroundColorAttributeName: colorAvatarInitials,
            NSParagraphStyleAttributeName: paraStyle
        ]
        
        let textSize = drawText.sizeWithAttributes(textFontAttributes)
        
        let imageRect = CGRectIntegral(CGRectMake(0, 0, size.width, size.height))
        drawInRect(imageRect)
        
        let textRect = CGRectIntegral(CGRectMake(0, imageRect.size.height/2 - textSize.height/2, imageRect.size.width, imageRect.size.height))
        drawText.drawInRect(textRect, withAttributes: textFontAttributes)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func crop(rect: CGRect) -> UIImage {

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        drawAtPoint(CGPointMake(-rect.origin.x, -rect.origin.y))
        
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return croppedImage
    }
    
    func squareImageWithSize(size: CGSize) -> UIImage {
        return squareImage().resizeImage(size)
    }
    
    func squareImage() -> UIImage {
        let originalWidth  = size.width
        let originalHeight = size.height
        
        if originalWidth == originalHeight {
            return self
        }
        
        var edge: CGFloat
        if originalWidth > originalHeight {
            edge = originalHeight
        } else {
            edge = originalWidth
        }
        
        let posX = (originalWidth  - edge) / 2.0
        let posY = (originalHeight - edge) / 2.0
        
        let cropSquare = CGRectMake(posX, posY, edge, edge)
        
        let imageRef = CGImageCreateWithImageInRect(self.CGImage, cropSquare)
        return UIImage(CGImage: imageRef!, scale: scale, orientation: imageOrientation)
    }
    
    func resizeImage(targetSize: CGSize) -> UIImage {
        if size == targetSize {
            return self
        }
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSizeMake(size.width * heightRatio, size.height * heightRatio)
        } else {
            newSize = CGSizeMake(size.width * widthRatio,  size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRectMake(0, 0, newSize.width, newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        drawInRect(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }

    
}
