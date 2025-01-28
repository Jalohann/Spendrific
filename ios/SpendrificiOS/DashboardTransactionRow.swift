import SwiftUI

struct DashboardTransactionRow: View {
    let transaction: Transaction
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showingCategorySelector = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.name)
                        .font(.system(size: 16, weight: .medium))
                    Text(transaction.date)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.processingPaymentForId == transaction.id {
                    // Show loading indicator when payment is processing
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Text(transaction.formattedAmount)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            
            Button(action: { showingCategorySelector = true }) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12))
                    Text(transaction.categoryName ?? "Select Category")
                        .font(.system(size: 13))
                }
                .foregroundColor(transaction.categoryName == nil ? .blue : .secondary)
                .padding(.top, 4)
            }
            .disabled(viewModel.processingPaymentForId == transaction.id)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .opacity(viewModel.processingPaymentForId == transaction.id ? 0.6 : 1.0)
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectionView(
                transaction: transaction,
                selectedCategoryId: Binding(
                    get: { transaction.categoryId },
                    set: { newCategoryId in
                        if let categoryId = newCategoryId {
                            Task {
                                await viewModel.categorizeTransaction(transaction, withCategoryId: categoryId)
                            }
                        }
                    }
                )
            )
        }
    }
}

#Preview {
    DashboardTransactionRow(
        transaction: Transaction.sample,
        viewModel: DashboardViewModel()
    )
} 