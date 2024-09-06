import SwiftUI
import Photos
import ColorfulX

struct EditView: View {
    @Binding var imageAssets: [PHAsset]
    @State private var borderColor: Color = .white
    @State private var borderThickness: CGFloat = 20
    @State private var selectedSize: InstagramSize = .square
    @State private var processedImages: [Int: UIImage] = [:]
    @State private var originalImages: [Int: UIImage] = [:]
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedImageIndex: Int = 0
    @Environment(\.presentationMode) var presentationMode
    
    // ColorfulX properties (unchanged)
    let customColors: [Color] = [
        Color(red: 0.0039, green: 0.0471, blue: 0.2471),
        Color(red: 0.1882, green: 0.2706, blue: 0.4),
        Color(red: 0.3725, green: 0.4824, blue: 0.5373),
        Color(red: 0.0314, green: 0.1608, blue: 0.3176),
        Color(red: 0.2824, green: 0.6, blue: 0.7098)
    ]
    
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
                        VStack{
                            Button(action: { deleteImage(at: selectedImageIndex) }) {
                                Text("Remove Current Image")
                                    .foregroundColor(.red)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.clear)
                                    .cornerRadius(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                            }
                        }
                        // Image slider
                        TabView(selection: $selectedImageIndex) {
                            ForEach(Array(imageAssets.enumerated()), id: \.offset) { index, asset in
                                ImageView(processedImage: processedImages[index])
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .onChange(of: selectedImageIndex) { _ in
                            updateCurrentImage()
                        }
                        
                        // Controls
                        VStack(spacing: 20) {
                            Picker("Image Size", selection: $selectedSize) {
                                ForEach(InstagramSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            ColorPicker("Border Color", selection: $borderColor)
                            
                            VStack {
                                Text("Border Thickness: \(Int(borderThickness)) px")
                                Slider(value: $borderThickness, in: 0...200, step: 1)
                            }
                        }
                        .padding()
                        
                        if isProcessing {
                            ProgressView()
                        }
                    }
                }
                .navigationBarTitle("", displayMode: .inline)
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(
                    leading: Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .accentColor(.white),
                    trailing: Button(action: saveImagesToPhotos) {
                        Image(systemName: "square.and.arrow.down")
                    }
                        .accentColor(.white)
                    .disabled(isProcessing || imageAssets.isEmpty)
                )
            }
        }
        .onAppear {
            loadOriginalImages()
        }
        .onChange(of: borderColor) { _ in updateCurrentImage() }
        .onChange(of: borderThickness) { _ in updateCurrentImage() }
        .onChange(of: selectedSize) { _ in updateCurrentImage() }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Save to Photos"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func loadOriginalImages() {
        for (index, asset) in imageAssets.enumerated() {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1000, height: 1000), contentMode: .aspectFit, options: options) { image, _ in
                guard let image = image else { return }
                DispatchQueue.main.async {
                    self.originalImages[index] = image
                    self.updateCurrentImage()
                }
            }
        }
    }

    private func updateCurrentImage() {
        guard let originalImage = originalImages[selectedImageIndex] else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let processedImage = self.processAndAddBorder(to: originalImage, color: UIColor(self.borderColor), thickness: self.borderThickness, size: self.selectedSize)
            DispatchQueue.main.async {
                self.processedImages[self.selectedImageIndex] = processedImage
            }
        }
    }
    
    private func deleteImage(at index: Int) {
        guard index < imageAssets.count else { return }
        imageAssets.remove(at: index)
        processedImages.removeValue(forKey: index)
        originalImages.removeValue(forKey: index)
        
        // Shift the remaining processed images
        for i in index..<imageAssets.count {
            processedImages[i] = processedImages.removeValue(forKey: i + 1)
            originalImages[i] = originalImages.removeValue(forKey: i + 1)
        }
        
        if selectedImageIndex >= imageAssets.count {
            selectedImageIndex = max(imageAssets.count - 1, 0)
        }
    }

    private func saveImagesToPhotos() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    var savedCount = 0
                    for (_, image) in processedImages {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        savedCount += 1
                    }
                    alertMessage = "\(savedCount) image(s) saved successfully to Photos library!"
                    showingAlert = true
                } else {
                    alertMessage = "Unable to access the Photos library. Please check your permissions in Settings."
                    showingAlert = true
                }
            }
        }
    }

    private func processAndAddBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: InstagramSize) -> UIImage {
        let croppedImage = cropImage(image, to: size)
        return addBorder(to: croppedImage, color: color, thickness: thickness, size: size.size)
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
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: drawRect.size, format: format)
        
        return renderer.image { context in
            image.draw(at: CGPoint(x: -drawRect.origin.x, y: -drawRect.origin.y))
        }
    }

    private func addBorder(to image: UIImage, color: UIColor, thickness: CGFloat, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { context in
            // Fill the entire image with the border color
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Calculate the size for the image after applying the border
            let imageRect = CGRect(x: thickness, y: thickness, width: size.width - (thickness * 2), height: size.height - (thickness * 2))
            
            // Draw the image, maintaining its aspect ratio
            let aspectFit = AVMakeRect(aspectRatio: image.size, insideRect: imageRect)
            image.draw(in: aspectFit)
        }
    }
}

struct ImageView: View {
    let processedImage: UIImage?
    
    var body: some View {
        Group {
            if let processedImage = processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        //.padding(.bottom, 30)
        .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.35)
        .background(Color.gray.opacity(0.0))
        //.cornerRadius(10)
    }
}
