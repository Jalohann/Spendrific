import SwiftUI

struct CardView: View {
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Icon
            if account.issuer == .chase {
                Image("icons8-chase-bank-120")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
            } else {
                Image(systemName: "creditcard.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .foregroundColor(account.color)
            }
            
            // Card Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                Text("····\(account.lastFour)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Balance
            Text(String(format: "$%.2f", account.balance))
                .font(.title3.bold())
        }
        .frame(width: 160)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

#Preview {
    CardView(account: Account(
        issuer: .chase,
        lastFour: "2355",
        balance: 26.49,
        name: "Freedom Unlimited"
    ))
} 