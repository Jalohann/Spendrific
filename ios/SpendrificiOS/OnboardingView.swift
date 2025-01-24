import SwiftUI

struct OnboardingView: View {
    @State private var showServerConfig = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
        } else {
            ContentView()
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
                    Button("Connect") {
                        verifyAndConnect()
                    }
                }
            }
            .navigationTitle("Server Setup")
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func verifyAndConnect() {
        // Store server details in UserDefaults
        UserDefaults.standard.set("\(serverAddress):\(port)", forKey: "serverAddress")
        
        // Update NetworkManager base URL
        NetworkManager.shared.updateBaseURL(server: serverAddress, port: port)
        
        // Verify connection
        Task {
            do {
                try await NetworkManager.shared.verifyServerConnection()
                hasCompletedOnboarding = true
                dismiss()
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 