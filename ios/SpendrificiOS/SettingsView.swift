import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serverAddress = AppStorage.shared.serverAddress
    @State private var userName = AppStorage.shared.userName
    @State private var showingConfirmation = false
    @State private var ynabToken = AppStorage.shared.ynabToken ?? ""
    @State private var isTestingToken = false
    @State private var testResult: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("User") {
                    TextField("Name", text: $userName)
                }
                
                Section("Server") {
                    TextField("Server Address", text: $serverAddress)
                }
                
                Section(header: Text("YNAB Settings")) {
                    SecureField("YNAB Access Token", text: $ynabToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !ynabToken.isEmpty {
                        Button(action: {
                            Task {
                                await testToken()
                            }
                        }) {
                            if isTestingToken {
                                ProgressView()
                            } else {
                                Text("Test Connection")
                            }
                        }
                    }
                    
                    if let result = testResult {
                        Text(result)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
                
                Section {
                    Link("Get YNAB Token",
                         destination: URL(string: "https://app.ynab.com/settings/developer")!)
                }
                
                Section(header: Text("Instructions")) {
                    Text("1. Click 'Get YNAB Token' above to go to YNAB settings")
                    Text("2. Sign in to your YNAB account")
                    Text("3. Under 'Developer Settings', click 'New Token'")
                    Text("4. Copy the token and paste it here")
                    Text("5. Click 'Test Connection' to verify")
                }
                
                Section {
                    Button("Save") {
                        AppStorage.shared.serverAddress = serverAddress
                        AppStorage.shared.userName = userName
                        showingConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        AppStorage.shared.reset()
                        dismiss()
                    }) {
                        Text("Reset App")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Settings Saved", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            }
        }
    }
    
    private func testToken() async {
        isTestingToken = true
        testResult = nil
        
        AppStorage.shared.ynabToken = ynabToken
        
        do {
            let budgets = try await YNABService.shared.getBudgets()
            testResult = "Success! Found \(budgets.count) budget(s)"
        } catch {
            testResult = "Error: \(error.localizedDescription)"
        }
        
        isTestingToken = false
    }
}

#Preview {
    SettingsView()
} 