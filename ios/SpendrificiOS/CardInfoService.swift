import Foundation

struct CardInfo: Codable {
    let cardName: String
    let lastFourDigits: String
    let currentBalance: Double
    
    enum CodingKeys: String, CodingKey {
        case cardName
        case lastFourDigits
        case currentBalance
    }
}

class CardInfoService {
    static let shared = CardInfoService()
    private let session: URLSession
    
    private init() {
        // Create custom URLSession configuration
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        // Create custom URLSession with TLS trust handling
        session = URLSession(configuration: configuration, delegate: NetworkManager.CustomURLSessionDelegate(), delegateQueue: nil)
    }
    
    func getCardInfo() async throws -> CardInfo {
        let baseURL = "https://\(AppStorage.shared.serverAddress)"
        guard let url = URL(string: "\(baseURL)/cardInfo") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(CardInfo.self, from: data)
    }
} 