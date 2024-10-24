import UIKit
import SwiftUI

// MARK: - Cache Cost Calculator
protocol CacheCostCalculating {
    func cost(for image: UIImage) -> Int
}

struct DefaultCacheCostCalculator: CacheCostCalculating {
    func cost(for image: UIImage) -> Int {
        let bytesPerPixel = 4
        let totalPixels = Int(image.size.width * image.size.height)
        return totalPixels * bytesPerPixel
    }
}

// MARK: - Cache Entry
final class CacheEntry {
    let image: UIImage
    let timestamp: Date
    let cost: Int
    
    init(image: UIImage, cost: Int) {
        self.image = image
        self.timestamp = Date()
        self.cost = cost
    }
}

// MARK: - Image Cache
final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, CacheEntry>()
    private let queue = DispatchQueue(label: "com.bordergenius.imagecache")
    private let costCalculator: CacheCostCalculating
    private var memoryWarningObserver: NSObjectProtocol?
    
    // Configuration
    private let defaultMaxCostLimit = 1024 * 1024 * 100 // 100 MB
    private let defaultMaxTimeInCache: TimeInterval = 60 * 15 // 15 minutes
    
    // Stats tracking
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    init(costCalculator: CacheCostCalculating = DefaultCacheCostCalculator()) {
        self.costCalculator = costCalculator
        setupCache()
        setupNotifications()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func setImage(_ image: UIImage, forKey key: String) {
        queue.async {
            let cost = self.costCalculator.cost(for: image)
            let entry = CacheEntry(image: image, cost: cost)
            self.cache.setObject(entry, forKey: key as NSString, cost: cost)
        }
    }
    
    func image(forKey key: String) -> UIImage? {
        queue.sync {
            if let entry = cache.object(forKey: key as NSString) {
                // Check if entry has expired
                if Date().timeIntervalSince(entry.timestamp) > defaultMaxTimeInCache {
                    cache.removeObject(forKey: key as NSString)
                    missCount += 1
                    return nil
                }
                hitCount += 1
                return entry.image
            }
            missCount += 1
            return nil
        }
    }
    
    func removeImage(forKey key: String) {
        queue.async {
            self.cache.removeObject(forKey: key as NSString)
        }
    }
    
    func clearCache() {
        queue.async {
            self.cache.removeAllObjects()
            self.hitCount = 0
            self.missCount = 0
        }
    }
    
    // MARK: - Cache Management
    
    func adjustCacheLimits(maxCost: Int? = nil, maxCount: Int? = nil) {
        queue.async {
            if let maxCost = maxCost {
                self.cache.totalCostLimit = maxCost
            }
            if let maxCount = maxCount {
                self.cache.countLimit = maxCount
            }
        }
    }
    
    // MARK: - Statistics
    
    func getCacheStats() -> (hitCount: Int, missCount: Int, hitRate: Double) {
        queue.sync {
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0
            return (hitCount, missCount, hitRate)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        cache.totalCostLimit = defaultMaxCostLimit
        cache.countLimit = 100 // Maximum number of images to store
    }
    
    private func setupNotifications() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                self?.handleMemoryWarning()
            }
    }
    
    private func handleMemoryWarning() {
        queue.async {
            self.cache.removeAllObjects()
            self.hitCount = 0
            self.missCount = 0
        }
    }
}

// MARK: - Cache Key Generator
extension ImageCache {
    static func makeKey(
        image: UIImage,
        borderColor: Color,
        borderThickness: CGFloat,
        aspectRatio: AspectRatio
    ) -> String {
        // Convert SwiftUI Color to UIColor
        let uiColor = UIColor(borderColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorString = "\(red)-\(green)-\(blue)-\(alpha)"
        return "\(image.hashValue)-\(colorString)-\(borderThickness)-\(aspectRatio.display)"
    }
}

// MARK: - EditView Extension
extension ImageCache {
    struct ImageProcessingError: Error {
        let message: String
    }
    
    static func processImage(
        originalImage: UIImage,
        borderColor: Color,
        borderThickness: CGFloat,
        aspectRatio: AspectRatio,
        processAndAddBorder: (UIImage, UIColor, CGFloat, AspectRatio) -> UIImage
    ) -> UIImage {
        let processedImage = processAndAddBorder(
            originalImage,
            UIColor(borderColor),
            borderThickness,
            aspectRatio
        )
        return processedImage
    }
}
