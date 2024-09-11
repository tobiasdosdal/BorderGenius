import SwiftUI
import PhotosUI
import Photos
import ColorfulX

struct ContentView: View {
    @State private var selectedImageAssets: [PHAsset] = []
    @State private var showingImagePicker = false
    
    let customColors: [Color] = [
        Color(red: 0.0078, green: 0.3176, blue: 0.349), /* #025159 */
        Color(red: 0.0157, green: 0.749, blue: 0.749), /* #04bfbf */
        Color(red: 0.0118, green: 0.549, blue: 0.549), /* #038c8c */
        Color(red: 0.749, green: 0.6039, blue: 0.4706), /* #bf9a78 */
        Color(red: 0.549, green: 0.2706, blue: 0.1686) /* #8c452b */
    ]
    
    @State var colors: [Color] = ColorfulPreset.neon.colors
    @AppStorage("speed") var speed: Double = 0.7
    @AppStorage("noise") var noise: Double = 8.0
    @AppStorage("duration") var duration: TimeInterval = 10.0
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorfulView(color: $colors, speed: $speed, noise: $noise)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        colors = customColors
                    }
                if selectedImageAssets.isEmpty {
                    VStack {
                        Text("BorderGenius")
                            .foregroundColor(.white)
                            .bold()
                            .font(.largeTitle)
                            
                        Text("No images selected")
                            .foregroundColor(.white)
                            .padding()
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Label("Select Images", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.white)
                        .padding()
                    }
                } else {
                    EditView(imageAssets: $selectedImageAssets)
                }
            }
            //.navigationTitle("BorderGenius")
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    Text("BorderGenius")
//                        .foregroundColor(.white)
//                        .font(.largeTitle)
//                }
//                
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        showingImagePicker = true
//                    }) {
//                        Image(systemName: "plus")
//                    }
//                    .foregroundColor(.white)
//                }
//            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(assets: $selectedImageAssets)
            }
        }
        .accentColor(.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}