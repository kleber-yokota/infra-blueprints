## Commit & Branch Guidelines

### Atomic Commits
- One logical change per commit
- Each commit must leave the project in a working state (tests passing, build green)
- Clear commit messages explaining the **why**, not the **what**
- Never mix refactoring, features, and bugfixes in a single commit

### Branches
- Always create a new branch for every task - never commit directly to `main`
- Use conventional branch naming:
  - `feat/description` - new features
  - `fix/description` - bug fixes
  - `refactor/description` - code refactoring
  - `hotfix/description` - urgent fixes
- Keep branches small and focused to make PR reviews faster and cleaner

### Before Pushing
- Always `git pull main` before pushing to check for conflicts
- Resolve any conflicts locally before creating the PR
