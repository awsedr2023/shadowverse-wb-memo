.DEFAULT_GOAL := help

.PHONY: help github-check issue-create subissue-create pr-create project-status

help:
	@printf '%s\n' \
	  'GitHub 操作（WSL + gh CLI）:' \
	  '  make github-check' \
	  '  make issue-create ISSUE_TITLE="..." ISSUE_BODY_FILE=path [ISSUE_LABELS="type:chore,area:infra"] CONFIRM=1' \
	  '  make subissue-create PARENT_ISSUE_NUMBER=123 ISSUE_TITLE="..." ISSUE_BODY_FILE=path [ISSUE_LABELS="..."] CONFIRM=1' \
	  '  make pr-create PR_TITLE="..." PR_BODY_FILE=path PR_HEAD=branch [PR_BASE=main] CONFIRM=1' \
	  '  make project-status ISSUE_NUMBER=123 STATUS="In Progress" CONFIRM=1' \
	  '' \
	  'CONFIRM=1 がない場合、外部変更は実行しません。'

github-check:
	@./scripts/github.sh check-config

issue-create:
	@./scripts/github.sh issue-create "$(ISSUE_TITLE)" "$(ISSUE_BODY_FILE)" "$(ISSUE_LABELS)" "$(CONFIRM)"

subissue-create:
	@./scripts/github.sh issue-create "$(ISSUE_TITLE)" "$(ISSUE_BODY_FILE)" "$(ISSUE_LABELS)" "$(CONFIRM)" "$(PARENT_ISSUE_NUMBER)"

pr-create:
	@./scripts/github.sh pr-create "$(PR_TITLE)" "$(PR_BODY_FILE)" "$(PR_HEAD)" "$(PR_BASE)" "$(CONFIRM)"

project-status:
	@./scripts/github.sh project-status "$(ISSUE_NUMBER)" "$(STATUS)" "$(CONFIRM)"
