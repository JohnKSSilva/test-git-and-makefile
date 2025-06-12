# Makefile for Git Cherry-pick Operations
# ------------------------------------------------------------------------------

.PHONY: help cherry-pick-to-staging check-commits-to-staging current-branch

# Get the current branch name
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

# Default target
help:
	@echo "Available commands:"
	@echo "  make cherry-pick-to-staging   - Cherry-pick commits from current branch to staging"
	@echo "  make check-commits-to-staging - Show commits that would be cherry-picked"
	@echo "  make current-branch           - Show current branch name"

# Show current branch name
current-branch:
	@echo "Current branch: $(CURRENT_BRANCH)"

# Check which commits would be cherry-picked (dry run)
check-commits-to-staging:
    @echo "Checking commits that would be cherry-picked from main to staging..."
    @git fetch origin main staging
    @ORIG_BRANCH=$(CURRENT_BRANCH); \
    echo "The following commits would be cherry-picked to staging:"; \
    echo ""; \
    COUNT=0; \
    git cherry staging $$ORIG_BRANCH | grep '^+' | while read status commit; do \
        COMMIT_MSG=$$(git log --format="%h - %s (%an)" -n 1 $$commit); \
        echo "  - $$COMMIT_MSG"; \
        COUNT=$$((COUNT + 1)); \
    done; \
    if [ $$COUNT -eq 0 ]; then \
        echo "❌ No new commits to cherry-pick"; \
    else \
        echo ""; \
        echo "Total: $$COUNT commit(s)"; \
    fi

cherry-pick-to-staging:
    @echo "Cherry-picking commits from main to staging branch..."
    @ORIG_BRANCH=$(CURRENT_BRANCH); \
    git fetch origin main staging; \
    git checkout staging; \
    git cherry staging $$ORIG_BRANCH | grep '^+' | while read status commit; do \
        COMMIT_MSG=$$(git log --format=%B -n 1 $$commit | head -n 1); \
        echo "Cherry-picking commit: $$COMMIT_MSG"; \
        if git cherry-pick -x $$commit 2>&1 | tee /tmp/cherry-pick.log; then \
            echo "✅ Successfully cherry-picked: $$COMMIT_MSG"; \
        elif grep -q "The previous cherry-pick is now empty" /tmp/cherry-pick.log; then \
            echo "⚠️  Skipping commit (already applied): $$COMMIT_MSG"; \
            git cherry-pick --skip; \
        else \
            echo "❌ Cherry-pick failed. Resolve conflicts and run:"; \
            echo "   git cherry-pick --continue"; \
            echo "   git checkout $$ORIG_BRANCH"; \
            exit 1; \
        fi; \
    done; \
    git push origin staging; \
    git checkout $$ORIG_BRANCH; \
    echo "✅ Successfully cherry-picked all commits to staging branch"