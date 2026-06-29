# iOS Conference Indonesia — MVVM, step by step

Seven progressive stages of the same SwiftUI MVVM example, used as live-coding
slides. Each stage redeclares the same type names (`User`, `ViewState`,
`UserViewModel`, `UserListView`, …), so they **cannot** share one build target.

To keep every stage runnable *and* avoid duplicate-symbol errors, each stage is
its own Swift Package **target** (= its own module). Identical names in different
stages are different types and never collide.

## Presenting

1. Open `Package.swift` in Xcode (File ▸ Open, or `open Package.swift`).
2. In the navigator, expand **Sources** → pick the stage you're on.
3. Open the **Canvas** (⌥⌘↩) for the live `#Preview`.
4. Pick an iOS Simulator as the run destination so Previews can build.

| Stage | Target | Theme |
|------|--------|-------|
| 1 | Stage1_MVVM | Plain MVVM |
| 2 | Stage2_MVVMProtocol | Protocol-backed view model |
| 3 | Stage3_MVVMProtocol2 | Generic view over the protocol |
| 4 | Stage4_NewView | Adding a detail view |
| 5 | Stage5_Builder | Builders |
| 6 | Stage6_Dependency | Dependency injection |
| 7 | Stage7_Router | Routing |

Source of truth for each stage is the single `.swift` file inside its target
folder under `Sources/`.
