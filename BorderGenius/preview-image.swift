import SwiftUI

struct PreviewImage: View {
    let image: UIImage
    let borderColor: Color
    let borderThickness: CGFloat
    let size: InstagramSize
    
    var body: some View {
        Image(uiImage: processAndAddBorder(to: image, color: UIColor(borderColor), thickness: borderThickness, size: size))
            .resizable()
            .scaledToFit()
    }
    
    func processAndAddBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: InstagramSize) -> UIImage {
        let croppedImage = cropImage(image, to: size)
        return addBorder(to: croppedImage, color: color, thickness: thickness, size: size.size)
    }
    
    func cropImage(_ image: UIImage, to size: InstagramSize) -> UIImage {
        let aspectRatio = size.aspectRatio
        let imageAspectRatio = image.size.width / image.size.height
        
        var drawRect: CGRect
        
        if imageAspectRatio > aspectRatio {
            // Image is wider, crop the sides
            let newWidth = image.size.height * aspectRatio
            let xOffset = (image.size.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: image.size.height)
        } else {
            // Image is taller, crop the top and bottom
            let newHeight = image.size.width / aspectRatio
            let yOffset = (image.size.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: image.size.width, height: newHeight)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: drawRect.size, format: format)
        
        return renderer.image { context in
            image.draw(at: CGPoint(x: -drawRect.origin.x, y: -drawRect.origin.y))
        }
    }
    
    func addBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { context in
            // Fill the entire image with the border color
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Calculate the size for the image after applying the border
            let imageRect = CGRect(x: thickness, y: thickness, width: size.width - (thickness * 2), height: size.height - (thickness * 2))
            
            // Draw the image
            image.draw(in: imageRect)
        }
    }
}

struct PreviewImage_Previews: PreviewProvider {
    static var previews: some View {
        PreviewImage(image: UIImage(systemName: "photo")!, borderColor: .white, borderThickness: 20, size: .square)
    }
}
