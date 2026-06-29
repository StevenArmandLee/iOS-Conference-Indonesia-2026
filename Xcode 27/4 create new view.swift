// xcode: set sdk=iOS

//
//  MVVM present view.swift
//  MVVM
//
//  Created by steven lee on 21/6/26.
//

import Foundation
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

// MARK: - List ViewModel

@MainActor
protocol UserViewModelProtocol: ObservableObject {
    var state: ViewState<[User]> { get set }
    func loadUsers() async
}

@MainActor
class UserViewModel: UserViewModelProtocol {
    @Published var state: ViewState<[User]> = .idle

    func loadUsers() async {
        state = .loading

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

// MARK: - Detail ViewModel

@MainActor
protocol UserDetailViewModelProtocol: ObservableObject {
    var user: User { get }
    var isFavorite: Bool { get }
    func toggleFavorite()
}

@MainActor
class UserDetailViewModel: UserDetailViewModelProtocol {
    let user: User
    @Published var isFavorite: Bool = false

    init(user: User) {
        self.user = user
    }

    func toggleFavorite() {
        isFavorite.toggle()
    }
}

// MARK: - Detail View

struct UserDetailView<ViewModel: UserDetailViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text(viewModel.user.name)
                .font(.title)
                .fontWeight(.bold)

            Text(viewModel.user.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.toggleFavorite()
            } label: {
                Label(
                    viewModel.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: viewModel.isFavorite ? "heart.fill" : "heart"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

// MARK: - List View

struct UserListView<ViewModel: UserViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel
    @State private var selectedUser: User?

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
                    Button {
                        selectedUser = user
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name).font(.headline)
                            Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
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
        .sheet(item: $selectedUser) { user in
            UserDetailView(viewModel: UserDetailViewModel(user: user)) //MARK: - Here we push other view
            
        }
    }
}


@MainActor
class MockUserViewModel: UserViewModelProtocol {
    @Published var state: ViewState<[User]> = .loaded([
        User(id: UUID(), name: "Alice", email: "alice@example.com"),
        User(id: UUID(), name: "Bob",   email: "bob@example.com"),
    ])

    func loadUsers() async {}
}

@MainActor
class MockUserDetailViewModel: UserDetailViewModelProtocol {
    let user = User(id: UUID(), name: "Alice", email: "alice@example.com")
    @Published var isFavorite: Bool = false

    func toggleFavorite() { isFavorite.toggle() }
}

#Preview("List") {
    UserListView(viewModel: MockUserViewModel())
}

#Preview("Detail") {
    UserDetailView(viewModel: MockUserDetailViewModel())
}
