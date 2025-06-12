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
	@echo "Checking commits that would be cherry-picked from $(CURRENT_BRANCH) to staging..."
	@git fetch origin main staging
	@echo "Debug: Commits in staging but not in main:"
	@git rev-list --reverse main..staging | while read commit; do \
		echo "  $$commit - $$(git log --format='%s' -n 1 $$commit)"; \
		echo "    Full message: $$(git log --format='%B' -n 1 $$commit | tr '\n' ' ')"; \
	done
	@echo "Debug: Commits in $(CURRENT_BRANCH) but not in main:"
	@git rev-list --reverse main..$(CURRENT_BRANCH) | while read commit; do \
		echo "  $$commit - $$(git log --format='%s' -n 1 $$commit)"; \
	done
	@echo ""
	@ORIG_BRANCH=$(CURRENT_BRANCH); \
	COMMITS_TO_PICK=""; \
	COMMITS_ALREADY_IN_STAGING=""; \
	COUNT_TO_PICK=0; \
	COUNT_ALREADY_IN_STAGING=0; \
	for commit in $$(git rev-list --reverse main..$$ORIG_BRANCH); do \
		COMMIT_MSG=$$(git log --format="%h - %s (%an)" -n 1 $$commit); \
		COMMIT_HASH=$$commit; \
		if git rev-list main..staging | xargs -I {} git log --format='%B' -n 1 {} | grep -q "cherry picked from commit $$COMMIT_HASH"; then \
			COMMITS_ALREADY_IN_STAGING="$$COMMITS_ALREADY_IN_STAGING  - $$COMMIT_MSG\n"; \
			COUNT_ALREADY_IN_STAGING=$$((COUNT_ALREADY_IN_STAGING + 1)); \
			echo "Debug: $$commit already cherry-picked to staging"; \
		else \
			COMMITS_TO_PICK="$$COMMITS_TO_PICK  - $$COMMIT_MSG\n"; \
			COUNT_TO_PICK=$$((COUNT_TO_PICK + 1)); \
			echo "Debug: $$commit needs to be picked"; \
		fi; \
	done; \
	if [ $$COUNT_TO_PICK -eq 0 ] && [ $$COUNT_ALREADY_IN_STAGING -eq 0 ]; then \
		echo "❌ No commits found between main and $(CURRENT_BRANCH)"; \
	else \
		if [ $$COUNT_TO_PICK -gt 0 ]; then \
			echo "The following commits would be cherry-picked to staging:"; \
			echo ""; \
			printf "$$COMMITS_TO_PICK"; \
			echo ""; \
			echo "Total to cherry-pick: $$COUNT_TO_PICK commit(s)"; \
		fi; \
		if [ $$COUNT_ALREADY_IN_STAGING -gt 0 ]; then \
			echo ""; \
			echo "The following commits are already in staging:"; \
			echo ""; \
			printf "$$COMMITS_ALREADY_IN_STAGING"; \
			echo ""; \
			echo "Total already in staging: $$COUNT_ALREADY_IN_STAGING commit(s)"; \
		fi; \
	fi

# Cherry-pick commits from current branch to staging (oldest to newest)
cherry-pick-to-staging:
	@echo "Cherry-picking commits from $(CURRENT_BRANCH) to staging branch..."
	@ORIG_BRANCH=$(CURRENT_BRANCH); \
	git fetch origin main staging; \
	git checkout staging; \
	echo "Debug: Original branch is $$ORIG_BRANCH"; \
	echo "Debug: Commits to process:"; \
	git rev-list --reverse main..$$ORIG_BRANCH | while read commit; do \
		echo "  $$commit"; \
	done; \
	COMMITS_PROCESSED=0; \
	for commit in $$(git rev-list --reverse main..$$ORIG_BRANCH); do \
		COMMITS_PROCESSED=$$((COMMITS_PROCESSED + 1)); \
		COMMIT_HASH=$$commit; \
		echo "Debug: Processing commit $$COMMITS_PROCESSED: $$COMMIT_HASH"; \
		if git rev-list main..staging | xargs -I {} git log --format='%B' -n 1 {} | grep -q "cherry picked from commit $$COMMIT_HASH"; then \
			COMMIT_MSG=$$(git log --format="%h - %s" -n 1 $$commit); \
			echo "⚠️  Skipping commit (already cherry-picked): $$COMMIT_MSG"; \
		else \
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
		fi; \
	done; \
	echo "Debug: Total commits processed: $$COMMITS_PROCESSED"; \
	if [ $$COMMITS_PROCESSED -gt 0 ]; then \
		git push origin staging; \
	else \
		echo "No commits to push"; \
	fi; \
	git checkout $$ORIG_BRANCH; \
	echo "✅ Successfully cherry-picked all commits to staging branch"