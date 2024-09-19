import SwiftUI
import CoreImage

extension CIImage {
    func sampledColor(at point: CGPoint, context: CIContext) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let extent = self.extent
        
        var pixelData = [UInt8](repeating: 0, count: 4)
        context.render(self, toBitmap: &pixelData, rowBytes: 4, bounds: CGRect(x: point.x, y: point.y, width: 1, height: 1), format: .RGBA8, colorSpace: colorSpace)
        
        let red = CGFloat(pixelData[0]) / 255.0
        let green = CGFloat(pixelData[1]) / 255.0
        let blue = CGFloat(pixelData[2]) / 255.0
        
        return (red, green, blue)
    }
}

enum FilmProfile: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case kodakPortra400 = "Kodak Portra 400"
    case fujiProvia100F = "Fuji Provia 100F"
    case ilfordHP5 = "Ilford HP5"
    case kodakEktar100 = "Kodak Ektar 100"
    case fujiVelvia50 = "Fuji Velvia 50"
    case cineStill800T = "CineStill 800T"
    
    var id: String { self.rawValue }
}

struct ProfileCardCarousel: View {
    let profiles: [FilmProfile]
    @Binding var selectedProfile: FilmProfile
    let onSelect: (FilmProfile) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 15) {
                ForEach(profiles) { profile in
                    ProfileCard(profile: profile, isSelected: profile == selectedProfile)
                        .frame(width: 120)
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
    let profile: FilmProfile
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                
                Image(systemName: "photo.film")
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

struct NeutralGrayPicker: View {
    let image: UIImage
    let onSelectNeutralPoint: (CGPoint) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(
                    Color.black.opacity(0.5)
                )
                .overlay(
                    Text("Tap on a neutral gray area")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(),
                    alignment: .top
                )
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let size = geometry.size
                    let normalizedPoint = CGPoint(
                        x: location.x / size.width,
                        y: location.y / size.height
                    )
                    onSelectNeutralPoint(normalizedPoint)
                }
        }
    }
}

struct FilmProfileConverterView: View {
    @State private var selectedProfile: FilmProfile = .standard
    @State private var sourceImage: UIImage?
    @State private var isShowingNeutralPicker = false
    @State private var neutralPoint: CGPoint?
    
    var body: some View {
        VStack {
            if let image = sourceImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            } else {
                Text("No image selected")
                    .foregroundColor(.secondary)
            }
            
            ProfileCardCarousel(
                profiles: FilmProfile.allCases,
                selectedProfile: $selectedProfile,
                onSelect: { profile in
                    // Handle profile selection
                    print("Selected profile: \(profile.rawValue)")
                }
            )
            
            Button("Select Neutral Gray Point") {
                isShowingNeutralPicker = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(sourceImage == nil)
        }
        .sheet(isPresented: $isShowingNeutralPicker) {
            if let image = sourceImage {
                NeutralGrayPicker(image: image) { point in
                    neutralPoint = point
                    isShowingNeutralPicker = false
                    applyNeutralPointCorrection()
                }
            }
        }
    }
    
    private func applyNeutralPointCorrection() {
        guard let image = sourceImage, let point = neutralPoint else { return }
        
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else { return }
        
        let extent = ciImage.extent
        let x = point.x * extent.width
        let y = point.y * extent.height
        
        // Create a CIContext
        let context = CIContext(options: nil)
        
        // Sample the color at the selected point
        let sampledColor = ciImage.sampledColor(at: CGPoint(x: x, y: y), context: context)
        
        // Calculate scaling factors
        let avgColor = (sampledColor.red + sampledColor.green + sampledColor.blue) / 3
        let scaleRed = avgColor / sampledColor.red
        let scaleGreen = avgColor / sampledColor.green
        let scaleBlue = avgColor / sampledColor.blue
        
        // Apply color matrix filter
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = ciImage
        colorMatrix.rVector = CIVector(x: scaleRed, y: 0, z: 0, w: 0)
        colorMatrix.gVector = CIVector(x: 0, y: scaleGreen, z: 0, w: 0)
        colorMatrix.bVector = CIVector(x: 0, y: 0, z: scaleBlue, w: 0)
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        
        if let outputImage = colorMatrix.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            sourceImage = UIImage(cgImage: cgImage)
        }
    }
}

struct FilmProfileConverterView_Previews: PreviewProvider {
    static var previews: some View {
        FilmProfileConverterView()
    }
}
