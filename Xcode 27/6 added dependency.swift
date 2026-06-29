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

// MARK: - Favorites Service

protocol FavoritesServiceProtocol {
    func isFavorite(userID: UUID) -> Bool
    func toggleFavorite(userID: UUID)
}

@Observable
class FavoritesService: FavoritesServiceProtocol {
    private var favoriteIDs: Set<UUID> = []

    func isFavorite(userID: UUID) -> Bool {
        favoriteIDs.contains(userID)
    }

    func toggleFavorite(userID: UUID) {
        if favoriteIDs.contains(userID) {
            favoriteIDs.remove(userID)
        } else {
            favoriteIDs.insert(userID)
        }
    }
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
    @Published var isFavorite: Bool
    private let favoritesService: FavoritesServiceProtocol

    init(user: User, favoritesService: FavoritesServiceProtocol) {
        self.user = user
        self.favoritesService = favoritesService
        self.isFavorite = favoritesService.isFavorite(userID: user.id)
    }

    func toggleFavorite() {
        favoritesService.toggleFavorite(userID: user.id)
        isFavorite = favoritesService.isFavorite(userID: user.id)
    }
}

// MARK: - Cell ViewModel

@MainActor
protocol UserCellViewModelProtocol: ObservableObject {
    var user: User { get }
    var isFavorite: Bool { get }
    func onTap()
}

@MainActor
class UserCellViewModel: UserCellViewModelProtocol {
    let user: User
    @Published var isFavorite: Bool
    private let onTapAction: () -> Void

    init(user: User, isFavorite: Bool, onTap: @escaping () -> Void) {
        self.user = user
        self.isFavorite = isFavorite
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.user.name).font(.headline)
                    Text(viewModel.user.email).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isFavorite {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Cell Dependency & Component

@MainActor
protocol UserCellDependency {
    var favoritesService: FavoritesService { get }
}

@MainActor
class UserCellComponent: UserCellDependency {
    let favoritesService: FavoritesService

    init(dependency: UserCellDependency) {
        self.favoritesService = dependency.favoritesService
    }
}

// MARK: - Cell Builder
// Standalone module — any screen can reuse UserCellBuilder with its own component

protocol UserCellBuildable {
    associatedtype CellContent: View
    @ViewBuilder @MainActor func buildCell(user: User, isFavorite: Bool, onTap: @escaping () -> Void) -> CellContent
}

@MainActor
class UserCellBuilder: UserCellBuildable {
    private let component: UserCellComponent

    init(component: UserCellComponent) {
        self.component = component
    }

    @ViewBuilder func buildCell(user: User, isFavorite: Bool, onTap: @escaping () -> Void) -> some View {
        let viewModel: some UserCellViewModelProtocol = UserCellViewModel(user: user, isFavorite: isFavorite, onTap: onTap)
        UserCellView(viewModel: viewModel)
    }
}

// MARK: - List Dependency & Component
// UserListComponent also conforms to UserCellDependency so it can create a UserCellComponent

@MainActor
protocol UserListDependency {
    var favoritesService: FavoritesService { get }
}

@MainActor
class UserListComponent: UserListDependency, UserCellDependency {
    let favoritesService: FavoritesService

    init(dependency: UserListDependency) {
        self.favoritesService = dependency.favoritesService
    }
}

// MARK: - List Builder

protocol UserListBuildable {
    associatedtype Screen: View
    associatedtype DetailScreen: View
    associatedtype CellContent: View
    @ViewBuilder @MainActor func build() -> Screen
    @ViewBuilder @MainActor func buildDetail(user: User) -> DetailScreen
    @ViewBuilder @MainActor func buildCell(user: User, isFavorite: Bool, onTap: @escaping () -> Void) -> CellContent
}

@MainActor
class UserListBuilder: UserListBuildable {
    private let component: UserListComponent
    private lazy var cellBuilder = UserCellBuilder(component: UserCellComponent(dependency: component))

    init(component: UserListComponent) {
        self.component = component
    }

    @ViewBuilder func build() -> some View {
        let viewModel: some UserViewModelProtocol = UserViewModel()
        UserListView(viewModel: viewModel, builder: self, favoritesService: component.favoritesService)
    }

    @ViewBuilder func buildDetail(user: User) -> some View {
        let viewModel: some UserDetailViewModelProtocol = UserDetailViewModel(
            user: user,
            favoritesService: component.favoritesService
        )
        UserDetailView(viewModel: viewModel)
    }

    @ViewBuilder func buildCell(user: User, isFavorite: Bool, onTap: @escaping () -> Void) -> some View {
        cellBuilder.buildCell(user: user, isFavorite: isFavorite, onTap: onTap)
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

struct UserListView<ViewModel: UserViewModelProtocol, Builder: UserListBuildable>: View {
    @ObservedObject private var viewModel: ViewModel
    @State private var selectedUser: User?
    private let builder: Builder
    private let favoritesService: FavoritesService

    init(viewModel: ViewModel, builder: Builder, favoritesService: FavoritesService) {
        self.viewModel = viewModel
        self.builder = builder
        self.favoritesService = favoritesService
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
                    builder.buildCell(
                        user: user,
                        isFavorite: favoritesService.isFavorite(userID: user.id),
                        onTap: { selectedUser = user }
                    )
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
            builder.buildDetail(user: user)
        }
    }
}

// MARK: - Preview

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

@MainActor
class PreviewDependency: UserListDependency {
    let favoritesService: FavoritesService = FavoritesService()
}

#Preview("List") {
    let dependency = PreviewDependency()
    let component = UserListComponent(dependency: dependency)
    let builder = UserListBuilder(component: component)
    UserListView(viewModel: MockUserViewModel(), builder: builder, favoritesService: dependency.favoritesService)
}

#Preview("Detail") {
    UserDetailView(viewModel: MockUserDetailViewModel())
}

#Preview("Cell") {
    UserCellView(
        viewModel: UserCellViewModel(
            user: User(id: UUID(), name: "Alice", email: "alice@example.com"),
            isFavorite: true,
            onTap: {}
        )
    )
}
