//
//  CustomPicker.swift
//  BorderGenius
//
//  Created by Tobias Dosdal-feddersen on 12/09/2024.
//

import Foundation
import SwiftUI

struct CustomSegmentedPicker: View {
    @Binding var selectedAspectRatio: AspectRatio
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AspectRatio.allCases) { ratio in
                Button(action: {
                    selectedAspectRatio = ratio
                }) {
                    Text(ratio.display)
                        .font(.caption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selectedAspectRatio == ratio ? Color.white.opacity(0.2) : Color.clear)
                        .foregroundColor(.white)
                }
            }
        }
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}
