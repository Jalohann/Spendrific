import SwiftUI

enum CardIssuer: String {
    case chase = "Chase"
    case amex = "American Express"
    case visa = "Visa"
    case mastercard = "Mastercard"
    case discover = "Discover"
    case other = "Other"
    
    var icon: Image {
        switch self {
        case .chase:
            return Image("icons8-chase-bank-120")
                .renderingMode(.original)
        case .amex:
            return Image(systemName: "creditcard.fill")
        case .visa:
            return Image(systemName: "creditcard.fill")
        case .mastercard:
            return Image(systemName: "creditcard.fill")
        case .discover:
            return Image(systemName: "creditcard.fill")
        case .other:
            return Image(systemName: "creditcard.fill")
        }
    }
    
    var color: Color {
        switch self {
        case .chase:
            return .blue
        case .amex:
            return Color(red: 0.0, green: 0.47, blue: 0.73) // Amex Blue
        case .visa:
            return Color(red: 0.0, green: 0.45, blue: 0.8) // Visa Blue
        case .mastercard:
            return .orange
        case .discover:
            return .orange
        case .other:
            return .gray
        }
    }
    
    static func from(cardName: String) -> CardIssuer {
        let lowercased = cardName.lowercased()
        if lowercased.contains("chase") {
            return .chase
        } else if lowercased.contains("amex") || lowercased.contains("american express") {
            return .amex
        } else if lowercased.contains("visa") {
            return .visa
        } else if lowercased.contains("mastercard") {
            return .mastercard
        } else if lowercased.contains("discover") {
            return .discover
        } else {
            return .other
        }
    }
} 