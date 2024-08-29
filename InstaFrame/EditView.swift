import SwiftUI
import Photos
import ColorfulX

struct EditView: View {
    @Binding var images: [UIImage]
    @State private var borderColor: Color = .white
    @State private var borderThickness: CGFloat = 20
    @State private var selectedSize: InstagramSize = .square
    @State private var processedImages: [UIImage] = []
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var removingIndices: Set<Int> = []
    @Environment(\.presentationMode) var presentationMode
    
    // ColorfulX properties
    let customColors: [Color] = [
        Color(red: 0.0039, green: 0.0471, blue: 0.2471), /* #010c3f */
        Color(red: 0.1882, green: 0.2706, blue: 0.4), /* #304566 */
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        if images.isEmpty {
                            Text("No images remaining")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            VStack {
                                Picker("Image Size", selection: $selectedSize) {
                                    ForEach(InstagramSize.allCases) { size in
                                        Text(size.rawValue).tag(size)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                                        VStack {
                                            Image(uiImage: processedImages.count > index ? processedImages[index] : image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 200, height: 300)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .shadow(radius: 5)
                                            
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    removingIndices.insert(index)
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    deleteImage(at: index)
                                                    removingIndices.remove(index)
                                                }
                                            }) {
                                                Text("Remove")
                                                    .foregroundColor(.red)
                                                    .padding(.vertical, 5)
                                                    .padding(.horizontal, 10)
                                                    .background(Color.white)
                                                    .cornerRadius(5)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 5)
                                                            .stroke(Color.red, lineWidth: 1)
                                                    )
                                            }
                                            .padding(.top, 5)
                                            .scaleEffect(removingIndices.contains(index) ? 0.8 : 1)
                                            .opacity(removingIndices.contains(index) ? 0 : 1)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 360)

                            ColorPicker("Border Color", selection: $borderColor)
                            
                            VStack {
                                Text("Border Thickness: \(Int(borderThickness)) px")
                                Slider(value: $borderThickness, in: 0...200, step: 1)
                            }

                            if isProcessing {
                                ProgressView()
                            }
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: saveImagesToPhotos) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .disabled(isProcessing || images.isEmpty)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            updateProcessedImages()
        }
        .onChange(of: borderColor) { _, _ in
            updateProcessedImages()
        }
        .onChange(of: borderThickness) { _, _ in
            updateProcessedImages()
        }
        .onChange(of: selectedSize) { _, _ in
            updateProcessedImages()
        }
        .onChange(of: images) { newImages in
            if newImages.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Save to Photos"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func updateProcessedImages() {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let newProcessedImages = images.map { image in
                processAndAddBorder(to: image, color: UIColor(borderColor), thickness: borderThickness, size: selectedSize)
            }
            DispatchQueue.main.async {
                processedImages = newProcessedImages
                isProcessing = false
            }
        }
    }
    
    private func deleteImage(at index: Int) {
        images.remove(at: index)
        if processedImages.count > index {
            processedImages.remove(at: index)
        }
        updateProcessedImages()
    }

    private func saveImagesToPhotos() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    var savedCount = 0
                    for image in processedImages {
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
