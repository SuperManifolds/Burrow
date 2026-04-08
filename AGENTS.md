# Claude Code Preferences

## Git Commits

- Write clear, professional commit messages that focus on what changed and why
- Use conventional commit style

## Code Changes

- Always build with Xcode after making code changes and verify zero warnings/errors
- Address SwiftLint warnings — do not silence them with `swiftlint:disable` without expressed consent
- When asked to commit, create a clear commit message without asking for confirmation
- Focus on the technical implementation rather than over-explaining what was done
- When implementing a new utility function make sure it is not already implemented elsewhere in the codebase
- Do not create a new version of an existing function if it makes the old function redundant, just modify the existing function
- Do not use `_` prefixes or `#[allow(dead_code)]` equivalents to silence unused code warnings — just remove code that is no longer used

## Swift Code Quality

- Avoid excessive nesting in functions (prefer early returns, extract helper functions)
- Keep functions small and focused on a single responsibility
- Follow Swift naming conventions and idiomatic patterns
- Use constants for magic numbers and layout/style values like colors, spacing, sizes, etc.
- Prefer declarative over imperative code when sensible (use map, filter, compactMap, etc.)
- Avoid unnecessary suffixes to files or structs like 'View', 'Component', 'Manager' unless they add genuine clarity
- When making a change to existing code that will negatively affect time complexity you must request permission
- Use protocols for testability and SwiftUI previews (e.g. `TunnelManaging` over `TunnelManager`)
- Use `@MainActor` for view models and UI-bound state
- Prefer `private(set)` for published properties that should only be modified internally

## SwiftUI Views

- Avoid code inside views that is not directly related to UI — model/business logic goes in ViewModels or Services
- Avoid large amounts of code inside event handlers — extract into functions
- Extract reusable row/cell views into separate component files under `Views/Components/`
- All views should have `#Preview` blocks with realistic data (use bundled JSON or preview helpers, not empty stubs)
- Wrap previews in `#if DEBUG` / `#endif`
- Use `.environmentObject` and `@ObservedObject` patterns consistent with the existing codebase
- Use shared color extensions (e.g. `Color.ping(_:)`, `Color.connectionStatus(_:)`) instead of duplicating color logic

## Design Philosophy

- **Minimal, calm, purposeful.** No clutter. The primary action (connect) should be achievable in one click.
- **Translucent materials.** Use `.ultraThinMaterial` / `.regularMaterial` for the menu bar popover and sidebars, like Apple's own apps.
- **Smooth animations.** Connection state transitions should use spring animations. The connect button should have a satisfying haptic-like visual feedback.
- **SF Symbols throughout.** Use system icons: `globe`, `antenna.radiowaves.left.and.right`, `lock.shield.fill`, `checkmark.circle.fill`, `mappin.circle`.
- **Native macOS patterns.** Use `NavigationSplitView` for the main window, `.searchable()` for filtering servers, `Settings` scene for preferences.

## Localization

- All user-facing strings must use `String(localized:)` — never hardcoded English in views

## Preview Data

- Use the bundled `preview_relays.json` for realistic preview data
- View models should expose `static func preview()` factories under `#if DEBUG`
- Mock protocols (e.g. `MockTunnelManager`) live alongside their protocol definitions

## Architecture

- MVVM: Views → ViewModels → Services
- The app and Network Extension (BurrowTunnel) share code via the Shared/ target
- Protocol-orient the boundary between app and system frameworks for testability
