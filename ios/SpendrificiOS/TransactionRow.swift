import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    let onUpdate: (Transaction) -> Void
    @ObservedObject var viewModel: TransactionsViewModel
    
    @State private var amount: String
    @State private var showingCategorySelector = false
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    
    init(transaction: Transaction, onUpdate: @escaping (Transaction) -> Void, viewModel: TransactionsViewModel) {
        self.transaction = transaction
        self.onUpdate = onUpdate
        self.viewModel = viewModel
        _amount = State(initialValue: transaction.amount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(transaction.name)
                    .font(.headline)
                Spacer()
                if transaction.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(transaction.date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !transaction.isPaid {
                TextField("Amount", text: $amount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .onSubmit {
                        updateAmount()
                    }
                    .onChange(of: amount) { _ in
                        // Don't update the transaction here
                    }
                
                Button(action: { showingCategorySelector = true }) {
                    HStack {
                        if let categoryName = transaction.categoryName {
                            Text(categoryName)
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Label("Select Category", systemImage: "tag")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else if let paymentDate = transaction.paymentDate {
                Text("Paid on \(paymentDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onDisappear {
            updateAmount()
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectionView(
                transaction: transaction,
                selectedCategoryId: Binding(
                    get: { transaction.categoryId },
                    set: { newCategoryId in
                        if let categoryId = newCategoryId {
                            Task {
                                // Get the budgets and accounts from YNAB
                                do {
                                    let budgets = try await YNABService.shared.getBudgets()
                                    guard let budgetId = budgets.first?.id else { return }
                                    
                                    // Convert date string to Date object
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "MMM dd, yyyy"
                                    let transactionDate = dateFormatter.date(from: transaction.date) ?? Date()
                                    
                                    // Convert back to YNAB expected format
                                    dateFormatter.dateFormat = "yyyy-MM-dd"
                                    let ynabDateString = dateFormatter.string(from: transactionDate)
                                    
                                    // Get accounts and find the first credit card account
                                    let accounts = try await YNABService.shared.getAccounts(budgetId: budgetId)
                                    guard let creditCard = accounts.first(where: { $0.type.lowercased() == "creditcard" && !$0.closed }) else {
                                        return
                                    }
                                    
                                    // Create YNAB transaction
                                    try await YNABService.shared.createTransaction(
                                        budgetId: budgetId,
                                        transaction: YNABTransaction(
                                            account_id: creditCard.id,
                                            date: ynabDateString,
                                            amount: Int(transaction.amountValue * -1000),
                                            payee_name: transaction.name,
                                            category_id: categoryId,
                                            memo: nil,
                                            cleared: "uncleared",
                                            approved: true
                                        )
                                    )
                                    
                                    // Get category name
                                    let categories = try await YNABService.shared.getCategories(budgetId: budgetId)
                                    if let category = categories.flatMap({ $0.categories }).first(where: { $0.id == categoryId }) {
                                        var updatedTransaction = transaction
                                        updatedTransaction.categoryId = categoryId
                                        updatedTransaction.categoryName = category.name
                                        
                                        // Update in TransactionsViewModel
                                        if let index = viewModel.transactions.firstIndex(where: { $0.id == transaction.id }) {
                                            viewModel.updateTransaction(updatedTransaction, at: index)
                                        }
                                    }
                                } catch {
                                    print("Failed to update YNAB transaction: \(error)")
                                }
                            }
                        }
                    }
                )
            )
        }
        .onChange(of: showDatePicker) { _, isShowing in
            if !isShowing {
                viewModel.updatePaymentDate(transaction, to: selectedDate)
            }
        }
    }
    
    private func updateAmount() {
        var updatedTransaction = transaction
        updatedTransaction.amount = amount
        onUpdate(updatedTransaction)
    }
}

#Preview {
    TransactionRow(
        transaction: Transaction.sample,
        onUpdate: { _ in },
        viewModel: TransactionsViewModel()
    )
} 