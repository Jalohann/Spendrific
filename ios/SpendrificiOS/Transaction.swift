import Foundation

struct Transaction: Codable, Identifiable {
    let id = UUID()
    var date: String
    var name: String
    var amount: String
    
    enum CodingKeys: String, CodingKey {
        case date = "Date"
        case name = "Name"
        case amount = "Amount"
    }
    
    var amountValue: Double {
        let cleanedAmount = amount.replacingOccurrences(of: "$", with: "")
        return Double(cleanedAmount) ?? 0.0
    }
    
    var formattedAmount: String {
        let value = amountValue
        return String(format: "$%.2f", abs(value))
    }
    
    var isExpense: Bool {
        return amountValue < 0
    }
}

extension Transaction {
    static var sample: Transaction {
        Transaction(date: "Jan 23, 2025", name: "Sample Transaction", amount: "$20.00")
    }
} 