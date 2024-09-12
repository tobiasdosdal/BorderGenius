//
//  CustomPicker.swift
//  BorderGenius
//
//  Created by Tobias Dosdal-feddersen on 12/09/2024.
//

import Foundation
import SwiftUI

struct CustomSegmentedPicker: View {
    @Binding var selectedSize: InstagramSize
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(InstagramSize.allCases) { size in
                Button(action: {
                    selectedSize = size
                }) {
                    VStack(spacing: 2) {
                        Text(size.rawValue)
                            .font(.headline)
                        Text("\(Int(size.size.width))x\(Int(size.size.height))")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(selectedSize == size ? Color.white.opacity(0.2) : Color.clear)
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
