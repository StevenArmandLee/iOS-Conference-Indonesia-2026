// xcode: set sdk=iOS

//
//  MVVM present view.swift
//  MVVM
//
//  Created by steven lee on 21/6/26.
//

import Foundation
import SwiftUI

struct User: Identifiable, Hashable {
    let id: UUID
    let name: String
    let email: String
}

enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}

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

// MARK: - Navigation

enum UserRoute: Hashable {
    case detail(User)
}

protocol UserRouterProtocol: AnyObject {
    func navigate(to user: User)
    func route(for user: User) -> UserRoute
}

class UserRouter: UserRouterProtocol {
    var push: ((UserRoute) -> Void)?

    func navigate(to user: User) {
        push?(.detail(user))
    }

    func route(for user: User) -> UserRoute {
        .detail(user)
    }
}

@MainActor
protocol UserViewModelProtocol: ObservableObject {
    var state: ViewState<[User]> { get set }
    var path: NavigationPath { get set }
    func loadUsers() async
    func navigate(to user: User)
}

@MainActor
class UserViewModel: UserViewModelProtocol {
    @Published var state: ViewState<[User]> = .idle
    @Published var path: NavigationPath = NavigationPath()
    private let router: UserRouter

    init(router: UserRouter) {
        self.router = router
        router.push = { [weak self] route in
            self?.path.append(route)
        }
    }

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

    func navigate(to user: User) {
        router.navigate(to: user)
    }
}

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
    private let router: UserRouterProtocol

    init(user: User, isFavorite: Bool, router: UserRouterProtocol) {
        self.user = user
        self.isFavorite = isFavorite
        self.router = router
    }

    func onTap() {
        router.navigate(to: user)
    }
}

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
// UserCellDependency includes the router — the cell handles its own tap navigation

@MainActor
protocol UserCellDependency {
    var favoritesService: FavoritesService { get }
    var router: UserRouter { get }
}

@MainActor
class UserCellComponent: UserCellDependency {
    let favoritesService: FavoritesService
    let router: UserRouter

    init(dependency: UserCellDependency) {
        self.favoritesService = dependency.favoritesService
        self.router = dependency.router
    }
}

// MARK: - Cell Builder
// No onTap — the router is injected, so the cell handles navigation itself

protocol UserCellBuildable {
    associatedtype CellContent: View
    @ViewBuilder @MainActor func buildCell(user: User, isFavorite: Bool) -> CellContent
}

@MainActor
class UserCellBuilder: UserCellBuildable {
    private let component: UserCellComponent

    init(component: UserCellComponent) {
        self.component = component
    }

    @ViewBuilder func buildCell(user: User, isFavorite: Bool) -> some View {
        let viewModel: some UserCellViewModelProtocol = UserCellViewModel(
            user: user,
            isFavorite: isFavorite,
            router: component.router
        )
        UserCellView(viewModel: viewModel)
    }
}

// MARK: - Detail Dependency & Component

@MainActor
protocol UserDetailDependency {
    var favoritesService: FavoritesService { get }
}

@MainActor
class UserDetailComponent: UserDetailDependency {
    let favoritesService: FavoritesService

    init(dependency: UserDetailDependency) {
        self.favoritesService = dependency.favoritesService
    }
}

// MARK: - Detail Builder

protocol UserDetailBuildable {
    associatedtype DetailContent: View
    @ViewBuilder @MainActor func build(user: User) -> DetailContent
}

// What UserDetailView can build internally — extend this as the screen grows
protocol UserDetailContentBuildable {}

@MainActor
class UserDetailBuilder: UserDetailBuildable, UserDetailContentBuildable {
    private let component: UserDetailComponent

    init(component: UserDetailComponent) {
        self.component = component
    }

    @ViewBuilder func build(user: User) -> some View {
        let viewModel: some UserDetailViewModelProtocol = UserDetailViewModel(
            user: user,
            favoritesService: component.favoritesService
        )
        UserDetailView(viewModel: viewModel, builder: self)
    }
}

// MARK: - List Dependency & Component
// UserListComponent conforms to UserCellDependency and UserDetailDependency so it can seed their components

@MainActor
protocol UserListDependency {
    var favoritesService: FavoritesService { get }
    var router: UserRouter { get }
}

@MainActor
class UserListComponent: UserListDependency, UserCellDependency, UserDetailDependency {
    let favoritesService: FavoritesService
    let router: UserRouter

    init(dependency: UserListDependency) {
        self.favoritesService = dependency.favoritesService
        self.router = dependency.router
    }
}

// MARK: - List Builder

protocol UserListBuildable {
    associatedtype DetailScreen: View
    associatedtype CellContent: View
    @ViewBuilder @MainActor func buildDetail(user: User) -> DetailScreen
    @ViewBuilder @MainActor func buildCell(user: User, isFavorite: Bool) -> CellContent
}

@MainActor
class UserListBuilder: UserListBuildable {
    private let component: UserListComponent
    private lazy var cellBuilder = UserCellBuilder(component: UserCellComponent(dependency: component))
    private lazy var detailBuilder = UserDetailBuilder(component: UserDetailComponent(dependency: component))

    init(component: UserListComponent) {
        self.component = component
    }

    @ViewBuilder func build() -> some View {
        let viewModel: some UserViewModelProtocol = UserViewModel(router: component.router)
        UserListView(viewModel: viewModel, builder: self, favoritesService: component.favoritesService)
    }

    @ViewBuilder func buildDetail(user: User) -> some View {
        detailBuilder.build(user: user)
    }

    @ViewBuilder func buildCell(user: User, isFavorite: Bool) -> some View {
        cellBuilder.buildCell(user: user, isFavorite: isFavorite)
    }
}

// MARK: - Detail View

struct UserDetailView<ViewModel: UserDetailViewModelProtocol, Builder: UserDetailContentBuildable>: View {
    @ObservedObject private var viewModel: ViewModel
    private let builder: Builder

    init(viewModel: ViewModel, builder: Builder) {
        self.viewModel = viewModel
        self.builder = builder
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
        .navigationTitle(viewModel.user.name)
    }
}

// MARK: - List View

struct UserListView<ViewModel: UserViewModelProtocol, Builder: UserListBuildable>: View {
    @ObservedObject private var viewModel: ViewModel
    private let builder: Builder
    private let favoritesService: FavoritesService

    init(viewModel: ViewModel, builder: Builder, favoritesService: FavoritesService) {
        self.viewModel = viewModel
        self.builder = builder
        self.favoritesService = favoritesService
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
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
                            isFavorite: favoritesService.isFavorite(userID: user.id)
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
            .navigationDestination(for: UserRoute.self) { route in
                switch route {
                case .detail(let user):
                    builder.buildDetail(user: user)
                }
            }
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
    @Published var path: NavigationPath = NavigationPath()

    func loadUsers() async {}
    func navigate(to user: User) { path.append(UserRoute.detail(user)) }
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
    let router: UserRouter = UserRouter()
}

#Preview("List") {
    let dependency = PreviewDependency()
    let component = UserListComponent(dependency: dependency)
    let builder = UserListBuilder(component: component)
    UserListView(
        viewModel: MockUserViewModel(),
        builder: builder,
        favoritesService: dependency.favoritesService
    )
}

#Preview("Detail") {
    struct MockDetailBuilder: UserDetailContentBuildable {}
    return NavigationStack {
        UserDetailView(viewModel: MockUserDetailViewModel(), builder: MockDetailBuilder())
    }
}

#Preview("Cell") {
    UserCellView(
        viewModel: UserCellViewModel(
            user: User(id: UUID(), name: "Alice", email: "alice@example.com"),
            isFavorite: true,
            router: UserRouter()
        )
    )
}
