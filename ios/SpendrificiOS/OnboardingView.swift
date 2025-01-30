import SwiftUI

struct OnboardingView: View {
    @State private var showServerConfig = false
    @State private var hasCompletedOnboarding = false
    
    var body: some View {
        if !hasCompletedOnboarding {
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon
                Image(systemName: "dollarsign.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                // Welcome Text
                VStack(spacing: 16) {
                    Text("Welcome to Spendrific")
                        .font(.system(size: 34, weight: .bold))
                    
                    Text("Your personal finance automation tool")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Privacy Notice
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Privacy & Security")
                        .font(.headline)
                    
                    Text("Spendrific prioritizes your privacy by not storing any sensitive data. All bank accounts and financial information must be manually hosted on your own server. While secure remote hosting options may be available in the future, this local-first approach ensures you maintain complete control over your data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Continue Button
                Button(action: {
                    showServerConfig = true
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
                .sheet(isPresented: $showServerConfig) {
                    ServerConfigView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .padding()
            .onAppear {
                hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            }
        } else {
            DashboardView()
        }
    }
}

struct ServerConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasCompletedOnboarding: Bool
    @State private var serverAddress: String = "localhost"
    @State private var port: String = "5001"
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    TextField("Server Address", text: $serverAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                
                Section(footer: Text("Enter the address and port of your Flask server")) {
                    Button(action: {
                        Task {
                            await verifyAndConnect()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Connect")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Server Setup")
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .disabled(isLoading)
        }
    }
    
    private func verifyAndConnect() async {
        isLoading = true
        
        // Store server details in UserDefaults
        UserDefaults.standard.set("\(serverAddress):\(port)", forKey: "serverAddress")
        
        // Update NetworkManager base URL
        NetworkManager.shared.updateBaseURL(server: serverAddress, port: port)
        
        do {
            // Verify connection
            try await NetworkManager.shared.verifyServerConnection()
            
            // Trigger transaction fetch which will run the chase script
            try await NetworkManager.shared.triggerTransactionFetch()
            
            // Poll for transactions with timeout
            var attempts = 0
            while attempts < 10 {
                do {
                    _ = try await NetworkManager.shared.getTransactions()
                    // If we get here, transactions are ready
                    break
                } catch let error as NetworkError where error.isTransactionsNotReady {
                    attempts += 1
                    if attempts >= 10 {
                        throw error
                    }
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second wait between attempts
                    continue
                }
            }
            
            // Complete onboarding
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            hasCompletedOnboarding = true
            dismiss()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 