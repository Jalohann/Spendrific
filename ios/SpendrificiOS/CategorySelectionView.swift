import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction
    @Binding var selectedCategoryId: String?
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading categories...")
                } else if !categories.isEmpty {
                    List(categories) { category in
                        Button(action: {
                            selectedCategoryId = category.id
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(category.name)
                                        .font(.headline)
                                    Text(String(format: "Available: $%.2f", category.balanceDecimal))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if category.id == selectedCategoryId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } else {
                    VStack {
                        Text("No categories found")
                            .font(.headline)
                        if let error = error {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
        .task {
            await loadCategories()
        }
    }
    
    private func loadCategories() async {
        isLoading = true
        do {
            let budgets = try await YNABService.shared.getBudgets()
            if let budgetId = budgets.first?.id {
                let categoryGroups = try await YNABService.shared.getCategories(budgetId: budgetId)
                // Filter out inflow and credit card categories, then flatten into a single array
                categories = categoryGroups
                    .filter { !$0.name.contains("Credit Card") } // Filter out credit card groups
                    .flatMap { $0.categories }
                    .filter { !$0.name.contains("Inflow") } // Filter out inflow categories
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 