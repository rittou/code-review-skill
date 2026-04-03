# review-code

Senior-style Codex skill for code review.

It helps Codex review:

- code logic
- security issues
- performance issues and trade-offs
- code cleanliness
- code design and architecture
- code style
- native-function usage and composition across languages
- test and coverage evidence across languages

## Repository layout

```text
review-code/
├── SKILL.md
├── README.md
├── agents/
│   └── openai.yaml
└── references/
    ├── senior-review-principles.md
    ├── code-logic-review.md
    ├── security-review.md
    ├── performance-review.md
    ├── code-cleanliness-review.md
    ├── code-architecture-review.md
    ├── code-style-review.md
    ├── native-functions-review.md
    ├── test-coverage-review.md
    └── review-output-template.md
```

## Install

### Option 1: Use directly from a local path

If the skill is not installed into Codex's skill directory, reference it by path when prompting:

```text
Use $review-code at /absolute/path/to/review-code to review this patch.
```

Example:

```text
Use $review-code at /Users/your-name/code/review-code to review this PR for logic, security, performance, cleanliness, style, and coverage evidence.
```

### Option 2: Install for auto-discovery

Clone or copy the folder into your Codex skills directory:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R /path/to/review-code "${CODEX_HOME:-$HOME/.codex}/skills/"
```

After that, Codex can discover the skill by name:

```text
Use $review-code to review this patch.
```

### Option 3: Keep the repo in `~/code` and symlink it

This is useful if you want the repository to stay shareable in one place while still being auto-discovered by Codex:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s /path/to/review-code "${CODEX_HOME:-$HOME/.codex}/skills/review-code"
```

## How to use

### Basic review

```text
Use $review-code to review this patch for logic bugs, security issues, performance regressions, cleanliness, style, and test coverage gaps.
```

### Review a change with coverage focus

```text
Use $review-code to review the changed files and tell me which touched lines are not covered.
```

### Review a PR like a senior engineer

```text
Use $review-code to review this PR like a senior engineer and separate blocking findings from nits.
```

### Use it by path without installation

```text
Use $review-code at /Users/your-name/code/review-code to review this diff.
```

## What the skill loads

The main workflow lives in `SKILL.md`.

The deeper review guidance is split into maintainable domain references:

- `references/senior-review-principles.md`
- `references/code-logic-review.md`
- `references/security-review.md`
- `references/performance-review.md`
- `references/code-cleanliness-review.md`
- `references/code-architecture-review.md`
- `references/code-style-review.md`
- `references/native-functions-review.md`
- `references/test-coverage-review.md`
- `references/review-output-template.md`

## Notes

- The skill is designed to keep findings risk-first and evidence-based.
- It prefers changed-line and branch-risk reasoning over percentage theater.
- If direct coverage tooling is unavailable, the skill should report that clearly instead of inventing coverage claims.
