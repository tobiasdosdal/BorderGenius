import SwiftUI

enum InstagramSize: String, CaseIterable, Identifiable {
    case square = "Square"
    case portrait = "Portrait"
    case landscape = "Landscape"
    
    var id: String { self.rawValue }
    
    var size: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1350)
        case .landscape: return CGSize(width: 1080, height: 608)
        }
    }
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
}
