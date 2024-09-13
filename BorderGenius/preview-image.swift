import SwiftUI
import Combine

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
}

struct PreviewImage: View {
    let image: UIImage
    let borderColor: Color
    let borderThickness: CGFloat
    let orientation: PostOrientation
    let aspectRatio: AspectRatio
    
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var cancellable: AnyCancellable?
    
    private var cacheKey: String {
        "\(image.hashValue)-\(borderColor.hashValue)-\(borderThickness)-\(orientation.rawValue)-\(aspectRatio.display)"
    }
    
    private var size: CGSize {
        let baseWidth: CGFloat = 1080 // Instagram's recommended width
        let height: CGFloat
        
        if orientation == .portrait {
            height = baseWidth / aspectRatio.ratio
        } else {
            height = baseWidth * aspectRatio.ratio
        }
        
        return CGSize(width: baseWidth, height: height)
    }
    
    var body: some View {
        Group {
            if let processedImage = processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFit()
            } else if isProcessing {
                ProgressView()
            } else {
                Color.gray
            }
        }
        .aspectRatio(aspectRatio.ratio, contentMode: .fit)
        .onAppear(perform: loadImage)
        .onChange(of: borderColor) { _ in loadImage() }
        .onChange(of: borderThickness) { _ in loadImage() }
        .onChange(of: orientation) { _ in loadImage() }
        .onChange(of: aspectRatio) { _ in loadImage() }
    }
    
    private func loadImage() {
        cancellable?.cancel()
        
        if let cachedImage = ImageCache.shared.get(forKey: cacheKey) {
            self.processedImage = cachedImage
            return
        }
        
        isProcessing = true
        
        let currentCacheKey = self.cacheKey
        let currentSize = self.size
        
        cancellable = Future<UIImage, Never> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                let downsampledImage = downsample(image: image, to: currentSize)
                let processedImage = addBorder(to: downsampledImage, color: UIColor(borderColor), thickness: borderThickness, size: currentSize)
                promise(.success(processedImage))
            }
        }
        .delay(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { processedImage in
            if currentCacheKey == cacheKey {
                self.processedImage = processedImage
                self.isProcessing = false
                ImageCache.shared.set(processedImage, forKey: currentCacheKey)
            }
        }
    }
    
    private func downsample(image: UIImage, to size: CGSize) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let data = image.jpegData(compressionQuality: 0.5),
              let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return image
        }
        
        let maxDimensionInPixels = max(size.width, size.height)
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return image
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    private func addBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        // Draw border
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw image
        let imageRect = CGRect(x: thickness, y: thickness,
                               width: size.width - (thickness * 2),
                               height: size.height - (thickness * 2))
        image.draw(in: imageRect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

}
