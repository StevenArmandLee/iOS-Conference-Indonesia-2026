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

// MARK: - Cell ViewModel

@MainActor
protocol UserCellViewModelProtocol: ObservableObject {
    var user: User { get }
    func onTap()
}

@MainActor
class UserCellViewModel: UserCellViewModelProtocol {
    let user: User
    private let onTapAction: () -> Void

    init(user: User, onTap: @escaping () -> Void) {
        self.user = user
        self.onTapAction = onTap
    }

    func onTap() {
        onTapAction()
    }
}

// MARK: - Cell View

struct UserCellView<ViewModel: UserCellViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            viewModel.onTap()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.user.name).font(.headline)
                Text(viewModel.user.email).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Cell Builder
// Standalone module — any screen can reuse UserCellBuilder without knowing its internals

protocol UserCellBuildable {
    associatedtype CellContent: View
    @ViewBuilder @MainActor func buildCell(user: User, onTap: @escaping () -> Void) -> CellContent
}

class UserCellBuilder: UserCellBuildable {
    @ViewBuilder @MainActor func buildCell(user: User, onTap: @escaping () -> Void) -> some View {
        let viewModel: some UserCellViewModelProtocol = UserCellViewModel(user: user, onTap: onTap)
        UserCellView(viewModel: viewModel)
    }
}

// MARK: - Detail Builder

protocol UserDetailBuildable {
    associatedtype Screen: View
    associatedtype CellContent: View
    @ViewBuilder @MainActor func build(user: User) -> Screen
    @ViewBuilder @MainActor func buildCell(user: User, onTap: @escaping () -> Void) -> CellContent
}

class UserDetailBuilder: UserDetailBuildable {
    private let cellBuilder = UserCellBuilder()

    @ViewBuilder @MainActor func build(user: User) -> some View {
        let viewModel: some UserDetailViewModelProtocol = UserDetailViewModel(user: user)
        UserDetailView(viewModel: viewModel)
    }

    @ViewBuilder @MainActor func buildCell(user: User, onTap: @escaping () -> Void) -> some View {
        cellBuilder.buildCell(user: user, onTap: onTap)
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

struct UserListView<ViewModel: UserViewModelProtocol, Builder: UserDetailBuildable>: View {
    @ObservedObject private var viewModel: ViewModel
    @State private var selectedUser: User?
    private let builder: Builder

    init(viewModel: ViewModel, builder: Builder) {
        self.viewModel = viewModel
        self.builder = builder
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
                    builder.buildCell(user: user, onTap: { selectedUser = user })
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
            builder.build(user: user)
        }
    }
}

// MARK: - Preview







#Preview("List") {
    @MainActor
    class MockUserDetailViewModel: UserDetailViewModelProtocol {
        let user = User(id: UUID(), name: "Alice", email: "alice@example.com")
        @Published var isFavorite: Bool = false

        func toggleFavorite() { isFavorite.toggle() }
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
    class MockUserDetailBuilder: UserDetailBuildable {
        private let cellBuilder = UserCellBuilder()

        @ViewBuilder @MainActor func build(user: User) -> some View {
            UserDetailView(viewModel: MockUserDetailViewModel())
        }

        @ViewBuilder @MainActor func buildCell(user: User, onTap: @escaping () -> Void) -> some View {
            cellBuilder.buildCell(user: user, onTap: onTap)
        }
    }
    return UserListView(viewModel: MockUserViewModel(), builder: MockUserDetailBuilder())
}

#Preview("Detail") {
    @MainActor
    class MockUserDetailViewModel: UserDetailViewModelProtocol {
        let user = User(id: UUID(), name: "Alice", email: "alice@example.com")
        @Published var isFavorite: Bool = false

        func toggleFavorite() { isFavorite.toggle() }
    }
    return UserDetailView(viewModel: MockUserDetailViewModel())
}

#Preview("Cell") {
    UserCellView(viewModel: UserCellViewModel(user: User(id: UUID(), name: "Alice", email: "alice@example.com"), onTap: {}))
}
