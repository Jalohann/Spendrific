import SwiftUI

struct CreditCardSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [YNABAccount] = []
    @State private var isLoading = false
    @State private var error: String?
    @Binding var selectedCardId: String?
    @State private var selectedAccount: YNABAccount?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading credit cards...")
                } else if !accounts.isEmpty {
                    List(accounts) { account in
                        Button(action: {
                            print("Selected card: \(account.name) (ID: \(account.id))")
                            selectedAccount = account
                            selectedCardId = account.id
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.name)
                                        .font(.headline)
                                    Text(String(format: "Balance: $%.2f", account.balanceDecimal))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if account.id == selectedCardId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } else {
                    VStack {
                        Text("No credit cards found")
                            .font(.headline)
                        if let error = error {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Select Credit Card")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .onAppear {
                print("CreditCardSelectionView appeared with selectedCardId: \(String(describing: selectedCardId))")
            }
        }
        .task {
            await loadAccounts()
        }
    }
    
    private func loadAccounts() async {
        isLoading = true
        do {
            guard AppStorage.shared.ynabToken != nil else {
                print("No YNAB token available")
                self.error = "Please set up your YNAB account in Settings"
                isLoading = false
                return
            }
            
            let budgets = try await YNABService.shared.getBudgets()
            print("Found \(budgets.count) budgets")
            if let budgetId = budgets.first?.id {
                print("Using budget: \(budgetId)")
                let allAccounts = try await YNABService.shared.getAccounts(budgetId: budgetId)
                print("Found \(allAccounts.count) total accounts")
                print("Available accounts:")
                for account in allAccounts {
                    print("- \(account.name) (ID: \(account.id), Type: \(account.type), Closed: \(account.closed))")
                }
                
                // Filter to only show credit card accounts that aren't closed
                accounts = allAccounts.filter { 
                    let isCredit = $0.type.lowercased() == "creditcard"
                    print("Account \($0.name): type=\($0.type), isCredit=\(isCredit), closed=\($0.closed)")
                    return isCredit && !$0.closed
                }
                print("Found \(accounts.count) credit card accounts")
                
                // If we have a selectedCardId, find the matching account
                if let cardId = selectedCardId,
                   let account = accounts.first(where: { $0.id == cardId }) {
                    selectedAccount = account
                    print("Found previously selected card: \(account.name)")
                }
            } else {
                print("No budgets found!")
                self.error = "No YNAB budgets found"
            }
        } catch YNABError.noToken {
            print("No YNAB token available")
            self.error = "Please set up your YNAB account in Settings"
        } catch {
            print("Failed to load accounts: \(error)")
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 