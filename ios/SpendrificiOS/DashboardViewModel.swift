import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var processingPaymentForId: UUID?
    @Published var selectedBudget: Budget?
    @Published var showSettings = false
    @Published var recentlyPaidIds: Set<UUID> = []  // Track recently paid transactions
    @Published var error: String? = nil
    @Published var showError = false
    
    private var storageObserver: NSObjectProtocol?
    
    init() {
        // Observe AppStorage changes
        storageObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadStoredStates()
            }
        }
    }
    
    deinit {
        if let observer = storageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func loadStoredStates() async {
        let storedTransactions = AppStorage.shared.storedTransactions
        
        // First, update existing transactions
        for (index, transaction) in transactions.enumerated() {
            if let storedTransaction = storedTransactions.first(where: { $0.name == transaction.name && $0.date == transaction.date }) {
                var updatedTransaction = transaction
                updatedTransaction.isPaid = storedTransaction.isPaid
                updatedTransaction.paymentDate = storedTransaction.paymentDate
                updatedTransaction.categoryId = storedTransaction.categoryId
                updatedTransaction.categoryName = storedTransaction.categoryName
                updatedTransaction.amount = storedTransaction.amount
                transactions[index] = updatedTransaction
            }
        }
        
        // Then, add any new transactions
        let newTransactions = storedTransactions.filter { storedTransaction in
            !transactions.contains { existingTransaction in
                existingTransaction.name == storedTransaction.name && 
                existingTransaction.date == storedTransaction.date
            }
        }
        transactions.append(contentsOf: newTransactions)
        
        // Force UI update
        objectWillChange.send()
    }
    
    var filteredTransactions: [Transaction] {
        // Only show unpaid transactions in dashboard
        return Array(transactions.filter { !$0.isPaid }.prefix(5))
    }
    
    var hasUnpaidTransactions: Bool {
        !transactions.filter { !$0.isPaid }.isEmpty
    }
    
    var totalUnpaid: Double {
        transactions.filter { !$0.isPaid }.reduce(0) { total, transaction in
            total + transaction.amountValue
        }
    }
    
    func loadData() async {
        do {
            // Load card information from server
            let cardInfo = try await CardInfoService.shared.getCardInfo()
            
            // Convert CardInfo to Account object using the factory method
            accounts = [Account.from(cardInfo: cardInfo)]
            
            // Load YNAB data first to get budget and categories
            let budgets = try await YNABService.shared.getBudgets()
            selectedBudget = budgets.first
            
            if let budgetId = selectedBudget?.id {
                // Load transactions and sync with YNAB
                await refreshTransactions(budgetId: budgetId)
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    func refreshTransactions(budgetId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch local transactions
            var fetchedTransactions = try await NetworkManager.shared.fetchTransactions()
            
            // Get stored transactions to preserve paid status
            let storedTransactions = AppStorage.shared.storedTransactions
            
            // Update fetched transactions with stored paid status and payment dates
            fetchedTransactions = fetchedTransactions.map { transaction in
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
            
            // If we have a budget ID, sync with YNAB categories
            if let budgetId = budgetId {
                let categories = try await YNABService.shared.getCategories(budgetId: budgetId)
                let allCategories = categories.flatMap { $0.categories }
                
                // Try to find existing YNAB transactions to sync categories
                let accounts = try await YNABService.shared.getAccounts(budgetId: budgetId)
                if let creditCard = accounts.first(where: { $0.type.lowercased() == "creditcard" && !$0.closed }) {
                    // Update transactions with YNAB categories if they exist
                    fetchedTransactions = fetchedTransactions.map { transaction in
                        var updatedTransaction = transaction
                        
                        // Check if this transaction exists in YNAB and has a category
                        if let category = allCategories.first(where: { $0.id == transaction.categoryId }) {
                            updatedTransaction.categoryName = category.name
                        }
                        
                        return updatedTransaction
                    }
                }
            }
            
            // Update local transactions
            transactions = fetchedTransactions
            
            // Update stored transactions, preserving paid status
            AppStorage.shared.storedTransactions = fetchedTransactions
            
        } catch {
            print("Failed to load transactions: \(error)")
        }
    }
    
    func markAsPaid(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        var updatedTransaction = transaction
        updatedTransaction.isPaid = true
        updatedTransaction.paymentDate = Date()
        transactions[index] = updatedTransaction
        
        // Add to recently paid set
        recentlyPaidIds.insert(transaction.id)
        
        // Update stored transactions
        var storedTransactions = AppStorage.shared.storedTransactions
        if let storedIndex = storedTransactions.firstIndex(where: { $0.name == transaction.name && $0.date == transaction.date }) {
            storedTransactions[storedIndex] = updatedTransaction
        } else {
            storedTransactions.append(updatedTransaction)
        }
        AppStorage.shared.storedTransactions = storedTransactions
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        
        // Update stored transactions
        var storedTransactions = AppStorage.shared.storedTransactions
        storedTransactions.removeAll { $0.name == transaction.name && $0.date == transaction.date }
        AppStorage.shared.storedTransactions = storedTransactions
    }
    
    @MainActor
    func initiatePayment(for transaction: Transaction) async {
        guard !transaction.isPaid else { return }
        
        processingPaymentForId = transaction.id
        error = nil
        showError = false
        
        do {
            try await NetworkManager.shared.submitBillPayment(transactions: [transaction])
            try await Task.sleep(nanoseconds: 1_000_000_000) // Add 1 second delay for animation
            markAsPaid(transaction)
            // Refresh data after successful payment
            if let budgetId = selectedBudget?.id {
                await refreshTransactions(budgetId: budgetId)
            }
            processingPaymentForId = nil
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            processingPaymentForId = nil
        }
    }
    
    @MainActor
    func submitBillPayment() async {
        let unpaidTransactions = transactions.filter { !$0.isPaid }
        error = nil
        showError = false
        
        do {
            try await NetworkManager.shared.submitBillPayment(transactions: unpaidTransactions)
            for transaction in unpaidTransactions {
                markAsPaid(transaction)
            }
            // Refresh data after successful bulk payment
            if let budgetId = selectedBudget?.id {
                await refreshTransactions(budgetId: budgetId)
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
    
    func categorizeTransaction(_ transaction: Transaction, withCategoryId categoryId: String) async {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        var updatedTransaction = transaction
        updatedTransaction.categoryId = categoryId
        
        // Add transaction to YNAB with the selected category
        do {
            // Convert date string to Date object
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd, yyyy"
            let transactionDate = dateFormatter.date(from: transaction.date) ?? Date()
            
            // Convert back to YNAB expected format
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let ynabDateString = dateFormatter.string(from: transactionDate)
            
            // Get budgets and accounts
            let budgets = try await YNABService.shared.getBudgets()
            guard let budgetId = budgets.first?.id else {
                print("No budgets found!")
                return
            }
            
            // Get accounts and find the first credit card account
            let accounts = try await YNABService.shared.getAccounts(budgetId: budgetId)
            guard let creditCard = accounts.first(where: { $0.type.lowercased() == "creditcard" && !$0.closed }) else {
                print("No credit card account found!")
                return
            }
            
            try await YNABService.shared.createTransaction(
                budgetId: budgetId,
                transaction: YNABTransaction(
                    account_id: creditCard.id,
                    date: ynabDateString,
                    amount: Int(transaction.amountValue * -1000), // Make negative and convert to milliunits
                    payee_name: transaction.name,
                    category_id: categoryId,
                    memo: nil,
                    cleared: "uncleared", // Mark as uncleared since it's pending
                    approved: true
                )
            )
            
            // Get category name
            let categories = try await YNABService.shared.getCategories(budgetId: budgetId)
            if let category = categories.flatMap({ $0.categories }).first(where: { $0.id == categoryId }) {
                updatedTransaction.categoryName = category.name
            }
            
            // Update on main actor
            await MainActor.run {
                transactions[index] = updatedTransaction
                
                // Update stored transactions
                var storedTransactions = AppStorage.shared.storedTransactions
                if let storedIndex = storedTransactions.firstIndex(where: { $0.name == transaction.name && $0.date == transaction.date }) {
                    storedTransactions[storedIndex] = updatedTransaction
                } else {
                    storedTransactions.append(updatedTransaction)
                }
                AppStorage.shared.storedTransactions = storedTransactions
            }
        } catch {
            print("Failed to create YNAB transaction: \(error)")
        }
    }
    
    func clearRecentlyPaid() {
        recentlyPaidIds.removeAll()
    }
} 