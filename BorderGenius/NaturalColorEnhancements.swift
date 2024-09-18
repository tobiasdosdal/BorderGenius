import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class EnhancedColorAnalyzer {
    func analyzeImage(_ image: CIImage) -> EnhancedImageAnalysis {
        let featurePrintRequest = VNGenerateImageFeaturePrintRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let classificationRequest = VNClassifyImageRequest()
        
        let handler = VNImageRequestHandler(ciImage: image, orientation: .up)
        
        do {
            try handler.perform([featurePrintRequest, saliencyRequest, classificationRequest])
        } catch {
            print("Failed to perform Vision requests: \(error)")
            return EnhancedImageAnalysis()
        }
        
        let featurePrint = featurePrintRequest.results?.first as? VNFeaturePrintObservation
        let saliency = saliencyRequest.results?.first as? VNSaliencyImageObservation
        let classifications = classificationRequest.results as? [VNClassificationObservation]
        
        return EnhancedImageAnalysis(
            featurePrint: featurePrint,
            saliency: saliency,
            classifications: classifications ?? [],
            histogram: image.enhancedHistogram(),
            averageColor: image.enhancedAverageColor()
        )
    }
}

struct EnhancedImageAnalysis {
    let featurePrint: VNFeaturePrintObservation?
    let saliency: VNSaliencyImageObservation?
    let classifications: [VNClassificationObservation]
    let histogram: (midpoint: Double, range: Double)
    let averageColor: (red: Double, green: Double, blue: Double)
    
    init(featurePrint: VNFeaturePrintObservation? = nil,
         saliency: VNSaliencyImageObservation? = nil,
         classifications: [VNClassificationObservation] = [],
         histogram: (midpoint: Double, range: Double) = (0.5, 1.0),
         averageColor: (red: Double, green: Double, blue: Double) = (0, 0, 0)) {
        self.featurePrint = featurePrint
        self.saliency = saliency
        self.classifications = classifications
        self.histogram = histogram
        self.averageColor = averageColor
    }
}

extension ColorModification {
    mutating func enhanceBasedOn(_ analysis: EnhancedImageAnalysis) {
        // White Balance
        let (temperatureAdjustment, tintAdjustment) = calculateWhiteBalanceAdjustment(analysis)
        self.temp += temperatureAdjustment
        self.tint += tintAdjustment
        
        // Exposure
        let brightnessAdjustment = calculateExposureAdjustment(analysis)
        self.brightness += brightnessAdjustment
        
        // Contrast
        let contrastAdjustment = calculateContrastAdjustment(analysis)
        self.contrast += contrastAdjustment
        
        // Saturation and Vibrance
        let saturationAdjustment = calculateSaturationAdjustment(analysis)
        self.saturation += saturationAdjustment
        let vibranceAdjustment = calculateVibranceAdjustment(analysis)
        self.vibrance += vibranceAdjustment
        
        // Additional adjustments based on image content
        applyContentBasedAdjustments(analysis)
        
        // Ensure all values are within the valid range
        clampValues()
    }
    
    private func calculateWhiteBalanceAdjustment(_ analysis: EnhancedImageAnalysis) -> (Double, Double) {
        let averageColor = analysis.averageColor
        
        // Calculate color temperature based on red/blue ratio
        let redBlueRatio = averageColor.red / averageColor.blue
        let temperatureAdjustment = (redBlueRatio - 1) * 0.1 // Reduced scale factor
        
        // Calculate tint based on green/magenta balance
        let greenMagentaBalance = averageColor.green - (averageColor.red + averageColor.blue) / 2
        let tintAdjustment = greenMagentaBalance * 0.1 // Reduced scale factor
        
        return (temperatureAdjustment, tintAdjustment)
    }
    
    private func calculateExposureAdjustment(_ analysis: EnhancedImageAnalysis) -> Double {
        let midpoint = analysis.histogram.midpoint
        let adjustment = (0.5 - midpoint) * 0.5 // Reduced scale factor
        return adjustment
    }
    
    private func calculateContrastAdjustment(_ analysis: EnhancedImageAnalysis) -> Double {
        let range = analysis.histogram.range
        let targetRange = 0.7
        let adjustment = ((targetRange / range) - 1) * 0.1 // Reduced scale factor
        return adjustment
    }
    
    private func calculateSaturationAdjustment(_ analysis: EnhancedImageAnalysis) -> Double {
        let averageColor = analysis.averageColor
        let maxColor = max(averageColor.red, averageColor.green, averageColor.blue)
        let minColor = min(averageColor.red, averageColor.green, averageColor.blue)
        let currentSaturation = maxColor > 0 ? (maxColor - minColor) / maxColor : 0
        
        let targetSaturation = 0.5
        let adjustment = ((targetSaturation - currentSaturation) / 2) * 0.1 // Reduced scale factor
        return adjustment
    }
    
    private func calculateVibranceAdjustment(_ analysis: EnhancedImageAnalysis) -> Double {
        let averageColor = analysis.averageColor
        let average = (averageColor.red + averageColor.green + averageColor.blue) / 3
        let deviation = sqrt(
            pow(averageColor.red - average, 2) +
            pow(averageColor.green - average, 2) +
            pow(averageColor.blue - average, 2)
        ) / average
        
        let targetDeviation = 0.15
        let adjustment = (targetDeviation - deviation) * 0.5 // Reduced scale factor
        return adjustment
    }
    
    private mutating func applyContentBasedAdjustments(_ analysis: EnhancedImageAnalysis) {
        for classification in analysis.classifications.prefix(3) {
            switch classification.identifier {
            case "sunset", "sunrise":
                self.temp += 0.05
                self.saturation += 0.02
                self.vibrance += 0.02
            case "beach", "snow":
                self.brightness -= 0.02
                self.contrast += 0.02
            case "night", "dark":
                self.brightness += 0.05
                self.contrast += 0.02
            case "forest", "nature":
                self.vibrance += 0.02
                self.saturation += 0.02
            case "portrait", "person":
                self.vibrance += 0.01
                self.saturation -= 0.01
                self.contrast += 0.01
            default:
                break
            }
        }
    }
    
    private mutating func clampValues() {
        brightness = max(-1, min(1, brightness))
        contrast = max(-1, min(1, contrast))
        saturation = max(-1, min(1, saturation))
        vibrance = max(-1, min(1, vibrance))
        temp = max(-1, min(1, temp))
        tint = max(-1, min(1, tint))
        redAdjustment = max(-1, min(1, redAdjustment))
        greenAdjustment = max(-1, min(1, greenAdjustment))
        blueAdjustment = max(-1, min(1, blueAdjustment))
    }
}
extension CIImage {
    func enhancedHistogram() -> (midpoint: Double, range: Double) {
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
    
    func enhancedAverageColor() -> (red: Double, green: Double, blue: Double) {
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
