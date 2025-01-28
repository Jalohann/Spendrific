import SwiftUI

struct Account: Identifiable {
    let id = UUID()
    let issuer: CardIssuer
    let lastFour: String
    var balance: Double
    let name: String
    
    var icon: Image {
        issuer.icon
    }
    
    var color: Color {
        issuer.color
    }
}

extension Account {
    static func from(cardInfo: CardInfo) -> Account {
        Account(
            issuer: CardIssuer.from(cardName: cardInfo.cardName),
            lastFour: cardInfo.lastFourDigits,
            balance: cardInfo.currentBalance,
            name: cardInfo.cardName
        )
    }
} 