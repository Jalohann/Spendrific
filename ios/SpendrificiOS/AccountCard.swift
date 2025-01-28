import SwiftUI

struct AccountCard: View {
    let account: Account
    
    var body: some View {
        NavigationLink(destination: AccountDetailView(account: account)) {
            HStack(spacing: 16) {
                account.icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 50)
                    .shadow(radius: 2)
                
                VStack(alignment: .leading) {
                    Text(account.name)
                        .font(.headline)
                    Text("····\(account.lastFour)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "$%.2f", account.balance))
                    .font(.headline)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }
}

#Preview {
    AccountCard(account: Account(
        issuer: .chase,
        lastFour: "1234",
        balance: 1234.56,
        name: "Chase Freedom Unlimited"
    ))
} 