import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct ColorModificationView: View {
    @Binding var modification: ColorModification
    @Binding var previewImage: UIImage?
    var onApply: () -> Void
    
    @State private var modifiedImage: UIImage?
    @State private var isUpdating = false
    @State private var selectedTab = 0
    
    let tabs = ["Basic", "Tone", "Color", "Channels"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image preview
                Group {
                    if let image = modifiedImage ?? previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding()
                            .overlay(
                                Group {
                                    if isUpdating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.5)
                                    }
                                }
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(Text("No image available"))
                            .padding()
                    }
                }
                .background(Color(UIColor.systemBackground))
                
                // Slider groups
                TabView(selection: $selectedTab) {
                    BasicAdjustments(modification: $modification, onEditingChanged: sliderEditingChanged)
                        .tag(0)
                    
                    ToneAdjustments(modification: $modification, onEditingChanged: sliderEditingChanged)
                        .tag(1)
                    
                    ColorTemperature(modification: $modification, onEditingChanged: sliderEditingChanged)
                        .tag(2)
                    
                    ColorChannels(modification: $modification, onEditingChanged: sliderEditingChanged)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom tab bar
                HStack {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Button(action: {
                            selectedTab = index
                        }) {
                            Text(tabs[index])
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(selectedTab == index ? Color.blue : Color.clear)
                                .foregroundColor(selectedTab == index ? .white : .primary)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
            }
            .navigationTitle("Modify Colors")
            .navigationBarItems(trailing: Button("Apply", action: onApply))
        }
    }
    
    private func sliderEditingChanged(editingChanged: Bool) {
        if !editingChanged {
            updatePreview()
        }
    }
    
    private func updatePreview() {
        guard let image = previewImage else { return }
        isUpdating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let updatedImage = applyModification(to: image, with: modification)
            
            DispatchQueue.main.async {
                modifiedImage = updatedImage
                isUpdating = false
            }
        }
    }
}

struct BasicAdjustments: View {
    @Binding var modification: ColorModification
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        VStack {
            SliderView(value: $modification.brightness, title: "Brightness", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.contrast, title: "Contrast", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.saturation, title: "Saturation", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.vibrance, title: "Vibrance", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
        }
        .padding()
    }
}

struct ToneAdjustments: View {
    @Binding var modification: ColorModification
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        VStack {
            SliderView(value: $modification.lights, title: "Lights", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.darks, title: "Darks", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.whites, title: "Whites", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.blacks, title: "Blacks", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
        }
        .padding()
    }
}

struct ColorTemperature: View {
    @Binding var modification: ColorModification
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        VStack {
            SliderView(value: $modification.temp, title: "Temperature", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.tint, title: "Tint", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.hueAdjustment, title: "Hue", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
        }
        .padding()
    }
}

struct ColorChannels: View {
    @Binding var modification: ColorModification
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        VStack {
            SliderView(value: $modification.redAdjustment, title: "Red", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.greenAdjustment, title: "Green", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
            SliderView(value: $modification.blueAdjustment, title: "Blue", range: -1...1, onEditingChanged: onEditingChanged, defaultValue: 0)
        }
        .padding()
    }
}

struct SliderView: View {
    @Binding var value: Double
    let title: String
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    let defaultValue: Double
    
    @State private var isResetting = false
    
    var body: some View {
        VStack {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value))
            }
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            resetValue()
                        }
                )
                .overlay(
                    Group {
                        if isResetting {
                            Text("Reset")
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue)
                                .cornerRadius(5)
                        }
                    }
                )
        }
    }
    
    private func resetValue() {
        withAnimation {
            isResetting = true
        }
        
        value = defaultValue
        onEditingChanged(false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isResetting = false
            }
        }
    }
}
