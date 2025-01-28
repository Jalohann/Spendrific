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
    private let baseURL = "http://localhost:5001" // Updated to match Flask server port
    
    private init() {}
    
    func getCardInfo() async throws -> CardInfo {
        guard let url = URL(string: "\(baseURL)/cardInfo") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(CardInfo.self, from: data)
    }
} 