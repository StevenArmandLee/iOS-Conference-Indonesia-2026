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
class UserViewModel: ObservableObject {
    @Published var state: ViewState<[User]> = .idle

    func loadUsers() async {
        state = .loading

        // Simulate a network request
        do {
            try await Task.sleep(for: .seconds(2))
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

struct UserListView: View {
    @State private var viewModel = UserViewModel()

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

#Preview {
    NavigationStack {
        UserListView()
    }
}
