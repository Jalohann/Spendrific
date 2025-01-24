import Foundation

@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var total: Double = 0.0
    @Published var showingConfirmation = false
    
    func checkServerConnection() {
        Task {
            do {
                try await NetworkManager.shared.verifyServerConnection()
            } catch {
                self.error = "Server Connection Error: \(error.localizedDescription)\n\nMake sure the Flask server is running on localhost:5001"
            }
        }
    }
    
    func fetchTransactions() {
        isLoading = true
        error = nil
        
        Task {
            do {
                // First verify server connection
                try await NetworkManager.shared.verifyServerConnection()
                
                // Then fetch transactions
                transactions = try await NetworkManager.shared.fetchTransactions()
                calculateTotal()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    func updateTransaction(_ transaction: Transaction, at index: Int) {
        transactions[index] = transaction
        calculateTotal()
    }
    
    func calculateTotal() {
        total = transactions.reduce(0) { $0 + $1.amountValue }
    }
    
    func submitBillPayment() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await NetworkManager.shared.submitBillPayment(transactions: transactions)
                showingConfirmation = true
                transactions = []
                calculateTotal()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
} 