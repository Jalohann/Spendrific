import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @StateObject private var viewModel = TransactionsViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Account Header
            HStack(spacing: 16) {
                account.icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 50)
                
                VStack(alignment: .leading) {
                    Text(account.name)
                        .font(.title2)
                        .bold()
                    Text("····\(account.lastFour)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
            
            // Transactions List
            if viewModel.isLoading {
                TransactionLoadingView()
            } else {
                TransactionListView(viewModel: self.viewModel)
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TransactionLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Fetching transactions...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationView {
        AccountDetailView(account: Account(
            issuer: .chase,
            lastFour: "1234",
            balance: 1234.56,
            name: "Chase Freedom Unlimited"
        ))
    }
} 