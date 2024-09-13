import SwiftUI

enum InstagramSize: String, CaseIterable, Identifiable {
    case square = "Square"
    case portrait = "Story"
    case landscape = "Landscape"
    
    var id: String { self.rawValue }
    
    var size: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1920)
        case .landscape: return CGSize(width: 1080, height: 608)
        }
    }
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
}

enum PostOrientation: String, CaseIterable, Identifiable {
    case portrait = "Portrait"
    case landscape = "Landscape"
    
    var id: String { self.rawValue }
}

enum AspectRatio: CaseIterable, Identifiable {
    case square
    case portrait916
    case portrait45
    case landscape169
    case landscape54
    
    var id: Self { self }
    
    var ratio: CGFloat {
        switch self {
        case .square: return 1.0
        case .portrait916: return 9.0 / 16.0
        case .portrait45: return 4.0 / 5.0
        case .landscape169: return 16.0 / 9.0
        case .landscape54: return 5.0 / 4.0
        }
    }
    
    var display: String {
        switch self {
        case .square: return "1:1"
        case .portrait916: return "9:16"
        case .portrait45: return "4:5"
        case .landscape169: return "16:9"
        case .landscape54: return "5:4"
        }
    }
}
