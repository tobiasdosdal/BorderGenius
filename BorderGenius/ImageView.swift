import SwiftUI

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
        .onChange(of: processedImage) { _, _ in
            updateDebouncedImage()
        }
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
