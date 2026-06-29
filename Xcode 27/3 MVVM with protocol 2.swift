// xcode: set sdk=iOS

import SwiftUI

// MARK: - Model

struct User: Identifiable {
    let id: UUID
    let name: String
    let email: String
}

// MARK: - State

enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}

@MainActor
protocol UserViewModelProtocol: ObservableObject {
    var state : ViewState<[User]> { get set }
    func loadUsers() async
}

@MainActor
class UserViewModel: UserViewModelProtocol {
    @Published var state: ViewState<[User]> = .idle

    func loadUsers() async {
        state = .loading

        // Simulate a network request
        do {
            try await Task.sleep(for: .seconds(2))

            // In a real app this would be URLSession — but in previews it
            // just hangs here, so you never see .loaded or .error.
            let users = [
                User(id: UUID(), name: "Alice", email: "alice@example.com"),
                User(id: UUID(), name: "Bob",   email: "bob@example.com"),
            ]
            state = .loaded(users)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: - View
//With this basically you are telling the compiler I don't know the exact type yet, but I promise whoever uses this view must provide one, and it must follow this protocol contract.
struct UserListView<ViewModel: UserViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                Button("Load Users") {
                    Task { await viewModel.loadUsers() }
                }

            case .loading:
                ProgressView("Loading…")

            case .loaded(let users):
                List(users) { user in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name).font(.headline)
                        Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(message)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.loadUsers() }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Users")
        .task { await viewModel.loadUsers() }
    }
}

// MARK: - Preview

@MainActor
class MockUserViewModel: UserViewModelProtocol {
    @Published var state: ViewState<[User]> = .loading

    func loadUsers() async {
    }
}

#Preview {
    UserListView(viewModel: MockUserViewModel())
}
