# Metropoles Backend Makefile
# ------------------------------------------------------------------------------

.PHONY: help push-staging current-branch cherry-pick-to-staging check-commits-to-staging

# Default target when just running 'make'
help:
	@echo "Available commands:"
	@echo "  make push-staging     - Push current branch to staging (force push)"
	@echo "  make current-branch   - Show current branch name"
	@echo "  make cherry-pick-to-staging - Cherry-pick commits from main to staging"
	@echo "  make check-commits-to-staging - Check which commits would be cherry-picked"

# Get the current branch name
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

# Push current branch to staging (force push)
push-staging:
	@echo "Pushing $(CURRENT_BRANCH) to staging (force)..."
	git push origin $(CURRENT_BRANCH):staging --force
	@echo "✅ Successfully pushed to staging"

# Show current branch name
current-branch:
	@echo "Current branch: $(CURRENT_BRANCH)" 

# Cherry-pick commits to staging branch
cherry-pick-to-staging:
	@echo "Cherry-picking commits from main to staging branch..."; \
    ORIG_BRANCH=$(CURRENT_BRANCH); \
    git fetch origin main staging; \
    git checkout staging; \
    for commit in $$(git log main..$$ORIG_BRANCH --pretty=format:"%H" | tac); do \
        COMMIT_MSG=$$(git log --format=%B -n 1 $$commit | head -n 1); \
        echo "Cherry-picking commit: $$COMMIT_MSG"; \
        if git cherry-pick -x $$commit 2>&1 | tee /tmp/cherry-pick.log | grep -q "The previous cherry-pick is now empty"; then \
            echo "Skipping commit (already applied or empty): $$COMMIT_MSG"; \
            git cherry-pick --skip; \
        elif grep -q "error: could not apply" /tmp/cherry-pick.log; then \
            echo "❌ Cherry-pick failed. Resolve conflicts and run 'git cherry-pick --continue'"; \
            echo "After resolving, run 'git checkout $$ORIG_BRANCH' to return to your branch"; \
            exit 1; \
        fi; \
    done; \
    git push origin staging; \
    git checkout $$ORIG_BRANCH; \
    echo "✅ Successfully cherry-picked commits to staging branch"

# Check which commits would be cherry-picked without actually doing it
check-commits-to-staging:
	@echo "Checking commits that would be cherry-picked from main to staging..."; \
    git fetch origin main staging; \
    ORIG_BRANCH=$(CURRENT_BRANCH); \
    COMMITS=$$(git log main..$$ORIG_BRANCH --pretty=format:"%H" | tac); \
    STAGING_PATCHES=$$(git log main..staging --pretty=format:"%H" | xargs -n1 git show --pretty=format:%P --no-patch | xargs -n1 git show --pretty=format:%B --no-patch | git patch-id --stable | cut -d' ' -f1 | tr '\n' ' '); \
    NEEDED=""; \
    for commit in $$COMMITS; do \
        PATCH_ID=$$(git show $$commit | git patch-id --stable | cut -d' ' -f1); \
        case " $$STAGING_PATCHES " in \
            *$$PATCH_ID*) \
                : ;; \
            *) \
                COMMIT_MSG=$$(git log --format="%h - %s (%an)" -n 1 $$commit); \
                NEEDED="$$NEEDED\n$$COMMIT_MSG"; \
            ;; \
        esac; \
    done; \
    if [ -z "$$NEEDED" ]; then \
        echo "No new commits to cherry-pick"; \
    else \
        echo "The following commits would be cherry-picked to staging:"; \
        echo "$$NEEDED" | grep -v '^$$'; \
        echo ""; \
        echo "Total: $$(echo "$$NEEDED" | grep -c .) commit(s)"; \
    fi