import SwiftUI
import Combine

struct PreviewImage: View {
    let image: UIImage
    let borderColor: Color
    let borderThickness: CGFloat
    let aspectRatio: AspectRatio
    
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var cancellable: AnyCancellable?
    
    private var cacheKey: String {
        // Change to use static method directly on ImageCache type
        ImageCache.makeKey(
            image: image,
            borderColor: borderColor,
            borderThickness: borderThickness,
            aspectRatio: aspectRatio
        )
    }
    
    var body: some View {
        Group {
            if let processedImage = processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: borderColor) { _, _ in loadImage() }
        .onChange(of: borderThickness) { _, _ in loadImage() }
        .onChange(of: aspectRatio) { _, _ in loadImage() }
    }
    
    private func loadImage() {
        cancellable?.cancel()
        
        if let cachedImage = ImageCache.shared.image(forKey: cacheKey) {
            self.processedImage = cachedImage
            return
        }
        
        isProcessing = true
        
        let currentCacheKey = self.cacheKey
        
        cancellable = Future<UIImage, Never> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    let processedImage = processAndAddBorder(
                        to: image,
                        color: UIColor(borderColor),
                        thickness: borderThickness,
                        aspectRatio: aspectRatio
                    )
                    promise(.success(processedImage))
                }
            }
        }
        .delay(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { processedImage in
            if currentCacheKey == cacheKey {
                self.processedImage = processedImage
                self.isProcessing = false
                ImageCache.shared.setImage(processedImage, forKey: currentCacheKey)
            }
        }
    }
    
    private func processAndAddBorder(to image: UIImage, color: UIColor, thickness: CGFloat, aspectRatio: AspectRatio) -> UIImage {
        let croppedImage = cropImage(image, to: aspectRatio.ratio)
        return addBorder(to: croppedImage, color: color, thickness: thickness, aspectRatio: aspectRatio)
    }
    
    private func cropImage(_ image: UIImage, to aspectRatio: CGFloat) -> UIImage {
        let imageAspect = image.size.width / image.size.height
        
        var drawRect: CGRect
        
        if imageAspect > aspectRatio {
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
    
    private func addBorder(to image: UIImage, color: UIColor, thickness: CGFloat, aspectRatio: AspectRatio) -> UIImage {
        let baseSize: CGFloat = 1080
        let targetSize: CGSize
        
        if aspectRatio.ratio > 1 {
            // Landscape
            targetSize = CGSize(width: baseSize, height: baseSize / aspectRatio.ratio)
        } else {
            // Portrait or Square
            targetSize = CGSize(width: baseSize * aspectRatio.ratio, height: baseSize)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            // Fill the entire image with the border color
            color.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate the image rect with border
            let imageRect = CGRect(
                x: thickness,
                y: thickness,
                width: targetSize.width - (thickness * 2),
                height: targetSize.height - (thickness * 2)
            )
            
            // Draw the image, maintaining its aspect ratio
            image.draw(in: imageRect)
        }
    }
}

struct PreviewImage_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "photo") {
            PreviewImage(
                image: image,
                borderColor: .white,
                borderThickness: 20,
                aspectRatio: .square
            )
        }
    }
}
