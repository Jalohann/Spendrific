import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private var baseURL: String
    
    private init() {
        if let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") {
            baseURL = "http://\(savedAddress)"
        } else {
            baseURL = "http://localhost:5001"
        }
    }
    
    func updateBaseURL(server: String, port: String) {
        baseURL = "http://\(server):\(port)"
    }
    
    enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
    }
    
    func fetchTransactions() async throws -> [Transaction] {
        // First trigger the fetch
        try await triggerTransactionFetch()
        
        // Then get the transactions
        return try await getTransactions()
    }
    
    private func triggerTransactionFetch() async throws {
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
    
    private func getTransactions() async throws -> [Transaction] {
        guard let url = URL(string: "\(baseURL)/transactions") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to get transactions")
        }
        
        return try JSONDecoder().decode([Transaction].self, from: data)
    }
    
    func submitBillPayment(transactions: [Transaction]) async throws {
        guard let url = URL(string: "\(baseURL)/pay-bill") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["transactions": transactions]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to submit bill payment")
        }
    }
    
    func verifyServerConnection() async throws {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw NetworkError.invalidURL
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.serverError("Server is not responding")
            }
        } catch {
            throw NetworkError.serverError("Cannot connect to server. Make sure the Flask server is running on \(baseURL)")
        }
    }
} 