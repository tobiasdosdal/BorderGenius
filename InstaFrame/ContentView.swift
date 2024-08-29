import SwiftUI
import ColorfulX

struct ContentView: View {
    @State private var selectedImages: [UIImage] = []
    @State private var showingEditView = false
    
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
        NavigationStack {
            ZStack {
                ColorfulView(color: $colors, speed: $speed, noise: $noise)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    if selectedImages.isEmpty {
                        Text("No images selected")
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        Text("\(selectedImages.count) images selected")
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    NavigationLink {
                        ImagePicker(images: $selectedImages)
                    } label: {
                        Label("Select Images", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.white)
                    .padding()
                    
                    NavigationLink(value: selectedImages) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
            .navigationTitle("InstaFrame")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("InstaFrame")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                }
            }
            .navigationDestination(isPresented: $showingEditView) {
                EditView(images: $selectedImages)
            }
        }
        .onChange(of: selectedImages) { newValue in
            if !newValue.isEmpty {
                showingEditView = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
