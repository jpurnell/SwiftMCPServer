#!/usr/bin/env swift

// setup.swift — Generate .claude/ bridge layer for a project using development guidelines
//
// Usage:
//   From your project root, after cloning development-guidelines:
//     swift development-guidelines/setup.swift
//
//   Or with a custom guidelines path:
//     swift setup.swift --guidelines-path .guidelines

import Foundation

// MARK: - Configuration

struct Config {
    let projectRoot: URL
    let guidelinesPath: String  // relative to project root
    let projectName: String
}

// MARK: - Helpers

func fileManager() -> FileManager { .default }

func writeFile(at path: String, content: String, relativeTo root: URL) {
    let url = root.appendingPathComponent(path)
    let dir = url.deletingLastPathComponent()
    try! fileManager().createDirectory(at: dir, withIntermediateDirectories: true)
    try! content.write(to: url, atomically: true, encoding: .utf8)
    print("  ✓ \(path)")
}

func fileExists(at path: String, relativeTo root: URL) -> Bool {
    fileManager().fileExists(atPath: root.appendingPathComponent(path).path)
}

func readExisting(at path: String, relativeTo root: URL) -> String? {
    try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

// MARK: - Parse Arguments

func parseArgs() -> Config {
    let args = CommandLine.arguments
    let cwd = URL(fileURLWithPath: fileManager().currentDirectoryPath)

    // Determine guidelines path relative to project root
    var guidelinesRelPath: String?
    var projectRoot = cwd

    for i in 1..<args.count {
        if args[i] == "--guidelines-path", i + 1 < args.count {
            guidelinesRelPath = args[i + 1]
        }
        if args[i] == "--project-root", i + 1 < args.count {
            projectRoot = URL(fileURLWithPath: args[i + 1])
        }
    }

    // Auto-detect: if this script lives inside the guidelines dir, infer the relative path
    if guidelinesRelPath == nil {
        let scriptPath = URL(fileURLWithPath: args[0]).resolvingSymlinksInPath().path
        let cwdPath = projectRoot.path

        // Find common prefix — the script's parent directory relative to cwd is the guidelines path
        if scriptPath.hasPrefix(cwdPath) {
            let relative = String(scriptPath.dropFirst(cwdPath.count + 1)) // drop leading /
            if let lastSlash = relative.lastIndex(of: "/") {
                // e.g., "development-guidelines/setup.swift" → "development-guidelines"
                guidelinesRelPath = String(relative[..<lastSlash])
            } else {
                // Script is at the repo root (e.g., "setup.swift") — we ARE the guidelines
                guidelinesRelPath = "."
            }
        }
    }

    let guidelinesPath = guidelinesRelPath ?? "development-guidelines"

    // Verify guidelines exist
    guard fileExists(at: "\(guidelinesPath)/README.md", relativeTo: projectRoot) else {
        print("Error: Cannot find guidelines at '\(guidelinesPath)/README.md'")
        print("Run this script from your project root, e.g.:")
        print("  swift \(guidelinesPath)/setup.swift")
        print("")
        print("Or specify the path:")
        print("  swift setup.swift --guidelines-path <relative-path-to-guidelines>")
        exit(1)
    }

    // Derive project name from the directory name
    let projectName = projectRoot.lastPathComponent

    return Config(
        projectRoot: projectRoot,
        guidelinesPath: guidelinesPath,
        projectName: projectName
    )
}

// MARK: - Generators

func generateCLAUDEmd(_ config: Config) -> String {
    """
    # \(config.projectName) — Development Guidelines

    This project follows the Design-First TDD workflow defined in `\(config.guidelinesPath)/`.

    ## Session Start

    Read documents in this order for full context recovery:
    1. `\(config.guidelinesPath)/00_CORE_RULES/00_MASTER_PLAN.md` — Vision and priorities
    2. `\(config.guidelinesPath)/00_CORE_RULES/01_CODING_RULES.md` — Forbidden patterns, safety rules
    3. `\(config.guidelinesPath)/00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md` — Testing contract
    4. `\(config.guidelinesPath)/04_IMPLEMENTATION_CHECKLISTS/CURRENT_*.md` — Active tasks (if any)
    5. Latest file in `\(config.guidelinesPath)/05_SUMMARIES/` — Where we left off (if any)

    For quick recovery (same-day, simple bug fixes), read only items 4-5.

    ## Development Workflow

    ```
    0. DESIGN   → Propose architecture (05_DESIGN_PROPOSAL.md)
    1. RED      → Write failing tests first
    2. GREEN    → Minimum code to pass
    3. REFACTOR → Clean up, keep tests green
    4. DOCUMENT → DocC comments and examples
    5. VERIFY   → Run quality-gate (zero warnings/errors)
    ```

    ## Key Rules

    - No force unwraps (`!`), no `try!`, no force casts (`as!`)
    - Guard clauses for all validation; early returns over nested ifs
    - Division safety: always check for zero before dividing
    - Swift 6 strict concurrency compliance
    - All public APIs require DocC documentation

    ## Quality Gate

    Run `quality-gate` before every commit. All checks must pass.

    ## References

    - Full guidelines: `\(config.guidelinesPath)/README.md`
    - Coding rules: `\(config.guidelinesPath)/00_CORE_RULES/01_CODING_RULES.md`
    - TDD contract: `\(config.guidelinesPath)/00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md`
    - Session workflow: `\(config.guidelinesPath)/00_CORE_RULES/07_SESSION_WORKFLOW.md`
    """
}

func generateSwiftRules(_ config: Config) -> String {
    """
    ---
    paths:
      - "Sources/**/*.swift"
      - "Tests/**/*.swift"
    ---
    # Swift Development Rules

    Follow the coding standards in `\(config.guidelinesPath)/00_CORE_RULES/01_CODING_RULES.md`.

    ## Mandatory

    - No force unwraps, no `try!`, no force casts
    - Guard clauses for validation, early returns over nesting
    - Division safety: check for zero before dividing
    - Swift 6 strict concurrency compliance
    - All public APIs need DocC comments (see `\(config.guidelinesPath)/00_CORE_RULES/03_DOCC_GUIDELINES.md`)

    ## Testing (TDD)

    Follow `\(config.guidelinesPath)/00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md`:
    - Write failing tests BEFORE implementation
    - Test golden path, edge cases, invalid inputs
    - Use deterministic test data (no random values)
    - Floating point: use accuracy-based assertions, not exact equality
    """
}

func generateDesignSkill(_ config: Config) -> String {
    """
    ---
    name: design
    description: Start a new feature with a Design Proposal (Phase 0). Use when beginning work on a new feature or capability.
    argument-hint: <feature name>
    ---
    Create a Design Proposal for the following feature: $ARGUMENTS

    Follow the template in `\(config.guidelinesPath)/00_CORE_RULES/05_DESIGN_PROPOSAL.md`.

    Save the proposal to `\(config.guidelinesPath)/02_IMPLEMENTATION_PLANS/PROPOSALS/`.

    Include:
    - Problem statement and motivation
    - Proposed API with Swift signatures
    - Error handling strategy
    - Testing strategy
    - Performance considerations
    """
}

func generateRecoverSkill(_ config: Config) -> String {
    """
    ---
    name: recover
    description: Recover session context after a break. Use at the start of a new session to reload project state, active tasks, and next steps.
    ---
    Perform context recovery following `\(config.guidelinesPath)/00_CORE_RULES/07_SESSION_WORKFLOW.md`.

    Read in order:
    1. `\(config.guidelinesPath)/00_CORE_RULES/00_MASTER_PLAN.md`
    2. `\(config.guidelinesPath)/00_CORE_RULES/01_CODING_RULES.md`
    3. `\(config.guidelinesPath)/00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md`
    4. Any `\(config.guidelinesPath)/04_IMPLEMENTATION_CHECKLISTS/CURRENT_*.md` files
    5. The most recent file in `\(config.guidelinesPath)/05_SUMMARIES/`
    6. Recent git log (`git log --oneline -20`)

    Then report:
    - Current phase and feature being worked on
    - What was completed last session
    - Exact next step to resume work
    - Any blockers or open questions
    """
}

func generateSummarizeSkill(_ config: Config) -> String {
    """
    ---
    name: summarize
    description: Create an end-of-session summary. Use before ending a work session to capture progress and next steps.
    ---
    Create a session summary following the template at `\(config.guidelinesPath)/05_SUMMARIES/SESSION_SUMMARY_TEMPLATE.md`.

    Save it to `\(config.guidelinesPath)/05_SUMMARIES/` with today's date as the filename prefix (YYYY-MM-DD_description.md).

    Include:
    - Work completed this session
    - Current phase and status
    - Quality gate results (run `quality-gate` if not already run)
    - Exact next step for the next session
    - Any blockers or decisions needed

    Also update any active `\(config.guidelinesPath)/04_IMPLEMENTATION_CHECKLISTS/CURRENT_*.md` to reflect current progress.
    """
}

func generateChecklistSkill(_ config: Config) -> String {
    """
    ---
    name: checklist
    description: Create a new feature implementation checklist tracking all TDD phases. Use when starting implementation of an approved feature.
    argument-hint: <feature name>
    ---
    Create a new implementation checklist for: $ARGUMENTS

    Use the template at `\(config.guidelinesPath)/04_IMPLEMENTATION_CHECKLISTS/TEMPLATE.md`.

    Save it to `\(config.guidelinesPath)/04_IMPLEMENTATION_CHECKLISTS/CURRENT_$ARGUMENTS.md` (sanitize the filename).

    The checklist should track all phases:
    - [ ] Phase 0: Design Proposal
    - [ ] Phase 1: Tests (RED)
    - [ ] Phase 2: Implementation (GREEN)
    - [ ] Phase 3: Refactoring
    - [ ] Phase 4: Documentation
    - [ ] Phase 5: Quality Gates
    """
}

func generateSettings() -> String {
    """
    {
      "permissions": {
        "allow": [
          "Bash(swift build:*)",
          "Bash(swift test:*)",
          "Bash(swift package:*)",
          "Bash(quality-gate:*)",
          "Bash(quality-gate)",
          "Bash(git status:*)",
          "Bash(git diff:*)",
          "Bash(git log:*)"
        ],
        "deny": [
          "Bash(rm -rf:*)",
          "Read(.env)",
          "Read(.env.*)"
        ]
      },
      "hooks": {
        "PostToolUse": [
          {
            "matcher": "Edit|Write",
            "hooks": [
              {
                "type": "command",
                "if": "Edit(*.swift)",
                "command": "swift build 2>&1 | tail -5"
              },
              {
                "type": "command",
                "if": "Write(*.swift)",
                "command": "swift build 2>&1 | tail -5"
              }
            ]
          }
        ]
      }
    }
    """
}

// MARK: - Migration helpers

/// Remove legacy .claude/commands/ files that have been migrated to .claude/skills/
func migrateLegacyCommands(config: Config) {
    let legacyCommands = ["design.md", "recover.md", "summarize.md", "checklist.md"]
    let commandsDir = config.projectRoot.appendingPathComponent(".claude/commands")

    var removed = false
    for file in legacyCommands {
        let url = commandsDir.appendingPathComponent(file)
        if fileManager().fileExists(atPath: url.path) {
            try? fileManager().removeItem(at: url)
            print("  ✓ Removed legacy .claude/commands/\(file)")
            removed = true
        }
    }

    // Remove the commands directory if it's now empty
    if let contents = try? fileManager().contentsOfDirectory(atPath: commandsDir.path),
       contents.isEmpty {
        try? fileManager().removeItem(at: commandsDir)
        print("  ✓ Removed empty .claude/commands/")
    }

    if !removed {
        print("  ⏭ No legacy commands to migrate")
    }
}

/// Move project-state directories from the project root into the guidelines folder.
/// Older versions of setup.swift created these at the root; they belong inside guidelinesPath.
func migrateRootDirectories(config: Config) {
    // When guidelinesPath is "." the root and target are the same — nothing to migrate
    if config.guidelinesPath == "." {
        print("  ⏭ Running inside guidelines repo (no migration needed)")
        return
    }

    let dirsToMigrate = [
        "02_IMPLEMENTATION_PLANS",
        "04_IMPLEMENTATION_CHECKLISTS",
        "05_SUMMARIES",
    ]

    let fm = fileManager()
    var migrated = false

    for dir in dirsToMigrate {
        let rootDir = config.projectRoot.appendingPathComponent(dir)
        let targetDir = config.projectRoot
            .appendingPathComponent(config.guidelinesPath)
            .appendingPathComponent(dir)

        guard fm.fileExists(atPath: rootDir.path) else { continue }

        // Enumerate files in the root-level directory and move them into the guidelines copy
        guard let enumerator = fm.enumerator(
            at: rootDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { continue }

        var movedFiles = 0
        while let sourceURL = enumerator.nextObject() as? URL {
            // Skip directories — we only move files; dirs are created by ensureProjectDirectories
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }

            // Compute the relative path within the directory tree
            let relativePath = sourceURL.path.dropFirst(rootDir.path.count + 1) // drop leading /
            let destURL = targetDir.appendingPathComponent(String(relativePath))
            let destDir = destURL.deletingLastPathComponent()

            // Ensure target subdirectory exists
            if !fm.fileExists(atPath: destDir.path) {
                try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            }

            // Only move if destination doesn't already have the file
            if fm.fileExists(atPath: destURL.path) {
                print("  ⏭ \(dir)/\(relativePath) already exists in guidelines (skipping)")
            } else {
                do {
                    try fm.moveItem(at: sourceURL, to: destURL)
                    print("  ✓ Moved \(dir)/\(relativePath) → \(config.guidelinesPath)/\(dir)/")
                    movedFiles += 1
                } catch {
                    print("  ✘ Failed to move \(dir)/\(relativePath): \(error.localizedDescription)")
                }
            }
        }

        // Remove the root-level directory if it's now empty (recursively check)
        if let remaining = fm.enumerator(at: rootDir, includingPropertiesForKeys: nil),
           remaining.allObjects.isEmpty {
            // Directory truly empty
        }
        // Use a simpler approach: try to remove and let it fail if not empty
        removeDirectoryIfEmpty(rootDir)

        if movedFiles > 0 { migrated = true }
    }

    if !migrated {
        print("  ⏭ No root-level project directories to migrate")
    }
}

/// Recursively remove a directory tree if it contains no regular files
func removeDirectoryIfEmpty(_ url: URL) {
    let fm = fileManager()
    guard let contents = try? fm.contentsOfDirectory(
        at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
    ) else { return }

    // Recurse into subdirectories first
    for item in contents {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
            removeDirectoryIfEmpty(item)
        }
    }

    // Now try to remove — this only succeeds if the dir is truly empty (or has only hidden files like .gitkeep)
    // Remove .gitkeep files we created, then remove the directory
    let gitkeep = url.appendingPathComponent(".gitkeep")
    if fm.fileExists(atPath: gitkeep.path) {
        try? fm.removeItem(at: gitkeep)
    }
    try? fm.removeItem(at: url)
    if !fm.fileExists(atPath: url.path) {
        print("  ✓ Removed empty \(url.lastPathComponent)/")
    }
}

// MARK: - Gitignore helpers

func ensureGitignoreEntries(config: Config) {
    let gitignorePath = ".gitignore"
    let url = config.projectRoot.appendingPathComponent(gitignorePath)

    var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

    let entries = [
        "# Claude Code local settings (personal preferences, not shared)",
        ".claude/settings.local.json",
        "CLAUDE.local.md",
    ]

    var added: [String] = []
    for entry in entries {
        if !content.contains(entry) {
            added.append(entry)
        }
    }

    if !added.isEmpty {
        if !content.isEmpty && !content.hasSuffix("\n") {
            content += "\n"
        }
        content += "\n" + added.joined(separator: "\n") + "\n"
        try! content.write(to: url, atomically: true, encoding: .utf8)
        print("  ✓ .gitignore (added local claude entries)")
    }
}

// MARK: - Project scaffolding directories
//
// All project-state directories live INSIDE the cloned guidelines folder
// so they sit within that folder's git boundary and don't pollute the
// outer project's working tree. The slash commands and CLAUDE.md
// reference paths under `<guidelinesPath>/...` for the same reason.

func ensureProjectDirectories(config: Config) {
    let dirs = [
        "02_IMPLEMENTATION_PLANS/PROPOSALS",
        "02_IMPLEMENTATION_PLANS/UPCOMING",
        "02_IMPLEMENTATION_PLANS/COMPLETED",
        "04_IMPLEMENTATION_CHECKLISTS",
        "04_IMPLEMENTATION_CHECKLISTS/04_99_COMPLETED",
        "04_IMPLEMENTATION_CHECKLISTS/04_99_BLOCKED",
        "05_SUMMARIES",
        "05_SUMMARIES/05_00_PHASE_SUMMARIES",
        "05_SUMMARIES/05_01_FIX_SUMMARIES",
        "05_SUMMARIES/05_99_ARCHIVE",
    ]

    for dir in dirs {
        let relative = "\(config.guidelinesPath)/\(dir)"
        let url = config.projectRoot.appendingPathComponent(relative)
        if !fileManager().fileExists(atPath: url.path) {
            try! fileManager().createDirectory(at: url, withIntermediateDirectories: true)
            // Add .gitkeep so empty dirs are tracked
            let gitkeep = url.appendingPathComponent(".gitkeep")
            fileManager().createFile(atPath: gitkeep.path, contents: nil)
        }
    }
    print("  ✓ Project directories under \(config.guidelinesPath)/ (implementation plans, checklists, summaries)")
}

// MARK: - Copy templates
//
// Templates already live inside the guidelines folder
// (`<guidelinesPath>/04_IMPLEMENTATION_CHECKLISTS/TEMPLATE.md` and
// `<guidelinesPath>/05_SUMMARIES/SESSION_SUMMARY_TEMPLATE.md`), and the
// project-state directories also live inside the guidelines folder, so
// no copying is required. This function is kept for forward
// compatibility but is intentionally a no-op.

func copyTemplates(config: Config) {
    _ = config
    print("  ⏭ Templates remain in place under \(config.guidelinesPath)/ (no copy needed)")
}

// MARK: - Main

func main() {
    let config = parseArgs()

    print("")
    print("╔══════════════════════════════════════════════════════╗")
    print("║     Development Guidelines — Claude Code Setup      ║")
    print("╠══════════════════════════════════════════════════════╣")
    print("║  Project:    \(config.projectName.padding(toLength: 38, withPad: " ", startingAt: 0)) ║")
    print("║  Guidelines: \(config.guidelinesPath.padding(toLength: 38, withPad: " ", startingAt: 0)) ║")
    print("╚══════════════════════════════════════════════════════╝")
    print("")

    // 1. CLAUDE.md
    print("Creating CLAUDE.md...")
    if fileExists(at: "CLAUDE.md", relativeTo: config.projectRoot) {
        let existing = readExisting(at: "CLAUDE.md", relativeTo: config.projectRoot) ?? ""
        if existing.contains("Development Guidelines") {
            print("  ⏭ CLAUDE.md already configured (skipping)")
        } else {
            // Prepend guidelines to existing CLAUDE.md
            let combined = generateCLAUDEmd(config) + "\n\n---\n\n" + existing
            writeFile(at: "CLAUDE.md", content: combined, relativeTo: config.projectRoot)
            print("  ↑ Prepended guidelines to existing CLAUDE.md")
        }
    } else {
        writeFile(at: "CLAUDE.md", content: generateCLAUDEmd(config), relativeTo: config.projectRoot)
    }

    // 2. .claude/rules/
    print("\nCreating .claude/rules/...")
    writeFile(at: ".claude/rules/swift-development.md",
              content: generateSwiftRules(config),
              relativeTo: config.projectRoot)

    // 3. Migrate legacy .claude/commands/ → .claude/skills/
    print("\nMigrating legacy commands...")
    migrateLegacyCommands(config: config)

    // 4. Migrate root-level project directories into guidelines folder
    print("\nMigrating root-level project directories...")
    migrateRootDirectories(config: config)

    // 5. .claude/skills/
    print("\nCreating .claude/skills/...")
    writeFile(at: ".claude/skills/design/SKILL.md",
              content: generateDesignSkill(config),
              relativeTo: config.projectRoot)
    writeFile(at: ".claude/skills/recover/SKILL.md",
              content: generateRecoverSkill(config),
              relativeTo: config.projectRoot)
    writeFile(at: ".claude/skills/summarize/SKILL.md",
              content: generateSummarizeSkill(config),
              relativeTo: config.projectRoot)
    writeFile(at: ".claude/skills/checklist/SKILL.md",
              content: generateChecklistSkill(config),
              relativeTo: config.projectRoot)

    // 6. .claude/settings.json (only if not present — don't overwrite team config)
    print("\nCreating .claude/settings.json...")
    if fileExists(at: ".claude/settings.json", relativeTo: config.projectRoot) {
        print("  ⏭ .claude/settings.json already exists (skipping)")
    } else {
        writeFile(at: ".claude/settings.json",
                  content: generateSettings(),
                  relativeTo: config.projectRoot)
    }

    // 7. Project scaffolding directories
    print("\nCreating project directories...")
    ensureProjectDirectories(config: config)

    // 8. Copy templates from guidelines
    print("\nCopying templates...")
    copyTemplates(config: config)

    // 9. Gitignore
    print("\nUpdating .gitignore...")
    ensureGitignoreEntries(config: config)

    // Summary
    print("")
    print("══════════════════════════════════════════════════════")
    print("  Setup complete!")
    print("")
    print("  Generated:")
    print("    CLAUDE.md                            — AI session entry point")
    print("    .claude/rules/swift-development.md   — Path-scoped Swift rules")
    print("    .claude/skills/design/SKILL.md       — /design <feature>")
    print("    .claude/skills/recover/SKILL.md      — /recover")
    print("    .claude/skills/summarize/SKILL.md    — /summarize")
    print("    .claude/skills/checklist/SKILL.md    — /checklist <feature>")
    print("    .claude/settings.json                — Default permissions")
    print("")
    print("  Commit .claude/ and CLAUDE.md to share with your team.")
    print("  Personal overrides go in .claude/settings.local.json")
    print("  and CLAUDE.local.md (both gitignored).")
    print("")
    print("  Start a session with:  claude")
    print("  Recover context with:  /recover")
    print("══════════════════════════════════════════════════════")
    print("")
}

main()
