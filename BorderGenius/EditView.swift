import SwiftUI
import Photos
import ColorfulX
import Combine

struct EditView: View {
    @Binding var imageAssets: [PHAsset]
    @State private var borderColor: Color = .white
    @State private var borderThickness: CGFloat = 20
    @State private var processedImages: [Int: UIImage] = [:]
    @State private var originalImages: [Int: UIImage] = [:]
    @State private var previewImages: [Int: UIImage] = [:]
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedImageIndex: Int = 0
    @State private var isLoading = false
    @State private var selectedAspectRatio: AspectRatio = .square
    @State private var isSaving = false
    @Environment(\.presentationMode) var presentationMode
    
    // ColorfulX properties
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
                        .onChange(of: selectedImageIndex) { _, _ in updateCurrentPreviewImage() }
                        
                        // Controls
                        VStack(spacing: 20) {
                            CustomSegmentedPicker(selectedAspectRatio: $selectedAspectRatio)
                                .padding()
                                .frame(maxWidth: 400)
                                .background(Color.clear)
                            
                            ColorPicker("Border Color", selection: $borderColor)
                                .foregroundColor(.white)
                            
                            VStack {
                                Text("Border Thickness: \(Int(borderThickness)) px")
                                    .foregroundStyle(Color(.white))
                                Slider(value: $borderThickness, in: 0...500, step: 10)
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
        .onChange(of: borderColor) { _, _ in updateCurrentPreviewImage() }
        .onChange(of: borderThickness) { _, _ in updateCurrentPreviewImage() }
        .onChange(of: selectedAspectRatio) { _, _ in updateCurrentPreviewImage() }
    }

    private func loadOriginalImages() {
        isLoading = true
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 1000, height: 1000)
        
        for (index, asset) in imageAssets.enumerated() {
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("Error loading image: \(error.localizedDescription)")
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
    
    private func updateCurrentPreviewImage() {
        updatePreviewImage(at: selectedImageIndex)
    }

    private func updatePreviewImage(at index: Int) {
        guard let originalImage = originalImages[index] else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let processedImage = self.processAndAddBorder(to: originalImage, color: UIColor(self.borderColor), thickness: self.borderThickness, aspectRatio: self.selectedAspectRatio)
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
                    for (_, originalImage) in self.originalImages {
                        let processedImage = self.processAndAddBorder(to: originalImage, color: UIColor(self.borderColor), thickness: self.borderThickness, aspectRatio: self.selectedAspectRatio)
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
        let imageRect: CGRect
        
        if aspectRatio.ratio > 1 {
            // Landscape
            targetSize = CGSize(width: baseSize, height: baseSize / aspectRatio.ratio)
            let availableWidth = targetSize.width - (thickness * 2)
            let availableHeight = targetSize.height - (thickness * 2)
            let imageWidth = availableWidth
            let imageHeight = imageWidth / aspectRatio.ratio
            let yOffset = (availableHeight - imageHeight) / 2
            imageRect = CGRect(x: thickness, y: thickness + yOffset, width: imageWidth, height: imageHeight)
        } else {
            // Portrait or Square
            targetSize = CGSize(width: baseSize, height: baseSize / aspectRatio.ratio)
            let availableWidth = targetSize.width - (thickness * 2)
            let availableHeight = targetSize.height - (thickness * 2)
            let imageHeight = availableHeight
            let imageWidth = imageHeight * aspectRatio.ratio
            let xOffset = (availableWidth - imageWidth) / 2
            imageRect = CGRect(x: thickness + xOffset, y: thickness, width: imageWidth, height: imageHeight)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            // Fill the entire image with the border color
            color.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Draw the image, maintaining its aspect ratio
            image.draw(in: imageRect)
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
