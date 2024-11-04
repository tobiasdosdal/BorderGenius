import SwiftUI
import Photos
import ColorfulX
import Combine

struct EditView: View {
    // MARK: - Public Properties
    @Binding var imageAssets: [PHAsset]
    
    // MARK: - Internal Properties (accessible within the module)
    // Change these from 'internal var' to '@State'
    @State var borderColor: Color = .white
    @State var borderThickness: CGFloat = 20
    @State var selectedAspectRatio: AspectRatio = .square
    @State var previewImages: [Int: UIImage] = [:]
    
    // MARK: - Private Properties
    @State private var processedImages: [Int: UIImage] = [:]
    @State private var originalImages: [Int: UIImage] = [:]
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedImageIndex: Int = 0
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showingSaveConfirmation = false
    @Environment(\.presentationMode) private var presentationMode
    
    // ColorfulX properties
    @State var colors: [Color] = [
        Color(red: 0.0078, green: 0.3176, blue: 0.349),  /* #025159 */
        Color(red: 0.0157, green: 0.749, blue: 0.749),   /* #04bfbf */
        Color(red: 0.0118, green: 0.549, blue: 0.549),   /* #038c8c */
        Color(red: 0.749, green: 0.6039, blue: 0.4706),  /* #bf9a78 */
        Color(red: 0.549, green: 0.2706, blue: 0.1686)   /* #8c452b */
    ]
    @AppStorage("speed") private var speed: Double = 0.2
    @AppStorage("noise") private var noise: Double = 5.0
    @AppStorage("duration") private var duration: TimeInterval = 10.0
    
    // MARK: - Initialization
    init(imageAssets: Binding<[PHAsset]>) {
        self._imageAssets = imageAssets
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                ColorfulView(color: $colors, speed: $speed, noise: $noise)
                    .edgesIgnoringSafeArea(.all)
                mainContent
            }
        }
        .onAppear(perform: loadOriginalImages)
        .onChange(of: borderColor) { _, _ in updateCurrentPreviewImage() }
        .onChange(of: borderThickness) { _, _ in updateCurrentPreviewImage() }
        .onChange(of: selectedAspectRatio) { _, _ in updateCurrentPreviewImage() }
        .onDisappear {
            ImageCache.shared.clearCache()
        }
    }
    
    // MARK: - Private Views
    @ViewBuilder
    private var mainContent: some View {
        VStack {
            if imageAssets.isEmpty {
                Text("No images remaining")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                removeButton
                imageSlider
                controlsSection
                if isSaving {
                    savingProgress
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(trailing: saveButton)
        .alert("Save Images", isPresented: $showingSaveConfirmation) {
            saveConfirmationAlert
        }
        .alert("Save Complete", isPresented: $showingAlert) {
            saveCompleteAlert
        }
    }
    
    internal func updatePreviewImage(at index: Int) {
        guard let originalImage = originalImages[index] else { return }
        
        let cacheKey = ImageCache.makeKey(
            image: originalImage,
            borderColor: borderColor,
            borderThickness: borderThickness,
            aspectRatio: selectedAspectRatio
        )
        
        // Check cache first
        if let cachedImage = ImageCache.shared.image(forKey: cacheKey) {
            self.previewImages[index] = cachedImage
            return
        }
        
        // Process image if not in cache
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                // In updatePreviewImage
                let processedImage = ImageCache.processImage(
                    originalImage: originalImage,
                    borderColor: self.borderColor,
                    borderThickness: self.borderThickness,
                    aspectRatio: self.selectedAspectRatio,
                    processAndAddBorder: self.processAndAddBorder // explicitly use self
                )
                
                // Cache the processed image
                ImageCache.shared.setImage(processedImage, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    self.previewImages[index] = processedImage
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func updateCurrentPreviewImage() {
        for index in 0..<imageAssets.count {
            updatePreviewImage(at: index)
        }
    }
    
    private func loadOriginalImages() {
        isLoading = true
        let thumbnailOptions = PHImageRequestOptions()
        thumbnailOptions.deliveryMode = .opportunistic
        thumbnailOptions.isNetworkAccessAllowed = true
        thumbnailOptions.isSynchronous = false
        
        let highQualityOptions = PHImageRequestOptions()
        highQualityOptions.deliveryMode = .highQualityFormat
        highQualityOptions.isNetworkAccessAllowed = true
        highQualityOptions.isSynchronous = false
        
        // Thumbnail size for quick preview
        let thumbnailSize = CGSize(width: 300, height: 300)
        // Target size for final processing
        let targetSize = CGSize(width: 1000, height: 1000)
        
        for (index, asset) in imageAssets.enumerated() {
            // First load thumbnail for quick preview
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFit,
                options: thumbnailOptions
            ) { image, info in
                if let thumbnailImage = image {
                    DispatchQueue.main.async {
                        self.previewImages[index] = thumbnailImage
                    }
                }
            }
            
            // Then load high quality image for processing
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: highQualityOptions
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("Error loading image: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                } else if let image = image {
                    DispatchQueue.global(qos: .userInitiated).async {
                        autoreleasepool {
                            let downsampledImage = self.downsampleImage(image: image, to: targetSize)
                            DispatchQueue.main.async {
                                self.originalImages[index] = downsampledImage
                                self.updatePreviewImage(at: index)
                                
                                // Check if this was the last image
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

    private func clearPhotos() {
        imageAssets.removeAll()
        originalImages.removeAll()
        processedImages.removeAll()
        previewImages.removeAll()
        selectedImageIndex = 0
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
    
    private func deleteImage(at index: Int) {
        guard index < imageAssets.count else { return }
        imageAssets.remove(at: index)
        processedImages.removeValue(forKey: index)
        originalImages.removeValue(forKey: index)
        previewImages.removeValue(forKey: index)
        
        // Shift remaining images
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
                        let processedImage = self.processAndAddBorder( // explicitly use self
                            to: originalImage,
                            color: UIColor(self.borderColor),
                            thickness: self.borderThickness,
                            aspectRatio: self.selectedAspectRatio
                        )
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
}

extension EditView {
    // Make this internal so it can be accessed by ImageCache
    internal func processAndAddBorder(
        to image: UIImage,
        color: UIColor,
        thickness: CGFloat,
        aspectRatio: AspectRatio
    ) -> UIImage {
        let croppedImage = cropImage(image, to: aspectRatio.ratio)
        return addBorder(to: croppedImage, color: color, thickness: thickness, aspectRatio: aspectRatio)
    }
}

// MARK: - Private View Components
private extension EditView {
    var removeButton: some View {
        Button(action: { deleteImage(at: selectedImageIndex) }) {
            Text("Remove Current Image")
                .foregroundColor(.red)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color.clear)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.red, lineWidth: 1))
        }
    }
    
    var imageSlider: some View {
        TabView(selection: $selectedImageIndex) {
            ForEach(Array(imageAssets.enumerated()), id: \.offset) { index, _ in
                ImageView(processedImage: previewImages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .onChange(of: selectedImageIndex) { _, _ in updateCurrentPreviewImage() }
    }
    
    var controlsSection: some View {
        VStack(spacing: 20) {
            CustomSegmentedPicker(selectedAspectRatio: $selectedAspectRatio)  // Changed from .constant to $ binding
                .padding()
                .frame(maxWidth: 400)
                .background(Color.clear)
            
            ColorPicker("Border Color", selection: $borderColor)  // Changed from .constant to $ binding
                .foregroundColor(.white)
            
            VStack {
                Text("Border Thickness: \(Int(borderThickness)) px")
                    .foregroundStyle(Color(.white))
                Slider(value: $borderThickness, in: 0...500, step: 10)  // Changed from .constant to $ binding
            }
        }
        .padding()
    }
    
    var savingProgress: some View {
        ProgressView("Saving images...")
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .foregroundColor(.white)
    }
    
    var saveButton: some View {
        Button(action: { showingSaveConfirmation = true }) {
            Image(systemName: "square.and.arrow.down")
        }
        .disabled(isSaving || imageAssets.isEmpty)
    }
    
    var saveConfirmationAlert: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            Button("Save", role: .destructive) {
                saveImagesToPhotos()
            }
        }
    }
    
    var saveCompleteAlert: some View {
        Button("OK") {
            if imageAssets.isEmpty {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
