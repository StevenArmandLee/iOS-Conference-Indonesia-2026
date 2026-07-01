// swift-tools-version: 5.9
import PackageDescription

// Each presentation stage lives in its OWN target (= its own module), so the
// repeated `User` / `ViewState` / `UserViewModel` / `UserListView` declarations
// across stages never collide. Open this package in Xcode, click any stage's
// file, and use the Canvas (#Preview) for the live demo.
let package = Package(
    name: "iOS Conference Indonesia",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "Stage1_MVVM"),
        .target(name: "Stage2_MVVMProtocol"),
        .target(name: "Stage3_MVVMProtocol2"),
        .target(name: "Stage4_NewView"),
        .target(name: "Stage5_Builder"),
        .target(name: "Stage6_Dependency"),
        .target(name: "Stage7_Router"),
    ]
)
