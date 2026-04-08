# Contributing to Burrow

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing.

## Getting Started

### Prerequisites

- **Xcode 26** or later
- **macOS 26.4** or later
- An Apple Developer account (for code signing and Network Extension entitlements)

### Development Setup

1. **Clone the repository**

```bash
git clone https://github.com/SuperManifolds/Burrow.git
cd Burrow
```

2. **Open in Xcode**

```bash
open Burrow.xcodeproj
```

Xcode will automatically resolve Swift Package Manager dependencies (WireGuardKit).

3. **Configure signing**

Select your development team in the project settings for both the `Burrow` and `BurrowTunnel` targets.

4. **Build and run**

Press `Cmd+R` or build from the Product menu. The app requires the Network Extension entitlement to function — you may need to enable it in your provisioning profile.

## Development Workflow

### Running Tests

```bash
# Run unit tests
xcodebuild -project Burrow.xcodeproj -scheme Burrow -only-testing:BurrowTests test

# Run UI tests
xcodebuild -project Burrow.xcodeproj -scheme Burrow -only-testing:BurrowUITests test

# Or run from Xcode with Cmd+U
```

### Code Quality

Before submitting changes, ensure your code passes quality checks:

```bash
# Build the project (also runs SwiftLint)
xcodebuild -project Burrow.xcodeproj -scheme Burrow -configuration Debug build

# Or build from Xcode and check the Issue Navigator for warnings
```

- Zero warnings policy — all SwiftLint warnings must be resolved
- Do not silence warnings with `swiftlint:disable` without maintainer approval

### Code Style

This project follows the conventions outlined in `AGENTS.md`:

- Build with Xcode after every change and verify zero warnings/errors
- Avoid excessive nesting (prefer early returns, extract helper functions)
- Keep functions small and focused on a single responsibility
- Follow Swift naming conventions and idiomatic patterns
- Use constants for magic numbers, colors, spacing, and layout values
- Prefer declarative patterns (map, filter, compactMap) over imperative loops
- Keep views focused on UI — business logic goes in ViewModels or Services
- All views should have `#Preview` blocks with realistic data
- Use `String(localized:)` for all user-facing strings

## LLM and AI Assistance

Using LLMs and AI coding assistants is allowed, but requires deliberate and responsible use. See [Oxide's RFD 576](https://rfd.shared.oxide.computer/rfd/0576) for the philosophy behind these guidelines.

**Core principles:**

- **You are accountable** — You are responsible for all code you submit, regardless of how it was written
- **Understand your code** — Don't submit code you can't explain; be prepared to discuss every line in review
- **Verify everything** — Always review, test, and understand LLM-generated code before committing
- **Respect reviewer time** — Don't dump unreviewed LLM output into PRs

**Good uses:**

- Debugging assistance and "rubber duck" conversations
- Understanding unfamiliar code patterns or APIs
- Generating boilerplate or test cases (with careful review)
- Research and documentation help

**Discouraged practices:**

- Submitting wholesale LLM-generated code without understanding it
- Using LLMs to bypass learning the codebase
- Relying on LLMs for architectural decisions without human validation

## Making Changes

### Branch Naming

Create a branch using the format: `githubusername/<issue-id>-description`

```bash
git checkout -b yourname/123-add-server-filtering
# or for bug fixes
git checkout -b yourname/456-fix-tunnel-reconnect
```

### Commit Messages

Write clear, professional commit messages following the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat:` — New feature
- `fix:` — Bug fix
- `refactor:` — Code refactoring
- `docs:` — Documentation changes
- `test:` — Adding or updating tests
- `chore:` — Maintenance tasks

Example:
```
feat: add persistent favourites section to server list

- Store favourite city IDs in UserDefaults
- Show favourites section at top of sidebar with country flags
- Add star toggle to city rows
```

### Pull Requests

1. **Ensure the project builds with zero warnings**
   - Build in Xcode or via `xcodebuild`
   - Run tests with `Cmd+U`

2. **Push your changes**

```bash
git push origin yourname/123-your-branch-name
```

3. **Open a Pull Request**
   - Go to the repository on GitHub
   - Click "New Pull Request"
   - Select your branch
   - Fill out the PR with a clear description

4. **Respond to feedback**
   - Address any review comments
   - Push additional commits to your branch as needed

## Project Structure

```
Burrow/
├── App/                    # App entry point (BurrowApp.swift)
├── Extensions/             # Swift extensions (Color+Burrow, String+CountryFlag)
├── Models/                 # Data models (Relay, ConnectionStatus, etc.)
├── Protocols/              # Protocols and mocks (TunnelManaging, APIClientProtocol)
├── Services/               # Business logic (TunnelManager, MullvadAPIClient, PingService)
├── ViewModels/             # MVVM view models
├── Views/
│   ├── Components/         # Reusable view components (CityRowView, CountryRowView, etc.)
│   ├── MainWindow/         # Main window views (ServerListView, ConnectionStatusView)
│   ├── MenuBar/            # Menu bar popover
│   ├── Onboarding/         # Login flow
│   └── Settings/           # Settings window
├── Resources/              # Bundled data (preview_relays.json)
BurrowTunnel/               # Network Extension target (PacketTunnelProvider)
Shared/                     # Shared code between app and extension (Constants.swift)
BurrowTests/                # Unit tests
BurrowUITests/              # UI tests
```

## Reporting Issues

When reporting bugs:
- Include steps to reproduce
- Include macOS version and relevant system configuration
- For tunnel/connection issues, include the tunnel log (accessible via the account menu)

For feature requests:
- Describe the use case
- Provide examples of how it would work

## Questions?

If you have questions about contributing, feel free to:
- Open a discussion on GitHub
- Ask in an issue

Thank you for contributing to Burrow!
