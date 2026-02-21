# Repository Guidelines

## Project Structure & Module Organization
- `BirdSaver/` contains the macOS SwiftUI app target.
- `BirdSaver/Features/` holds feature-specific UI (for example, auth login web view).
- `BirdSaver/Services/` contains side-effect and API logic (`AuthService`, timeline fetch, media download).
- `BirdSaver/ViewModels/` contains presentation state and orchestration (`BirdSaverViewModel`).
- `BirdSaver/Models/` defines shared data models and DTOs.
- `BirdSaver/Support/` contains persistence/helpers (settings and keychain storage).
- `BirdSaver/Assets.xcassets/` stores icons and color assets.
- `BirdSaver.xcodeproj/` holds project settings and Swift Package dependencies.

## Build, Test, and Development Commands
- `open BirdSaver.xcodeproj`
  - Open in Xcode for local development and debugging.
- `xcodebuild -project BirdSaver.xcodeproj -scheme BirdSaver -configuration Debug build`
  - CLI debug build used for CI-like verification.
- `xcodebuild -project BirdSaver.xcodeproj -scheme BirdSaver -configuration Release build`
  - Validate release configuration.
- `xcodebuild -project BirdSaver.xcodeproj -scheme BirdSaver -showBuildSettings`
  - Inspect active build flags and environment.

## Coding Style & Naming Conventions
- Language: Swift + SwiftUI, 4-space indentation, one type per file.
- Types use `UpperCamelCase`; properties/methods use `lowerCamelCase`.
- Name files after the primary type (for example, `TimelineService.swift`).
- Keep UI logic in `Features/` or `ContentView`, business flow in `ViewModels/`, and network/storage in `Services/`/`Support/`.
- Prefer `@MainActor` for UI-facing state and avoid blocking calls on the main thread.

## Testing Guidelines
- There is currently no dedicated XCTest target in this repository.
- For now, validate changes with debug and release `xcodebuild` commands above.
- When adding tests, create a `BirdSaverTests` target and name files `*Tests.swift` with focused method names like `testLoginStateRestoresFromKeychain()`.

## Commit & Pull Request Guidelines
- Follow Conventional Commits seen in history, e.g. `feat(app): bootstrap BirdSaver macOS app`.
- Preferred types: `feat`, `fix`, `refactor`, `chore`, `perf`.
- Keep PRs small and include:
  - What changed and why.
  - Manual validation steps/commands run.
  - UI screenshots for SwiftUI-visible changes.
  - Linked issue (if applicable).

## Security & Configuration Tips
- Do not commit tokens, cookies, or account data.
- Keep secrets in Keychain-backed flows (`Support/KeychainStore.swift`), not in source or plist files.
