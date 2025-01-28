import Foundation
import CFNetwork

@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categoryGroups: [CategoryGroup] = []
    @Published var selectedBudget: Budget?
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var total: Double = 0.0
    @Published var showingConfirmation = false
    @Published var showError = false
    @Published var accounts: [Account] = []
    
    private let ynabService = YNABService.shared
    private var storageObserver: NSObjectProtocol?
    
    init() {
        // Sample accounts (in production, these would be fetched from a service)
        accounts = [
            Account(
                issuer: .chase,
                lastFour: "2355",
                balance: 26.49,
                name: "Freedom Unlimited"
            )
        ]
        
        // Load stored transactions on init
        Task { @MainActor in
            await loadStoredTransactions()
        }
        
        // Observe AppStorage changes
        storageObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadStoredTransactions()
            }
        }
    }
    
    deinit {
        if let observer = storageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func loadStoredTransactions() async {
        let storedTransactions = AppStorage.shared.storedTransactions
        await MainActor.run {
            self.transactions = storedTransactions
            self.calculateTotal()
        }
    }
    
    func checkServerConnection() {
        Task {
            do {
                try await NetworkManager.shared.verifyServerConnection()
            } catch {
                self.error = "Server Connection Error: \(error.localizedDescription)\n\nMake sure the Flask server is running on localhost:5001"
            }
        }
    }
    
    func refreshTransactions() async {
        isLoading = true
        error = nil
        
        do {
            // First trigger the fetch
            try await NetworkManager.shared.triggerTransactionFetch()
            
            // Start polling for transactions
            var transactions: [Transaction]?
            var attempts = 0
            
            while attempts < 10 {
                do {
                    let fetchedTransactions = try await NetworkManager.shared.getTransactions()
                    
                    // Apply stored states to new transactions
                    let storedTransactions = AppStorage.shared.storedTransactions
                    transactions = fetchedTransactions.map { transaction in
                        var updatedTransaction = transaction
                        // Look for matching transactions by name and amount to preserve paid status
                        if let storedTransaction = storedTransactions.first(where: { 
                            $0.name == transaction.name && 
                            abs($0.amountValue - transaction.amountValue) < 0.01 // Compare amounts with small tolerance
                        }) {
                            updatedTransaction.isPaid = storedTransaction.isPaid
                            updatedTransaction.paymentDate = storedTransaction.paymentDate
                            updatedTransaction.categoryId = storedTransaction.categoryId
                            updatedTransaction.categoryName = storedTransaction.categoryName
                        }
                        return updatedTransaction
                    }
                    break
                } catch let error as NetworkError where error.isTransactionsNotReady {
                    attempts += 1
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    continue
                }
            }
            
            if let transactions = transactions {
                self.transactions = transactions
                AppStorage.shared.storedTransactions = transactions
                calculateTotal()
            } else {
                error = "Failed to fetch transactions after multiple attempts"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func markAsPaid(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            var updatedTransaction = transaction
            updatedTransaction.isPaid = true
            updatedTransaction.paymentDate = Date()
            transactions[index] = updatedTransaction
            
            // Update stored transactions
            var storedTransactions = AppStorage.shared.storedTransactions
            if let storedIndex = storedTransactions.firstIndex(where: { 
                $0.name == transaction.name && 
                abs($0.amountValue - transaction.amountValue) < 0.01 // Compare amounts with small tolerance
            }) {
                storedTransactions[storedIndex] = updatedTransaction
            } else {
                storedTransactions.append(updatedTransaction)
            }
            AppStorage.shared.storedTransactions = storedTransactions
            calculateTotal()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        // Remove from view model
        transactions.removeAll { $0.id == transaction.id }
        
        // Remove from AppStorage
        var storedTransactions = AppStorage.shared.storedTransactions
        storedTransactions.removeAll { 
            $0.name == transaction.name && 
            abs($0.amountValue - transaction.amountValue) < 0.01 // Compare amounts with small tolerance
        }
        AppStorage.shared.storedTransactions = storedTransactions
        calculateTotal()
    }
    
    func markAsUnpaid(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            var updatedTransaction = transaction
            updatedTransaction.isPaid = false
            updatedTransaction.paymentDate = nil
            transactions[index] = updatedTransaction
            AppStorage.shared.storedTransactions = transactions
            calculateTotal()
        }
    }
    
    func updateTransaction(_ transaction: Transaction, at index: Int) {
        transactions[index] = transaction
        // Update stored transactions
        var storedTransactions = AppStorage.shared.storedTransactions
        if let storedIndex = storedTransactions.firstIndex(where: { $0.name == transaction.name && $0.date == transaction.date }) {
            storedTransactions[storedIndex] = transaction
        } else {
            storedTransactions.append(transaction)
        }
        AppStorage.shared.storedTransactions = storedTransactions
        calculateTotal()
    }
    
    func calculateTotal() {
        total = transactions
            .filter { !$0.isPaid }
            .reduce(0) { $0 + $1.amountValue }
    }
    
    func submitBillPayment() {
        isLoading = true
        error = nil
        showError = false
        
        // Filter only unpaid transactions
        let unpaidTransactions = transactions.filter { !$0.isPaid }
        
        Task {
            do {
                try await NetworkManager.shared.submitBillPayment(transactions: unpaidTransactions)
                
                // Mark transactions as paid
                let now = Date()
                transactions = transactions.map { transaction in
                    var updated = transaction
                    if !transaction.isPaid {
                        updated.isPaid = true
                        updated.paymentDate = now
                    }
                    return updated
                }
                
                // Update stored transactions
                AppStorage.shared.storedTransactions = transactions
                
                // Refresh transactions to ensure everything is up to date
                await refreshTransactions()
                
                showingConfirmation = true
                calculateTotal()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
            isLoading = false
        }
    }
    
    func loadYNABData() async {
        do {
            let budgets = try await ynabService.getBudgets()
            selectedBudget = budgets.first
            
            if let budgetId = selectedBudget?.id {
                categoryGroups = try await ynabService.getCategories(budgetId: budgetId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func categorizeTransaction(_ transaction: Transaction, withCategoryId categoryId: String) async {
        guard let budgetId = selectedBudget?.id else { return }
        
        do {
            // Get accounts and find the first credit card account
            let accounts = try await ynabService.getAccounts(budgetId: budgetId)
            guard let creditCard = accounts.first(where: { $0.type.lowercased() == "creditcard" && !$0.closed }) else {
                print("No credit card account found!")
                return
            }
            
            // Convert date string to Date object
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd, yyyy"
            let transactionDate = dateFormatter.date(from: transaction.date) ?? Date()
            
            // Convert back to YNAB expected format
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let ynabDateString = dateFormatter.string(from: transactionDate)
            
            // Create YNAB transaction
            let ynabTransaction = YNABTransaction(
                account_id: creditCard.id,
                date: ynabDateString,
                amount: Int(transaction.amountValue * -1000), // Make negative and convert to milliunits
                payee_name: transaction.name,
                category_id: categoryId,
                memo: nil,
                cleared: "cleared",
                approved: true
            )
            
            try await ynabService.createTransaction(budgetId: budgetId, transaction: ynabTransaction)
            
            // Update local transaction
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                var updatedTransaction = transaction
                updatedTransaction.categoryId = categoryId
                if let category = findCategory(id: categoryId) {
                    updatedTransaction.categoryName = category.name
                }
                updateTransaction(updatedTransaction, at: index)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func findCategory(id: String) -> Category? {
        for group in categoryGroups {
            if let category = group.categories.first(where: { $0.id == id }) {
                return category
            }
        }
        return nil
    }
    
    func updatePaymentDate(_ transaction: Transaction, to date: Date) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            var updatedTransaction = transaction
            updatedTransaction.paymentDate = date
            transactions[index] = updatedTransaction
            AppStorage.shared.storedTransactions = transactions
        }
    }
} 