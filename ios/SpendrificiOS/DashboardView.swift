import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showSettings = false
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Greeting
                    Text("\(greeting), \(AppStorage.shared.userName)")
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                    
                    // Accounts Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Credit Cards")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.accounts) { account in
                            AccountCard(account: account)
                        }
                    }
                    
                    // Transactions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Transactions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List(viewModel.filteredTransactions) { transaction in
                            DashboardTransactionRow(transaction: transaction, viewModel: viewModel)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteTransaction(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    if !transaction.isPaid {
                                        Button {
                                            viewModel.markAsPaid(transaction)
                                        } label: {
                                            Label("Mark Paid", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if !transaction.isPaid {
                                        Button {
                                            Task {
                                                await viewModel.initiatePayment(for: transaction)
                                            }
                                        } label: {
                                            Label("Pay", systemImage: "dollarsign.circle.fill")
                                        }
                                        .tint(.blue)
                                    }
                                }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(viewModel.filteredTransactions.count) * 120)
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showSettings = true
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onDisappear {
                viewModel.clearRecentlyPaid()
            }
        }
        .task {
            await viewModel.loadData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error ?? "An unknown error occurred")
        }
    }
}

#Preview {
    DashboardView()
} 