//
//  ColorModification.swift
//  BorderGenius
//
//  Created by Tobias Dosdal-feddersen on 17/09/2024.
//

import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct ColorModification: Equatable {
    var brightness: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var vibrance: Double = 0
    var lights: Double = 0
    var darks: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    var temp: Double = 0
    var tint: Double = 0
    var redAdjustment: Double = 0
    var greenAdjustment: Double = 0
    var blueAdjustment: Double = 0
    var hueAdjustment: Double = 0
}

func applyModification(to image: UIImage, with modification: ColorModification) -> UIImage {
    guard let cgImage = image.cgImage else { return image }
    let context = CIContext(options: nil)
    let ciImage = CIImage(cgImage: cgImage)
    
    var filter = ciImage
    
    // Apply brightness and contrast
    let colorControlsFilter = CIFilter.colorControls()
    colorControlsFilter.inputImage = filter
    colorControlsFilter.brightness = Float(modification.brightness)
    colorControlsFilter.contrast = Float(modification.contrast) + 1
    colorControlsFilter.saturation = Float(modification.saturation) + 1
    filter = colorControlsFilter.outputImage ?? filter
    
    // Apply vibrance
    let vibranceFilter = CIFilter.vibrance()
    vibranceFilter.inputImage = filter
    vibranceFilter.amount = Float(modification.vibrance)
    filter = vibranceFilter.outputImage ?? filter
    
    // Apply highlights and shadows (approximate using gamma adjustment)
    let gammaFilter = CIFilter.gammaAdjust()
    gammaFilter.inputImage = filter
    gammaFilter.power = Float(1 - modification.lights * 0.5)
    filter = gammaFilter.outputImage ?? filter
    
    gammaFilter.inputImage = filter
    gammaFilter.power = Float(1 + modification.darks * 0.5)
    filter = gammaFilter.outputImage ?? filter
    
    // Apply whites and blacks (approximate using exposure adjustment)
    let exposureFilter = CIFilter.exposureAdjust()
    exposureFilter.inputImage = filter
    exposureFilter.ev = Float(modification.whites)
    filter = exposureFilter.outputImage ?? filter
    
    exposureFilter.inputImage = filter
    exposureFilter.ev = Float(-modification.blacks)
    filter = exposureFilter.outputImage ?? filter
    
    // Apply temperature and tint
    let temperatureAndTintFilter = CIFilter.temperatureAndTint()
    temperatureAndTintFilter.inputImage = filter
    temperatureAndTintFilter.neutral = CIVector(x: 6500 + 1500 * modification.temp, y: 0 + 150 * modification.tint)
    filter = temperatureAndTintFilter.outputImage ?? filter
    
    // Apply hue adjustment
    let hueAdjustFilter = CIFilter.hueAdjust()
    hueAdjustFilter.inputImage = filter
    hueAdjustFilter.angle = Float(modification.hueAdjustment * .pi)
    filter = hueAdjustFilter.outputImage ?? filter
    
    // Apply individual color channel adjustments
    let colorMatrixFilter = CIFilter.colorMatrix()
    colorMatrixFilter.inputImage = filter
    let redVector = CIVector(x: 1 + CGFloat(Float(modification.redAdjustment)), y: 0, z: 0, w: 0)
    let greenVector = CIVector(x: 0, y: 1 + CGFloat(Float(modification.greenAdjustment)), z: 0, w: 0)
    let blueVector = CIVector(x: 0, y: 0, z: 1 + CGFloat(Float(modification.blueAdjustment)), w: 0)
    let alphaVector = CIVector(x: 0, y: 0, z: 0, w: 1)
    colorMatrixFilter.rVector = redVector
    colorMatrixFilter.gVector = greenVector
    colorMatrixFilter.bVector = blueVector
    colorMatrixFilter.aVector = alphaVector
    filter = colorMatrixFilter.outputImage ?? filter
    
    guard let outputCGImage = context.createCGImage(filter, from: filter.extent) else {
        return image
    }
    
    return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
}

