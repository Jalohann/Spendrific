import SwiftUI

struct TransactionListView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @State private var showPaidTransactions = false
    @State private var selectedTransaction: Transaction?
    @State private var showingDatePicker = false
    @State private var selectedDate: Date
    @State private var isRefreshing = false
    @State private var processingPaymentForId: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: TransactionsViewModel) {
        self.viewModel = viewModel
        _selectedDate = State(initialValue: Date())
    }
    
    var filteredTransactions: [Transaction] {
        viewModel.transactions.filter { transaction in
            showPaidTransactions || !transaction.isPaid || processingPaymentForId == transaction.id
        }
    }
    
    var hasUnpaidTransactions: Bool {
        !viewModel.transactions.filter { !$0.isPaid }.isEmpty
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        withAnimation {
            viewModel.deleteTransaction(transaction)
        }
    }
    
    private func onSave(_ date: Date) {
        if let transaction = selectedTransaction,
           let index = viewModel.transactions.firstIndex(where: { $0.id == transaction.id }) {
            var updatedTransaction = transaction
            updatedTransaction.paymentDate = date
            viewModel.updateTransaction(updatedTransaction, at: index)
            showingDatePicker = false
        }
    }
    
    private func markAsPaid(_ transaction: Transaction) {
        withAnimation {
            processingPaymentForId = transaction.id
            viewModel.markAsPaid(transaction)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    processingPaymentForId = nil
                }
            }
        }
    }
    
    private func startRefresh() async {
        isRefreshing = true
        
        do {
            // First verify server is up
            try await NetworkManager.shared.verifyServerConnection()
            
            // Start a background task for refreshing transactions
            await viewModel.refreshTransactions()
            
            // Only set isRefreshing to false after the task completes
            isRefreshing = false
        } catch {
            print("Server error or refresh cancelled: \(error.localizedDescription)")
            isRefreshing = false
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Fetching transactions...")
                            Spacer()
                        }
                        .padding()
                    }
                    
                    Toggle("Show Paid Transactions", isOn: $showPaidTransactions)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                    
                    if filteredTransactions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text(showPaidTransactions ? "No Paid Transactions" : "No New Transactions")
                                .font(.headline)
                            
                            if !showPaidTransactions && !hasUnpaidTransactions {
                                Text("Do the Debt Free dance! 💃")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    
                    ForEach(filteredTransactions) { transaction in
                        List {
                            TransactionRow(
                                transaction: transaction,
                                onUpdate: { updatedTransaction in
                                    if let index = viewModel.transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
                                        viewModel.updateTransaction(updatedTransaction, at: index)
                                    }
                                },
                                viewModel: viewModel
                            )
                            .opacity(transaction.isPaid && processingPaymentForId != transaction.id ? 0.6 : 1.0)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color(UIColor.systemBackground))
                            .swipeActions(edge: .leading) {
                                if transaction.isPaid {
                                    Button {
                                        viewModel.markAsUnpaid(transaction)
                                    } label: {
                                        Label("Mark Unpaid", systemImage: "xmark.circle.fill")
                                    }
                                    .tint(.orange)
                                    
                                    Button {
                                        selectedTransaction = transaction
                                        selectedDate = transaction.paymentDate ?? Date()
                                        showingDatePicker = true
                                    } label: {
                                        Label("Edit Date", systemImage: "calendar")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                if !transaction.isPaid {
                                    Button {
                                        markAsPaid(transaction)
                                    } label: {
                                        Label("Mark Paid", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: 120)
                        .background(Color(UIColor.systemBackground))
                        .scrollDisabled(true)
                    }
                    
                    if hasUnpaidTransactions {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Total Unpaid")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "$%.2f", viewModel.total))
                                    .font(.headline)
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            
                            Button(action: {
                                viewModel.submitBillPayment()
                            }) {
                                Text("Submit Bill Payment")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(viewModel.isLoading)
                            .padding()
                        }
                    }
                }
            }
            .refreshable {
                await startRefresh()
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            if let transaction = selectedTransaction {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        
                        Spacer()
                    }
                    .navigationTitle("Adjust Payment Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                onSave(selectedDate)
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error ?? "An unknown error occurred")
        }
    }
} 