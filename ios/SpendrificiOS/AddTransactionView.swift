import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var name = ""
    @State private var selectedCategoryId: String?
    @State private var selectedCardId: String?
    @State private var showingCategoryPicker = false
    @State private var showingCardPicker = false
    @State private var showingSettings = false
    @State private var isLoading = false
    @State private var error: String?
    
    // Create a transaction object for the pickers
    private var transaction: Transaction {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        var transaction = Transaction(
            date: dateFormatter.string(from: Date()),
            name: name.isEmpty ? "Untitled Transaction" : name,
            amount: amount
        )
        transaction.categoryId = selectedCategoryId
        return transaction
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Name/Description", text: $name)
                }
                
                Section {
                    Button(action: {
                        showingCardPicker = true
                    }) {
                        HStack {
                            Text("Credit Card")
                            Spacer()
                            Text(selectedCardId != nil ? "Selected" : "Select Card")
                                .foregroundColor(selectedCardId == nil ? .gray : .primary)
                        }
                    }
                    .onChange(of: selectedCardId) { oldValue, newValue in
                        print("Card ID changed from: \(String(describing: oldValue)) to: \(String(describing: newValue))")
                    }
                    
                    Button(action: {
                        showingCategoryPicker = true
                    }) {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(selectedCategoryId != nil ? "Selected" : "Select Category")
                                .foregroundColor(selectedCategoryId == nil ? .gray : .primary)
                        }
                    }
                }
                
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await addTransaction()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Add Transaction")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarItems(
                leading: Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                },
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
            .sheet(isPresented: $showingCategoryPicker) {
                NavigationView {
                    CategorySelectionView(
                        transaction: transaction,
                        selectedCategoryId: $selectedCategoryId
                    )
                }
            }
            .sheet(isPresented: $showingCardPicker) {
                NavigationView {
                    CreditCardSelectionView(selectedCardId: $selectedCardId)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private var isValid: Bool {
        guard let amountDouble = Double(amount),
              amountDouble > 0,
              !name.isEmpty,
              selectedCategoryId != nil,
              selectedCardId != nil else {
            return false
        }
        return true
    }
    
    private func addTransaction() async {
        guard let amountDouble = Double(amount),
              let categoryId = selectedCategoryId,
              let accountId = selectedCardId else {
            print("Validation failed:")
            print("- Amount: \(amount)")
            print("- Category ID: \(String(describing: selectedCategoryId))")
            print("- Account ID: \(String(describing: selectedCardId))")
            self.error = "Please fill in all required fields"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let budgets = try await YNABService.shared.getBudgets()
            print("Found \(budgets.count) budgets")
            guard let budgetId = budgets.first?.id else {
                print("No budgets found!")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No budget found"])
            }
            print("Using budget: \(budgetId)")
            
            // Create YNAB transaction
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let ynabDateString = dateFormatter.string(from: Date())
            
            print("Creating YNAB transaction with:")
            print("- Budget ID: \(budgetId)")
            print("- Account ID: \(accountId)")
            print("- Category ID: \(categoryId)")
            print("- Amount: \(-amountDouble * 1000)")
            print("- Name: \(name)")
            
            let ynabTransaction = YNABTransaction(
                account_id: accountId,
                date: ynabDateString,
                amount: Int(-amountDouble * 1000), // Convert to milliunits and make negative
                payee_name: name,
                category_id: categoryId,
                memo: nil,
                cleared: "uncleared", // Mark as uncleared since it's pending
                approved: true
            )
            
            try await YNABService.shared.createTransaction(budgetId: budgetId, transaction: ynabTransaction)
            print("Transaction created successfully!")
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("YNAB Transaction creation failed with error: \(error)")
            await MainActor.run {
                self.error = "Failed to create transaction: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
} 