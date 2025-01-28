import Foundation

class YNABService {
    static let shared = YNABService()
    private let baseURL = "https://api.ynab.com/v1"
    
    private var token: String? {
        let token = AppStorage.shared.ynabToken
        print("YNAB Token: \(token != nil ? "exists" : "missing")")
        return token
    }
    
    // Get all budgets
    func getBudgets() async throws -> [Budget] {
        guard let token = token else {
            print("No YNAB token found!")
            throw YNABError.noToken
        }
        
        print("Fetching budgets with token...")
        var request = URLRequest(url: URL(string: "\(baseURL)/budgets")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            print("Budget fetch failed with status code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            throw YNABError.noToken
        }
        
        let budgetResponse = try JSONDecoder().decode(BudgetResponse.self, from: data)
        print("Successfully fetched \(budgetResponse.data.budgets.count) budgets")
        return budgetResponse.data.budgets
    }
    
    // Get accounts for a budget
    func getAccounts(budgetId: String) async throws -> [YNABAccount] {
        guard let token = token else { throw YNABError.noToken }
        
        print("Fetching accounts for budget: \(budgetId)")
        var request = URLRequest(url: URL(string: "\(baseURL)/budgets/\(budgetId)/accounts")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            print("Account fetch failed with status code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            throw YNABError.noToken
        }
        
        let accountResponse = try JSONDecoder().decode(YNABAccountsResponse.self, from: data)
        print("Successfully fetched \(accountResponse.data.accounts.count) accounts")
        return accountResponse.data.accounts
    }
    
    // Get categories for a budget
    func getCategories(budgetId: String) async throws -> [CategoryGroup] {
        guard let token = token else { throw YNABError.noToken }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/budgets/\(budgetId)/categories")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            print("Categories fetch failed with status code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            throw YNABError.noToken
        }
        
        let categoryResponse = try JSONDecoder().decode(CategoryGroupsResponse.self, from: data)
        return categoryResponse.data.category_groups
    }
    
    // Create a transaction in YNAB
    func createTransaction(budgetId: String, transaction: YNABTransaction) async throws {
        guard let token = token else { throw YNABError.noToken }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/budgets/\(budgetId)/transactions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create a simplified transaction object with only the required fields
        let transactionDict: [String: Any] = [
            "account_id": transaction.account_id,
            "date": transaction.date,
            "amount": transaction.amount,
            "payee_name": transaction.payee_name as Any,
            "category_id": transaction.category_id as Any,
            "memo": transaction.memo as Any,
            "cleared": transaction.cleared,
            "approved": transaction.approved
        ]
        
        // Create the payload with just the single transaction
        let payload = ["transaction": transactionDict]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.httpBody = jsonData
        
        print("Sending YNAB request:")
        print(String(data: jsonData, encoding: .utf8) ?? "")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YNABError.createFailed
        }
        
        if httpResponse.statusCode != 201 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("YNAB Error Response: \(errorString)")
            }
            throw YNABError.createFailed
        }
    }
}

// YNAB Models
struct BudgetResponse: Codable {
    let data: BudgetsData
}

struct BudgetsData: Codable {
    let budgets: [Budget]
}

struct Budget: Codable, Identifiable {
    let id: String
    let name: String
}

struct YNABAccountsResponse: Codable {
    let data: YNABAccountsData
}

struct YNABAccountsData: Codable {
    let accounts: [YNABAccount]
}

struct YNABAccount: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let balance: Int
    let closed: Bool
    
    var balanceDecimal: Double {
        Double(balance) / 1000.0
    }
}

struct CategoryGroupsResponse: Codable {
    let data: CategoryGroupsData
}

struct CategoryGroupsData: Codable {
    let category_groups: [CategoryGroup]
}

struct CategoryGroup: Codable, Identifiable {
    let id: String
    let name: String
    let categories: [Category]
}

struct Category: Codable, Identifiable {
    let id: String
    let name: String
    let balance: Int // Amount in milliunits
    let category_group_id: String
    
    var balanceDecimal: Double {
        Double(balance) / 1000.0
    }
}

struct YNABTransaction: Codable {
    let account_id: String
    let date: String
    let amount: Int // Milliunits
    let payee_name: String?
    let category_id: String?
    let memo: String?
    let cleared: String
    let approved: Bool
}

enum YNABError: Error {
    case noToken
    case createFailed
    case updateFailed
} 