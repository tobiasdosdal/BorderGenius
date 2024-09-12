import SwiftUI
import Photos
import ColorfulX
import Combine

struct EditView: View {
    @Binding var imageAssets: [PHAsset]
    @State private var borderColor: Color = .white
    @State private var borderThickness: CGFloat = 20
    @State private var selectedSize: InstagramSize = .square
    @State private var processedImages: [Int: UIImage] = [:]
    @State private var originalImages: [Int: UIImage] = [:]
    @State private var previewImages: [Int: UIImage] = [:]
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedImageIndex: Int = 0
    @State private var isLoading = false  // Add this line
    @State private var isSaving = false
    @Environment(\.presentationMode) var presentationMode
    
    
    // ColorfulX properties (unchanged)
    @State var colors: [Color] = ColorfulPreset.neon.colors
    @AppStorage("speed") var speed: Double = 0.2
    @AppStorage("noise") var noise: Double = 5.0
    @AppStorage("duration") var duration: TimeInterval = 10.0

    var body: some View {
        NavigationView {
            ZStack {
                ColorfulView(color: $colors, speed: $speed, noise: $noise)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    if imageAssets.isEmpty {
                        Text("No images remaining")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        Button(action: { deleteImage(at: selectedImageIndex) }) {
                            Text("Remove Current Image")
                                .foregroundColor(.red)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(Color.clear)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.red, lineWidth: 1))
                        }
                        
                        // Image slider
                        TabView(selection: $selectedImageIndex) {
                            ForEach(Array(imageAssets.enumerated()), id: \.offset) { index, _ in
                                ImageView(processedImage: previewImages[index])
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .onChange(of: selectedImageIndex) { _ in
                            updateCurrentPreviewImage()
                        }
                        
                        // Controls
                        VStack(spacing: 20) {
                            CustomSegmentedPicker(selectedSize: $selectedSize)
                                .padding()
                                .frame(maxWidth: 400) // Adjust this value as needed
                                .background(Color.clear)

                            
                            ColorPicker("Border Color", selection: $borderColor)
                                .foregroundColor(.white)
                            
                            VStack {
                                Text("Border Thickness: \(Int(borderThickness)) px")
                                    .foregroundStyle(Color(.white))
                                Slider(value: $borderThickness, in: 0...200, step: 1)
                            }
                        }
                        .padding()
                        
                        if isSaving {
                            ProgressView("Saving images...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .foregroundColor(.white)
                        }
                    }
                }
                        .navigationBarTitle("", displayMode: .inline)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarItems(
                            //leading: Button("Done") { presentationMode.wrappedValue.dismiss() },
                            trailing: Button(action: saveImagesToPhotos) {
                                Image(systemName: "square.and.arrow.down")
                            }
                                .disabled(isSaving || imageAssets.isEmpty)
                        )
                        .alert(isPresented: $showingAlert) {
                            Alert(
                                title: Text("Save to Photos"),
                                message: Text(alertMessage),
                                dismissButton: .default(Text("OK")) {
                                    if imageAssets.isEmpty {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            )
                }
            }
        }
        .onAppear(perform: loadOriginalImages)
        .onChange(of: borderColor) { _ in updateCurrentPreviewImage() }
        .onChange(of: borderThickness) { _ in updateCurrentPreviewImage() }
        .onChange(of: selectedSize) { _ in updateCurrentPreviewImage() }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Save to Photos"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func loadOriginalImages() {
        isLoading = true
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 1000, height: 1000) // Adjust based on your needs
        
        for (index, asset) in imageAssets.enumerated() {
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("Error loading image: \(error.localizedDescription)")
                    // Handle error (e.g., show an alert to the user)
                } else if let image = image {
                    DispatchQueue.global(qos: .userInitiated).async {
                        autoreleasepool {
                            let downsampledImage = self.downsampleImage(image: image, to: targetSize)
                            DispatchQueue.main.async {
                                self.originalImages[index] = downsampledImage
                                self.updatePreviewImage(at: index)
                                if index == self.imageAssets.count - 1 {
                                    self.isLoading = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 3. Process images in batches
    private func processImagesInBatches() {
        let batchSize = 3 // Adjust based on your app's performance
        
        for i in stride(from: 0, to: imageAssets.count, by: batchSize) {
            let end = min(i + batchSize, imageAssets.count)
            let batch = Array(imageAssets[i..<end])
            
            autoreleasepool {
                for (index, asset) in batch.enumerated() {
                    processImage(asset, at: i + index)
                }
            }
        }
    }
    
    private func processImage(_ asset: PHAsset, at index: Int) {
        guard let originalImage = originalImages[index] else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let processedImage = self.processAndAddBorder(to: originalImage, color: UIColor(self.borderColor), thickness: self.borderThickness, size: self.selectedSize)
                DispatchQueue.main.async {
                    self.previewImages[index] = processedImage
                }
            }
        }
    }
    
    private func downsampleImage(image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        let scaleFactor = max(targetSize.width / size.width, targetSize.height / size.height)
        
        if scaleFactor >= 1 {
            return image // No need to downsample
        }
        
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }


    private func updateCurrentPreviewImage() {
        updatePreviewImage(at: selectedImageIndex)
    }

    private func updatePreviewImage(at index: Int) {
        guard let originalImage = originalImages[index] else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let processedImage = self.processAndAddBorder(to: originalImage, color: UIColor(self.borderColor), thickness: self.borderThickness, size: self.selectedSize)
                DispatchQueue.main.async {
                    self.previewImages[index] = processedImage
                }
            }
        }
    }
    
    private func deleteImage(at index: Int) {
        guard index < imageAssets.count else { return }
        imageAssets.remove(at: index)
        processedImages.removeValue(forKey: index)
        originalImages.removeValue(forKey: index)
        previewImages.removeValue(forKey: index)
        
        // Shift the remaining images
        for i in index..<imageAssets.count {
            processedImages[i] = processedImages.removeValue(forKey: i + 1)
            originalImages[i] = originalImages.removeValue(forKey: i + 1)
            previewImages[i] = previewImages.removeValue(forKey: i + 1)
        }
        
        if selectedImageIndex >= imageAssets.count {
            selectedImageIndex = max(imageAssets.count - 1, 0)
        }
    }

    private func saveImagesToPhotos() {
            isSaving = true
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    DispatchQueue.global(qos: .userInitiated).async {
                        var savedCount = 0
                        for (index, originalImage) in self.originalImages {
                            let processedImage = self.processAndAddBorder(to: originalImage, color: UIColor(self.borderColor), thickness: self.borderThickness, size: self.selectedSize)
                            UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
                            savedCount += 1
                        }
                        DispatchQueue.main.async {
                            self.alertMessage = "\(savedCount) image(s) saved successfully to Photos library!"
                            self.showingAlert = true
                            self.isSaving = false
                            self.clearPhotos()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.alertMessage = "Unable to access the Photos library. Please check your permissions in Settings."
                        self.showingAlert = true
                        self.isSaving = false
                    }
                }
            }
        }
    
    private func clearPhotos() {
            imageAssets.removeAll()
            originalImages.removeAll()
            processedImages.removeAll()
            previewImages.removeAll()
            selectedImageIndex = 0
        }

    private func processAndAddBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: InstagramSize) -> UIImage {
        let croppedImage = cropImage(image, to: size)
        return addBorder(to: croppedImage, color: color, thickness: thickness, size: size)
    }

    private func cropImage(_ image: UIImage, to size: InstagramSize) -> UIImage {
        let targetAspect = size.aspectRatio
        let imageAspect = image.size.width / image.size.height
        
        var drawRect: CGRect
        
        if imageAspect > targetAspect {
            // Image is wider, crop the sides
            let newWidth = image.size.height * targetAspect
            let xOffset = (image.size.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: image.size.height)
        } else {
            // Image is taller, crop the top and bottom
            let newHeight = image.size.width / targetAspect
            let yOffset = (image.size.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: image.size.width, height: newHeight)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        
        let renderer = UIGraphicsImageRenderer(size: drawRect.size, format: format)
        
        return renderer.image { context in
            image.draw(at: CGPoint(x: -drawRect.origin.x, y: -drawRect.origin.y))
        }
    }


    private func addBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: InstagramSize) -> UIImage {
        let targetSize = size.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            // Fill the entire image with the border color
            color.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate the size for the image after applying the border
            let imageRect = CGRect(x: thickness, y: thickness,
                                   width: targetSize.width - (thickness * 2),
                                   height: targetSize.height - (thickness * 2))
            
            // Calculate the aspect ratio of the original image
            let imageAspect = image.size.width / image.size.height
            
            // Calculate the aspect ratio of the target size
            let targetAspect = imageRect.width / imageRect.height
            
            let drawRect: CGRect
            if imageAspect > targetAspect {
                // Image is wider, fit to height
                let drawWidth = imageRect.height * imageAspect
                let xOffset = (imageRect.width - drawWidth) / 2
                drawRect = CGRect(x: thickness + xOffset, y: thickness,
                                  width: drawWidth, height: imageRect.height)
            } else {
                // Image is taller, fit to width
                let drawHeight = imageRect.width / imageAspect
                let yOffset = (imageRect.height - drawHeight) / 2
                drawRect = CGRect(x: thickness, y: thickness + yOffset,
                                  width: imageRect.width, height: drawHeight)
            }
            
            // Draw the image, maintaining its aspect ratio
            image.draw(in: drawRect)
        }
    }


    private func downsample(image: UIImage, to pointSize: CGSize) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let data = image.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return image
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * UIScreen.main.scale
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
}

struct ImageView: View {
    let processedImage: UIImage?
    
    @State private var debouncedImage: UIImage?
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let debouncedImage = debouncedImage {
                Image(uiImage: debouncedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.35)
        .onAppear {
            updateDebouncedImage()
        }
        .onChange(of: processedImage) { _, _ in updateDebouncedImage() }
    }
    
    private func updateDebouncedImage() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 milliseconds
            if !Task.isCancelled {
                await MainActor.run {
                    debouncedImage = processedImage
                }
            }
        }
    }
}
