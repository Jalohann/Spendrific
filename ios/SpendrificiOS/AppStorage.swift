import Foundation
import KeychainSwift

class AppStorage {
    static let shared = AppStorage()
    private let keychain = KeychainSwift()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // Add reset function
    func reset() {
        // Clear UserDefaults
        defaults.removeObject(forKey: "userName")
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: "serverAddress")
        defaults.removeObject(forKey: "ynabBudgetId")
        defaults.removeObject(forKey: "transactions")
        
        // Clear Keychain
        keychain.delete("ynabToken")
        
        // Force defaults to sync
        defaults.synchronize()
    }
    
    // User Settings
    var userName: String {
        get { defaults.string(forKey: "userName") ?? "" }
        set { defaults.set(newValue, forKey: "userName") }
    }
    
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    // Server Configuration
    var serverAddress: String {
        get { defaults.string(forKey: "serverAddress") ?? "localhost:5001" }
        set { defaults.set(newValue, forKey: "serverAddress") }
    }
    
    // YNAB Configuration
    var ynabBudgetId: String? {
        get { defaults.string(forKey: "ynabBudgetId") }
        set { defaults.set(newValue, forKey: "ynabBudgetId") }
    }
    
    var ynabToken: String? {
        get { keychain.get("ynabToken") }
        set {
            if let token = newValue {
                keychain.set(token, forKey: "ynabToken")
            } else {
                keychain.delete("ynabToken")
            }
        }
    }
    
    // Transactions Storage
    var storedTransactions: [Transaction] {
        get {
            guard let data = defaults.data(forKey: "transactions") else { return [] }
            return (try? JSONDecoder().decode([Transaction].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "transactions")
            }
        }
    }
    
    func markTransactionAsPaid(_ transaction: Transaction) {
        var transactions = storedTransactions
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index].isPaid = true
            transactions[index].paymentDate = Date()
            storedTransactions = transactions
        }
    }
} 