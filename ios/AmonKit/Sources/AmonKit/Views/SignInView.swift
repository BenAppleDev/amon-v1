import AuthenticationServices
import SwiftUI

public struct SignInView: View {
    @ObservedObject private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Amon")
                .font(.largeTitle.weight(.semibold))
            Text("Private by default. Deeper when needed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                switch result {
                case .success(let authResults):
                    guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
                    Task {
                        await viewModel.completeAppleDevSignIn(subject: credential.user)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)

            Text("Local starter: the Apple subject is sent to the dev auth endpoint. Swap to verified id_token exchange when you add production backend auth.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
