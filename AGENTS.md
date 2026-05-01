## Commit & Branch Guidelines

### Atomic Commits
- One logical change per commit - no mixing features, refactoring, and bugfixes
- Each commit must leave the project in a working state (tests passing, build green)
- Clear commit messages explaining the **why**, not the **what**
- Keep commits small and focused for easier review and bisect

### Branch Creation
- Always create a new branch for every task - never commit directly to `main`
- Conventional naming:
  - `feat/description` - new features
  - `fix/description` - bug fixes
  - `refactor/description` - code refactoring
  - `hotfix/description` - urgent fixes
- Keep branches focused and small for faster PR reviews

### Before Pushing
- Always `git pull main` before pushing to check for conflicts
- Resolve any conflicts locally before creating the PR
