import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case transactionsNotReady
    
    var isTransactionsNotReady: Bool {
        if case .transactionsNotReady = self {
            return true
        }
        return false
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private var baseURL: String
    
    private init() {
        let serverAddress = AppStorage.shared.serverAddress
        baseURL = "http://\(serverAddress)"
    }
    
    func updateBaseURL(server: String, port: String) {
        let address = "\(server):\(port)"
        AppStorage.shared.serverAddress = address
        baseURL = "http://\(address)"
    }
    
    func fetchTransactions() async throws -> [Transaction] {
        let url = URL(string: "\(baseURL)/transactions")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response")
        }
        
        // If status is 202, transactions are not ready yet
        if httpResponse.statusCode == 202 {
            throw NetworkError.transactionsNotReady
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Server returned status code \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode([Transaction].self, from: data)
    }
    
    func triggerTransactionFetch() async throws {
        guard let url = URL(string: "\(baseURL)/fetch-transactions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to fetch transactions")
        }
    }
    
    func getTransactions() async throws -> [Transaction] {
        guard let url = URL(string: "\(baseURL)/transactions") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response from server")
        }
        
        // Debug: Print the JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Server Response: \(jsonString)")
        }
        
        // If the CSV file doesn't exist yet, the server returns a 500 with an error message
        if httpResponse.statusCode == 500 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               errorResponse.message.contains("No such file") {
                return [] // Return empty array if CSV doesn't exist yet
            }
            throw NetworkError.serverError("Failed to get transactions")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to get transactions")
        }
        
        do {
            let transactions = try JSONDecoder().decode([Transaction].self, from: data)
            print("Decoded \(transactions.count) transactions")
            return transactions
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    private struct ErrorResponse: Codable {
        let status: String
        let message: String
    }
    
    private struct ServerTransaction: Codable {
        let Date: String
        let Name: String
        let Amount: String
        
        init(from transaction: Transaction) {
            self.Date = transaction.date
            self.Name = transaction.name
            self.Amount = transaction.amount
        }
    }
    
    func submitBillPayment(transactions: [Transaction]) async throws {
        guard let url = URL(string: "\(baseURL)/pay-bill") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert to server-safe transactions
        let serverTransactions = transactions.map { ServerTransaction(from: $0) }
        let payload = ["transactions": serverTransactions]
        
        // Debug print
        if let jsonData = try? JSONEncoder().encode(payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Sending payload: \(jsonString)")
        }
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to submit bill payment")
        }
    }
    
    func verifyServerConnection() async throws {
        let url = URL(string: "\(baseURL)/health")!
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Server is not responding")
        }
    }
} 