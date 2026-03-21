import AuthenticationServices
import SwiftUI

public struct SignInView: View {
    @ObservedObject private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Amon")
                            .font(.largeTitle.bold())

                        Text("Private by default. Deeper when needed.")
                            .font(.title3.weight(.medium))

                        Text("A calm place to search, save, compare, and synthesize without turning your work into server history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    AmonTrustStripView(items: ["Saved locally", "No server history", "Backend broker only"])

                    if let banner = viewModel.banner {
                        AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sign in")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = []
                            },
                            onCompletion: { result in
                                switch result {
                                case .success(let authorization):
                                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                        viewModel.banner = AmonBanner(
                                            tone: .error,
                                            title: "Couldn't read Apple ID",
                                            message: "Amon couldn't read the Apple credential returned by the system."
                                        )
                                        return
                                    }
                                    Task {
                                        await viewModel.signIn(appleSubject: credential.user)
                                    }
                                case .failure(let error):
                                    viewModel.banner = AmonBanner(
                                        tone: .error,
                                        title: "Sign in cancelled",
                                        message: AmonErrorPresenter.message(
                                            for: error,
                                            fallback: "Amon couldn't complete Apple sign in."
                                        )
                                    )
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .disabled(viewModel.isSigningIn)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Local development")
                                .font(.subheadline.weight(.semibold))
                            Text("Use the dev path while your local backend is running.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button {
                                Task {
                                    await viewModel.signIn(appleSubject: "dev-ben-local")
                                }
                            } label: {
                                HStack {
                                    if viewModel.isSigningIn {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                    }
                                    Text("Dev Sign In")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(viewModel.isSigningIn)
                        }
                        .amonCardStyle()
                    }
                    .amonCardStyle(padding: 20)
                }
                .padding(20)
                .frame(maxWidth: 560)
            }
        }
    }
}
