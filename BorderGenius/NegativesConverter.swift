import SwiftUI
import PhotosUI
import Photos
import UIKit
import Vision
import CoreImage

enum ColorProfile: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case colorNegative = "Color Negative"
    case blackAndWhite = "Black & White"
    case slide = "Slide Film"
    case cineStill800T = "CineStill 800T"
    case kodakPortra400 = "Kodak Portra 400"
    case fujiProvia100F = "Fuji Provia 100F"
    case ilfordHP5 = "Ilford HP5"
    
    var id: String { self.rawValue }
}

extension CIImage {
    func histogram() -> (midpoint: Double, range: Double) {
        let inputImage = self.clampedToExtent()
        let extent = inputImage.extent
        
        guard let histogramFilter = CIFilter(name: "CIAreaHistogram") else {
            return (midpoint: 0.5, range: 1.0)
        }
        
        histogramFilter.setValue(inputImage, forKey: kCIInputImageKey)
        histogramFilter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        histogramFilter.setValue(256, forKey: "inputCount")
        histogramFilter.setValue(1.0, forKey: "inputScale")
        
        guard let histogramImage = histogramFilter.outputImage else {
            return (midpoint: 0.5, range: 1.0)
        }
        
        let context = CIContext(options: nil)
        var histogramData = [Float](repeating: 0, count: 256)
        context.render(histogramImage,
                       toBitmap: &histogramData,
                       rowBytes: 256 * MemoryLayout<Float>.size,
                       bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
                       format: .Rf,
                       colorSpace: nil)
        
        var totalPixels: Float = 0
        var weightedSum: Float = 0
        var minIntensity: Float = 256
        var maxIntensity: Float = 0
        
        for (i, count) in histogramData.enumerated() {
            totalPixels += count
            weightedSum += Float(i) * count
            if count > 0 {
                minIntensity = min(minIntensity, Float(i))
                maxIntensity = max(maxIntensity, Float(i))
            }
        }
        
        let midpoint = Double(weightedSum / (totalPixels * 255))
        let range = Double((maxIntensity - minIntensity) / 255)
        
        return (midpoint: midpoint, range: range)
    }
    
    func averageColor() -> (red: Double, green: Double, blue: Double) {
        let extentVector = CIVector(x: self.extent.origin.x, y: self.extent.origin.y, z: self.extent.size.width, w: self.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector]) else {
            return (0, 0, 0)
        }
        
        guard let outputImage = filter.outputImage else {
            return (0, 0, 0)
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return (Double(bitmap[0]) / 255.0, Double(bitmap[1]) / 255.0, Double(bitmap[2]) / 255.0)
    }
}

class ImageAnalyzer {
    func analyze(_ image: CIImage) -> ImageAnalysis {
        return ImageAnalysis(
            exposureAdjustment: calculateExposureAdjustment(image),
            temperature: calculateColorTemperature(image),
            tint: calculateTint(image),
            contrastAdjustment: calculateContrastAdjustment(image),
            saturationAdjustment: calculateSaturationAdjustment(image),
            vibranceAdjustment: calculateVibranceAdjustment(image)
        )
    }
    
    private func calculateExposureAdjustment(_ image: CIImage) -> Double {
        let histogram = image.histogram()
        let midpoint = histogram.midpoint
        
        // Adjust exposure to bring the midpoint closer to 0.5
        let adjustment = 0.5 - midpoint
        return max(-2.0, min(2.0, adjustment * 4))  // Scale and clamp the adjustment
    }
    
    private func calculateColorTemperature(_ image: CIImage) -> Double {
        let averageColor = image.averageColor()
        
        // Calculate color temperature based on red/blue ratio
        let redBlueRatio = averageColor.red / averageColor.blue
        
        // Map the ratio to a temperature range (roughly 2000K to 12000K)
        let temperature = 4000 + (redBlueRatio - 1) * 4000
        
        return max(2000, min(12000, temperature))
    }
    
    private func calculateTint(_ image: CIImage) -> Double {
        let averageColor = image.averageColor()
        
        // Calculate tint based on green/magenta balance
        let greenMagentaBalance = averageColor.green - (averageColor.red + averageColor.blue) / 2
        
        // Map the balance to a tint range (-150 to 150)
        return max(-150, min(150, greenMagentaBalance * 300))
    }
    
    private func calculateContrastAdjustment(_ image: CIImage) -> Double {
        let histogram = image.histogram()
        let range = histogram.range
        
        // Adjust contrast based on the histogram range
        let targetRange = 0.9  // Desired range for good contrast
        let adjustment = targetRange / range
        
        return max(0.5, min(1.5, adjustment))
    }
    
    private func calculateSaturationAdjustment(_ image: CIImage) -> Double {
        let averageColor = image.averageColor()
        
        // Calculate current saturation
        let maxColor = Swift.max(averageColor.red, averageColor.green, averageColor.blue)
        let minColor = Swift.min(averageColor.red, averageColor.green, averageColor.blue)
        
        // Avoid division by zero
        guard maxColor > 0 else { return 1.0 }
        
        let currentSaturation = (maxColor - minColor) / maxColor
        
        // Avoid division by zero
        guard currentSaturation > 0 else { return 1.5 }
        
        // Adjust saturation to bring it closer to a target value
        let targetSaturation = 0.5
        let adjustment = targetSaturation / currentSaturation
        
        return Swift.max(0.5, Swift.min(1.5, adjustment))
    }
    
    private func calculateVibranceAdjustment(_ image: CIImage) -> Double {
        let averageColor = image.averageColor()
        
        // Calculate color richness
        let average = (averageColor.red + averageColor.green + averageColor.blue) / 3
        let deviation = sqrt(
            pow(averageColor.red - average, 2) +
            pow(averageColor.green - average, 2) +
            pow(averageColor.blue - average, 2)
        ) / average
        
        // Adjust vibrance based on color richness
        let targetDeviation = 0.2
        let adjustment = (targetDeviation - deviation) * 5
        
        return max(-1.0, min(1.0, adjustment))
    }
}

struct ImageAnalysis {
    let exposureAdjustment: Double
    let temperature: Double
    let tint: Double
    let contrastAdjustment: Double
    let saturationAdjustment: Double
    let vibranceAdjustment: Double
}

struct ProfileCardCarousel: View {
    let profiles: [ColorProfile]
    @Binding var selectedProfile: ColorProfile
    let onSelect: (ColorProfile) -> Void
    
    @State private var cardWidth: CGFloat = 120
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 15) {
                ForEach(profiles) { profile in
                    ProfileCard(profile: profile, isSelected: profile == selectedProfile)
                        .frame(width: cardWidth)
                        .onTapGesture {
                            selectedProfile = profile
                            onSelect(profile)
                        }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 150)
    }
}

struct ProfileCard: View {
    let profile: ColorProfile
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                
                Image(systemName: "photo.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
            }
            .frame(height: 100)
            
            Text(profile.rawValue)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
    }
}

struct NegativeConverterView: View {
    @State private var selectedAsset: PHAsset?
    @State private var sourceImage: UIImage?
    @State private var convertedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isConverting = false
    @State private var selectedProfile: ColorProfile = .standard
    @State private var isShowingColorModification = false
    @State private var colorModification = ColorModification()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Negative to Positive Converter")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top)
                
                ProfileCardCarousel(
                    profiles: ColorProfile.allCases,
                    selectedProfile: $selectedProfile,
                    onSelect: { _ in updatePreview() }
                )
                
                ZStack {
                    if let image = convertedImage ?? sourceImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                            .overlay(
                                Text("No image selected")
                                    .foregroundColor(.white)
                            )
                    }
                    
                    if isConverting {
                        Color.black.opacity(0.5)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .frame(height: 300)
                
                HStack {
                    Button(action: {
                        isShowingImagePicker = true
                    }) {
                        Text("Select Image")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isShowingColorModification = true
                    }) {
                        Text("Modify Colors")
                            .padding()
                            .background(convertedImage != nil ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(convertedImage == nil)
                    
                    Button("Enhance Colors") {
                        applyEnhancedColorAdjustment()
                    }
                    
                    Button(action: saveImage) {
                        Text("Save")
                            .padding()
                            .background(convertedImage != nil ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(convertedImage == nil)
                }
                .padding()
                
                Spacer()
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(assets: Binding(
                get: { selectedAsset.map { [$0] } ?? [] },
                set: { assets in
                    if let asset = assets.first {
                        self.selectedAsset = asset
                        loadImage(from: asset)
                    }
                }
            ))
        }
        .sheet(isPresented: $isShowingColorModification) {
            ColorModificationView(
                modification: $colorModification,
                previewImage: $convertedImage,
                onApply: {
                    applyColorModification()
                    isShowingColorModification = false
                }
            )
        }
    }
    
    func applyEnhancedColorAdjustment() {
        guard let currentImage = convertedImage,
              let ciImage = CIImage(image: currentImage) else { return }
        
        let analyzer = EnhancedColorAnalyzer()
        let analysis = analyzer.analyzeImage(ciImage)
        
        // Note that we're creating a new instance here
        var enhancedModification = self.colorModification
        enhancedModification.enhanceBasedOn(analysis)
        
        // Update the colorModification property
        self.colorModification = enhancedModification
        
        // Apply the updated colorModification to your image
        updatePreview()
    }
    
    private func loadImage(from asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .original
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.sourceImage = image
                    self.updatePreview()
                }
            }
        }
    }
    
    private func updatePreview() {
        guard let sourceImage = sourceImage else { return }
        isConverting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let convertedImage = NegativeConverter.convertToPositive(sourceImage, profile: selectedProfile)
            
            DispatchQueue.main.async {
                self.convertedImage = convertedImage
                self.isConverting = false
                self.applyColorModification()
            }
        }
    }
    
    private func applyColorModification() {
            guard let image = convertedImage else { return }
            isConverting = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                let modifiedImage = applyModification(to: image, with: colorModification)
                
                DispatchQueue.main.async {
                    self.convertedImage = modifiedImage
                    self.isConverting = false
                }
            }
        }
        
        private func autoEditImage() {
            guard let image = convertedImage else { return }
            isConverting = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                let autoEditedImage = performAutoEdit(image: image)
                
                DispatchQueue.main.async {
                    self.convertedImage = autoEditedImage
                    self.isConverting = false
                }
            }
        }
        
        private func performAutoEdit(image: UIImage) -> UIImage {
            guard let cgImage = image.cgImage else { return image }
            
            let context = CIContext(options: nil)
            var ciImage = CIImage(cgImage: cgImage)
            
            // 1. Analyze image
            let analyzer = ImageAnalyzer()
            let analysis = analyzer.analyze(ciImage)
            
            // 2. Apply auto adjustments based on analysis
            // Auto Exposure
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = ciImage
            exposureFilter.ev = Float(analysis.exposureAdjustment)
            ciImage = exposureFilter.outputImage ?? ciImage
            
            // Auto White Balance
            let temperatureAndTintFilter = CIFilter.temperatureAndTint()
            temperatureAndTintFilter.inputImage = ciImage
            temperatureAndTintFilter.neutral = CIVector(x: CGFloat(analysis.temperature), y: CGFloat(analysis.tint))
            ciImage = temperatureAndTintFilter.outputImage ?? ciImage
            
            // Auto Contrast
            let contrastFilter = CIFilter.colorControls()
            contrastFilter.inputImage = ciImage
            contrastFilter.contrast = Float(analysis.contrastAdjustment)
            ciImage = contrastFilter.outputImage ?? ciImage
            
            // Auto Saturation
            let saturationFilter = CIFilter.colorControls()
            saturationFilter.inputImage = ciImage
            saturationFilter.saturation = Float(analysis.saturationAdjustment)
            ciImage = saturationFilter.outputImage ?? ciImage
            
            // Auto Vibrance
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = ciImage
            vibranceFilter.amount = Float(analysis.vibranceAdjustment)
            ciImage = vibranceFilter.outputImage ?? ciImage
            
            // 3. Convert back to UIImage
            guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                return image
            }
            
            return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        private func saveImage() {
            guard let convertedImage = convertedImage else { return }
            UIImageWriteToSavedPhotosAlbum(convertedImage, nil, nil, nil)
            // You might want to add some feedback here, like a temporary overlay message
        }
    }

    struct NegativeConverter {
        static func convertToPositive(_ image: UIImage, profile: ColorProfile) -> UIImage {
            guard let cgImage = image.cgImage else { return image }
            
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8
            
            var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
            
            guard let context = CGContext(data: &rawData,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: bitsPerComponent,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return image
            }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            for i in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
                let r = Double(rawData[i])
                let g = Double(rawData[i + 1])
                let b = Double(rawData[i + 2])
                
                var (newR, newG, newB): (Double, Double, Double)
                
                switch profile {
                case .standard:
                    newR = 255 - r
                    newG = 255 - g
                    newB = 255 - b
                case .colorNegative:
                    // Adjust for orange mask and color balance
                    newR = 255 - (r * 1.1)
                    newG = 255 - (g * 1.0)
                    newB = 255 - (b * 0.9)
                case .blackAndWhite:
                    // Convert to grayscale and invert
                    let gray = (r * 0.299 + g * 0.587 + b * 0.114)
                    newR = 255 - gray
                    newG = 255 - gray
                    newB = 255 - gray
                case .slide:
                    // Slide film typically needs less adjustment
                    newR = 255 - (r * 0.9)
                    newG = 255 - (g * 0.9)
                    newB = 255 - (b * 0.9)
                case .cineStill800T:
                    // CineStill 800T: Tungsten-balanced film with removed remjet layer
                    // Adjust color balance to compensate for tungsten light and simulate removed remjet
                    newR = 255 - (r * 1.15) // Boost reds slightly to counteract tungsten balance
                    newG = 255 - (g * 1.0)  // Keep greens neutral
                    newB = 255 - (b * 0.85) // Reduce blues to warm up the image
                    
                    // Increase overall exposure slightly
                    let exposureBoost = 1.1
                    newR *= exposureBoost
                    newG *= exposureBoost
                    newB *= exposureBoost
                    
                    // Simulate halation effect (reddish glow in highlights due to removed remjet layer)
                    let halationThreshold = 220.0
                    if (newR + newG + newB) / 3 > halationThreshold {
                        let halationStrength = 0.2
                        newR += (255 - newR) * halationStrength
                    }
                    
                    // Slightly reduce contrast in shadows to simulate cinematic look
                    let shadowThreshold = 50.0
                    if (newR + newG + newB) / 3 < shadowThreshold {
                        let shadowLift = 10.0
                        newR += shadowLift
                        newG += shadowLift
                        newB += shadowLift
                    }
                case .kodakPortra400:
                    // Kodak Portra 400: Known for its natural, slightly warm skin tones
                    newR = 255 - (r * 1.05) // Slightly boost reds for warmth
                    newG = 255 - (g * 0.95) // Slightly reduce greens
                    newB = 255 - (b * 0.9)  // Reduce blues more for overall warmth
                case .fujiProvia100F:
                    // Fuji Provia 100F: Known for its vivid colors and high contrast
                    newR = 255 - (r * 1.1)  // Boost reds
                    newG = 255 - (g * 1.05) // Slightly boost greens
                    newB = 255 - (b * 1.1)  // Boost blues
                    // Increase contrast
                    newR = (newR - 128) * 1.2 + 128
                    newG = (newG - 128) * 1.2 + 128
                    newB = (newB - 128) * 1.2 + 128
                case .ilfordHP5:
                    // Ilford HP5: High-contrast black and white film
                    let gray = (r * 0.299 + g * 0.587 + b * 0.114)
                    let contrastBoost = 1.2
                    newR = 255 - ((gray - 128) * contrastBoost + 128)
                    newG = newR
                    newB = newR
                }
                
                rawData[i] = UInt8(min(max(newR, 0), 255))
                rawData[i + 1] = UInt8(min(max(newG, 0), 255))
                rawData[i + 2] = UInt8(min(max(newB, 0), 255))
            }
            
            guard let outputCGImage = context.makeImage() else {
                return image
            }
            
            return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
    }

    struct NegativeConverterView_Previews: PreviewProvider {
        static var previews: some View {
            NegativeConverterView()
        }
    }
