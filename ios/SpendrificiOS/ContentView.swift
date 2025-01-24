import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TransactionsViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if !viewModel.transactions.isEmpty {
                    TransactionListView(viewModel: viewModel)
                } else {
                    EmptyStateView(viewModel: viewModel)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                Button("Reset Onboarding") {
                    hasCompletedOnboarding = false
                    UserDefaults.standard.removeObject(forKey: "serverAddress")
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .alert("Success", isPresented: $viewModel.showingConfirmation) {
                Button("OK") { }
            } message: {
                Text("Bill payment has been processed successfully")
            }
        }
        .onAppear {
            viewModel.fetchTransactions()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Fetching transactions...")
                .foregroundColor(.secondary)
        }
    }
}

struct TransactionListView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    
    var body: some View {
        List {
            ForEach(Array(viewModel.transactions.enumerated()), id: \.element.id) { index, transaction in
                TransactionRow(transaction: transaction) { updatedTransaction in
                    viewModel.updateTransaction(updatedTransaction, at: index)
                }
            }
            
            Section {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "$%.2f", viewModel.total))
                        .font(.headline)
                }
            }
            
            Section {
                Button(action: {
                    viewModel.submitBillPayment()
                }) {
                    Text("Submit Bill Payment")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.blue)
                .disabled(viewModel.isLoading)
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let onUpdate: (Transaction) -> Void
    
    @State private var amount: String
    
    init(transaction: Transaction, onUpdate: @escaping (Transaction) -> Void) {
        self.transaction = transaction
        self.onUpdate = onUpdate
        _amount = State(initialValue: transaction.amount)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(transaction.name)
                .font(.headline)
            Text(transaction.date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Amount", text: $amount)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
                .onChange(of: amount) { newValue in
                    var updatedTransaction = transaction
                    updatedTransaction.amount = newValue
                    onUpdate(updatedTransaction)
                }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No transactions found")
                .font(.headline)
            Button("Refresh") {
                viewModel.fetchTransactions()
            }
        }
    }
}

#Preview {
    ContentView()
} 