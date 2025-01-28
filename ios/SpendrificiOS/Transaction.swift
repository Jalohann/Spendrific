import Foundation

struct Transaction: Codable, Identifiable {
    let id = UUID()
    var date: String
    var name: String
    var amount: String
    var categoryId: String? = nil
    var categoryName: String? = nil
    var isPaid: Bool = false
    var paymentDate: Date? = nil
    
    enum CodingKeys: String, CodingKey {
        case date = "Date"
        case name = "Name"
        case amount = "Amount"
        case categoryId
        case categoryName
        case isPaid
        case paymentDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(String.self, forKey: .amount)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
        paymentDate = try container.decodeIfPresent(Date.self, forKey: .paymentDate)
    }
    
    init(date: String, name: String, amount: String) {
        self.date = date
        self.name = name
        self.amount = amount
    }
    
    var amountValue: Double {
        let cleanedAmount = amount.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleanedAmount) ?? 0.0
    }
    
    var formattedAmount: String {
        let value = amountValue
        return String(format: "$%.2f", value)
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