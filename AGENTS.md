# AGENTS.md — Project Policy & Workflow

> **Project**: applspeech — Swift CLI for on-device speech transcription
> **Stack**: Swift 6.2.3, Speech framework (SpeechTranscriber/SpeechAnalyzer APIs)
> **VCS**: Jujutsu (jj)
> **Workflow**: TCR (test || commit || revert)
> **Focus**: Optimized for AI agent usage (programmable, JSON output, stdin/pipe)

---

## §1 — Project Identity

**applspeech** is a command-line tool for transcribing and analyzing audio using Apple's on-device Speech framework. Designed primarily for **AI agent usage** — simple, scriptable, JSON-first output.

**Target users**: AI agents (like me), automation scripts, CLI workflows
**Target platform**: macOS 26.0+ (Sonoma or later, required for SpeechTranscriber API)
**Binary name**: `applspeech`

### Design Principles for AI Agents
- **JSON-first**: Default output is JSON for easy parsing
- **Stdin/pipe friendly**: Works in Unix pipelines  
- **Single purpose**: One thing (transcription), done well
- **No GUI**: Pure CLI, no UI elements

---

## §2 — Code Organization

### File Structure
```
applspeech/
├── Package.swift                    # SPM manifest
├── .swift-format                    # Code style config
├── Sources/
│   └── ApplSpeech/
│       ├── ApplSpeech.swift        # Entry point (@main)
│       ├── Commands/                # Subcommands
│       ├── Transcription/          # SpeechTranscriber logic
│       ├── Analysis/               # SpeechAnalyzer logic
│       ├── Output/                 # Formatters
│       └── Utilities/              # Helpers
├── Tests/
│   └── ApplSpeechTests/
└── .github/workflows/              # CI/CD
```

### Module Dependencies (respects Swift's single-pass compilation)
- Utilities (bottom layer)
- Transcription (depends on Utilities)
- Analysis (depends on Utilities)
- Output (depends on Transcription, Analysis)
- Commands (depends on all above)
- ApplSpeech.swift (top layer, depends on Commands)

**Rule**: Lower layers cannot import higher layers.

---

## §3 — TCR Workflow (Test || Commit || Revert)

Every code change follows this loop:

```bash
# 1. Describe your change
jj desc -m "feat(transcribe): add live transcription"

# 2. Make ONE small change

# 3. Verify
swift build && swift test

# 4. Result:
#    ✅ ALL PASS → jj new (commit)
#    ❌ ANY FAIL → jj restore (revert)
```

### TCR Rules
- **Small steps**: Each change should be < 50 lines
- **Always green**: Never commit failing tests
- **No stubs**: Every commit must be fully functional
- **No TODOs**: Finish what you start or don't commit it
- **Test first**: Write test, see it fail, make it pass, commit

### Verification Checklist (run before every commit)
```bash
swift build                          # Type checking
swift test                           # Unit tests pass
swift format lint --recursive .      # No style violations (if format installed)
```

For final story verification, also run:
```bash
swift build -c release               # Production build
swift test --verbose                  # All tests with output
```

---

## §4 — Commit Conventions

Use Conventional Commits with these types:

- `feat(scope)`: New feature
- `fix(scope)`: Bug fix
- `test(scope)`: Test-only changes
- `refactor(scope)`: Code restructure, no behavior change
- `docs(scope)`: Documentation only
- `chore(scope)`: Tooling, dependencies, non-code

**Scopes**: `transcribe`, `analyze`, `commands`, `output`, `utils`, `cli`, `tests`, `ci`

**Examples**:
```
feat(transcribe): implement live transcription
test(transcribe): add transcription accuracy tests
fix(commands): handle missing audio file gracefully
refactor(output): extract transcript formatter
docs(readme): add installation instructions
chore(ralph): complete story S03-transcription-engine
```

---

## §5 — Testing Standards

### Framework: Swift Testing
- Use `@Test` macros, NOT XCTest
- Organize tests with `@Suite`
- Use `#expect` for assertions
- Use parameterized tests with `arguments:`

### Coverage Requirements
- All public APIs must have tests
- Error paths must be tested
- Edge cases must be covered
- Target: >80% coverage

### Test Organization
```swift
import Testing
@testable import ApplSpeech

@Suite("Transcription Tests")
struct TranscriptionTests {
  
  @Test("Transcribe audio file")
  func transcribeAudioFile() async throws {
    // Test implementation
  }
  
  @Test("Handle unsupported format")
  func unsupportedFormatError() throws {
    #expect(throws: TranscriptionError.unsupportedFormat) {
      // Test code
    }
  }
}
```

### Test File Naming
- Implementation: `Sources/ApplSpeech/Transcription/Transcriber.swift`
- Tests: `Tests/ApplSpeechTests/TranscriptionTests.swift`
- Suffix tests with `Tests`

---

## §6 — Code Style & Quality

### Swift 6 Standards
- Enable strict concurrency checking
- All types crossing isolation boundaries are `Sendable`
- Use value types (struct/enum) over reference types (class)
- Protocol-oriented design where appropriate
- No force unwrapping (`!`) in production code

### Formatting (swift-format)
If swift-format is available, code must pass:
```bash
swift format lint --recursive Sources/ Tests/
```

If not available, follow these conventions:
- 100 character line length
- 2-space indentation
- No trailing whitespace
- One blank line between declarations
- PascalCase for types, camelCase for functions/variables

### Documentation
- Triple-slash (`///`) comments for public APIs
- Include parameter descriptions
- Provide usage examples for complex functions

```swift
/// Transcribes audio from a file using on-device speech recognition.
///
/// - Parameters:
///   - url: URL to the audio file
///   - language: BCP-47 language code (default: en-US)
/// - Returns: Transcribed text
/// - Throws: `TranscriptionError` if transcription fails
func transcribe(url: URL, language: String = "en-US") async throws -> String
```

---

## §7 — Security & Privacy Guidelines

### Critical Rules
- **NEVER** log audio content or transcription results
- **Use on-device transcription** only — no cloud APIs
- **Respect microphone permissions** — always check and request
- ** audio files securely** — processHandle in memory, don't persist
- **Clear temporary files** after processing

### Safe Patterns
```swift
// ✅ GOOD: On-device transcription
let request = SFSpeechURLRecognitionRequest(url: audioFile)
request.requiresOnDeviceRecognition = true

// ❌ BAD: Cloud-based transcription (privacy risk)
// request.requiresOnDeviceRecognition = false
```

---

## §8 — Jujutsu (jj) Workflow

### Basic Operations
```bash
# Start new work
jj new -m "feat(scope): description"

# Check status
jj st

# Commit (automatic with jj new)
jj new -m "next change"

# Revert uncommitted changes
jj restore

# View history
jj log --limit 10

# Amend current description
jj desc -m "better description"
```

### Working Copy Model
- `jj new` creates a new commit and moves to it (auto-commits previous work)
- `jj restore` reverts working directory to last commit
- No explicit `git add` or `git commit` needed

### TCR Integration
```bash
# Make change
jj desc -m "feat(transcribe): add file transcription"

# Edit code...

# Test
swift build && swift test

# If pass:
jj new

# If fail:
jj restore
```

---

## §9 — Story Completion Protocol

Before marking a story complete in `prd.json`, verify:

### Build Verification
```bash
swift build                    # ✅ Zero errors
swift build -c release         # ✅ Release build succeeds
swift test                     # ✅ All tests pass
swift test --verbose           # ✅ No warnings in test output
```

### Optional (if swift-format installed)
```bash
swift format lint --recursive Sources/ Tests/  # ✅ No violations
```

### Manual Verification
- [ ] All acceptance criteria met
- [ ] Tests added for new functionality
- [ ] Error paths tested
- [ ] Documentation updated
- [ ] No force unwrapping in production code
- [ ] No TODO comments
- [ ] Security/privacy guidelines followed

### Update Tracking Files
1. Set `"passes": true` in `prd.json`
2. Append completion entry to `progress.txt`
3. Commit tracking files:
```bash
jj desc -m "chore(ralph): complete story S##-story-id"
jj new
```

---

## §10 — Dependencies

### Required
- Swift 6.2.3+ (check with `swift --version`)
- macOS 26.0+ (Sonoma or later, required for SpeechTranscriber API)
- Xcode 16.0+ (for development)

### System Frameworks
- Speech.framework (SpeechTranscriber, SpeechAnalyzer)
- AVFoundation (audio file handling)
- Foundation

### Swift Packages
- swift-format 600.0.0+ (optional, for formatting)

---

## §11 — CI/CD Integration

### GitHub Actions
On push to `main`:
- Run `swift build`
- Run `swift test --verbose`
- Run `swift format lint` (if available)
- Build release binary
- Upload artifact

### Local Pre-push Check
```bash
swift build -c release && swift test --verbose
```

If this passes, push is safe.

---

## §12 — Discovered Patterns

> This section is appended by agents during development. If you discover a
> pattern, convention, or gotcha that future iterations need to know, add it
> here and commit as `docs(agents): add <pattern description>`
>
> **IMPORTANT**: After completing ANY iteration, explicitly check if you discovered
> anything worth documenting. If yes, update this section AND commit it separately.

### Pattern: Speech Framework Initialization
Always request authorization before using Speech framework:
```swift
let status = await SFSpeechRecognizer.requestAuthorization()
switch status {
case .authorized: // proceed
case .denied, .restricted, .notDetermined: // handle error
}
```

### Pattern: On-Device Recognition
For privacy, always prefer on-device recognition:
```swift
let request = SFSpeechURLRecognitionRequest(url: audioFile)
request.requiresOnDeviceRecognition = true
```

### Pattern: SwiftPM Sandbox Workaround
In sandboxed environments (Codex, CI), SwiftPM sandbox causes errors:
```
sandbox-exec: sandbox_apply: Operation not permitted
```
Always use `--disable-sandbox` flag:
```bash
swift build --disable-sandbox
swift test --disable-sandbox
```

---

## §13 — Anti-Patterns (Don't Do This)

### ❌ Force Unwrapping
```swift
// BAD
let result = transcription.result!

// GOOD
guard let result = transcription.result else {
  throw TranscriptionError.noResult
}
```

### ❌ Large Commits
```swift
// BAD: Implementing entire transcription in one commit

// GOOD: 
// 1. Add SFSpeechRecognizer wrapper + test
// 2. Add TranscriptionRequest + test
// 3. Add live transcription + test
// 4. Add file transcription + test
```

### ❌ Skipping Tests
```swift
// BAD: "I'll add tests later"

// GOOD: Test-first development
// 1. Write failing test
// 2. Implement feature
// 3. See test pass
// 4. Commit
```

### ❌ Logging Audio Content
```swift
// BAD
print("Transcribed: \(transcription)")

// GOOD
print("Transcription complete: \(wordCount) words")
```

---

## §14 — Quick Reference

### Daily Workflow
```bash
# Read progress.txt for context
cat progress.txt | tail -20

# Check assigned story
jq '.stories[] | select(.passes == false) | .id' prd.json | head -1

# Read story details
jq '.stories[] | select(.id == "S01")' prd.json

# Create commit description
jj desc -m "feat(scope): what you're doing"

# Make small change, test, commit or revert
swift build && swift test && jj new || jj restore

# Mark story complete
# Edit prd.json, append to progress.txt, commit

# === COMPOUNDING STEP ===
# Check for discovered patterns:
# Did you encounter any gotchas? Update AGENTS.md §12 and commit
```

### Verification Commands
```bash
swift build                           # Type check
swift test                            # Unit tests
swift test --verbose                  # Verbose test output
swift build -c release               # Production build
swift format lint --recursive .       # Style check (if available)
```

### Jujutsu Commands
```bash
jj new -m "message"                   # Create new commit
jj desc -m "message"                 # Update commit message
jj st                                 # Status
jj log --limit 10                     # Recent history
jj restore                            # Revert working directory
```

---

## §15 — Voice Input Sources

This project uses **SpeechTranscriber** API for transcription:

- **File**: Local audio files (flac, wav, m4a, mp3)
- **Live**: Real-time transcription via microphone using `.progressiveLiveTranscription`
- **URL**: Remote audio files via HTTP/HTTPS

### Transcription Modes
- **Offline**: Uses `SpeechTranscriber.offlineTranscription` - processes entire file
- **Live**: Uses `SpeechTranscriber.progressiveLiveTranscription` - real-time results

### Telegram Integration
Audio from Telegram messages can be processed:
1. Download audio from Telegram message
2. Pass to applspeech for transcription
3. Output results in various formats

---

**Last Updated**: 2026-02-14
**Version**: 1.0
