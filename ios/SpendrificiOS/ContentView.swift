import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TransactionsViewModel()
    @State private var userName: String = AppStorage.shared.userName
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerView
                    
                    // Cards Section
                    cardsSection
                    
                    // Budget Section
                    budgetSection
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    settingsButton
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good \(timeOfDay),")
                .font(.title)
            Text(userName)
                .font(.title.bold())
        }
        .padding(.horizontal)
    }
    
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Credit Cards")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.accounts) { account in
                        NavigationLink(destination: AccountDetailView(account: account)) {
                            CardView(account: account)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budget: Spring 2025")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var settingsButton: some View {
        Menu {
            Button(action: { showingSettings = true }) {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title2)
                .foregroundColor(.primary)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
    }
    
    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}

#Preview {
    ContentView()
} 