# Makefile
# ------------------------------------------------------------------------------

.PHONY: help push-staging current-branch cherry-pick-to-staging

# Default target when just running 'make'
help:
    @echo "Available commands:"
    @echo "  make push-staging     - Push current branch to staging (force push)"
    @echo "  make current-branch   - Show current branch name"
    @echo "  make cherry-pick-to-staging - Cherry-pick commits from main to staging"

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
    @echo "Cherry-picking commits from main to staging branch..."
    @ORIG_BRANCH=$(CURRENT_BRANCH) && \
    git fetch origin main staging && \
    COMMITS=$$(git log main..$(CURRENT_BRANCH) --pretty=format:"%H") && \
    if [ -z "$$COMMITS" ]; then \
        echo "❌ No new commits to cherry-pick"; \
        exit 1; \
    fi && \
    git checkout staging && \
    echo "$$COMMITS" | tac | while read commit; do \
        COMMIT_MSG=$$(git log --format=%B -n 1 $$commit | head -n 1) && \
        if git cherry staging | grep -q "+$$commit"; then \
            echo "Cherry-picking commit: $$COMMIT_MSG" && \
            if ! git cherry-pick -x $$commit; then \
                echo "❌ Cherry-pick failed. Resolve conflicts and run 'git cherry-pick --continue'"; \
                echo "After resolving, run 'git checkout $$ORIG_BRANCH' to return to your branch"; \
                exit 1; \
            fi; \
        else \
            echo "Skipping commit (already in staging): $$COMMIT_MSG"; \
        fi; \
    done && \
    git push origin staging && \
    git checkout $$ORIG_BRANCH && \
    echo "✅ Successfully cherry-picked commits to staging branch"