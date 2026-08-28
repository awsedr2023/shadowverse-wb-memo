#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 が見つかりません。"
}

repository() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null)" || fail "origin リモートが必要です。"

  case "$remote" in
    https://github.com/*.git) printf '%s\n' "${remote#https://github.com/}" | sed 's/\.git$//' ;;
    https://github.com/*) printf '%s\n' "${remote#https://github.com/}" ;;
    git@github.com:*.git) printf '%s\n' "${remote#git@github.com:}" | sed 's/\.git$//' ;;
    git@github.com:*) printf '%s\n' "${remote#git@github.com:}" ;;
    *) fail "GitHub origin ではありません: $remote" ;;
  esac
}

require_confirmation() {
  local confirmation="$1"
  if [[ "$confirmation" != "1" ]]; then
    fail "外部変更を行いません。実行するには CONFIRM=1 を指定してください。"
  fi
}

require_nonempty() {
  local name="$1"
  local value="$2"
  [[ -n "$value" ]] || fail "$name を指定してください。"
}

require_file() {
  local name="$1"
  local path="$2"
  [[ -f "$path" ]] || fail "$name が見つかりません: $path"
}

project_metadata() {
  local number="$1" owner repo query result
  [[ "$number" =~ ^[0-9]+$ ]] || fail "project_number は正の整数にしてください。"
  repo="$(repository)"
  owner="${repo%%/*}"

  read -r -d '' query <<'GRAPHQL' || true
query($owner: String!, $number: Int!) {
  user(login: $owner) {
    projectV2(number: $number) {
      id
      field(name: "Status") {
        ... on ProjectV2SingleSelectField {
          id
          options { id name }
        }
      }
    }
  }
}
GRAPHQL
  result="$(gh api graphql -f query="$query" -f "owner=$owner" -F "number=$number")" || \
    fail "GitHub Projectの設定を取得できませんでした。gh auth status とネットワーク接続を確認してください。"
  jq -e '.data.user.projectV2.id and .data.user.projectV2.field.id' >/dev/null <<< "$result" || \
    fail "ProjectまたはStatusフィールドを解決できません。PROJECT_NUMBER を確認してください。"
  printf '%s\n' "$result"
}

check_config() {
  local number="$1" metadata
  metadata="$(project_metadata "$number")"
  printf 'GitHub Project設定を確認しました。\n'
  jq -r '"Project: \(.data.user.projectV2.id)\nStatus: \([.data.user.projectV2.field.options[].name] | join(", "))"' <<< "$metadata"
}

create_issue() {
  local title="$1" body_file="$2" labels="$3" confirmation="$4" parent_issue_number="${5:-}"
  local repo label created issue_number issue_id
  require_nonempty ISSUE_TITLE "$title"
  require_file ISSUE_BODY_FILE "$body_file"
  require_confirmation "$confirmation"
  if [[ -n "$parent_issue_number" ]]; then
    [[ "$parent_issue_number" =~ ^[0-9]+$ ]] || fail "PARENT_ISSUE_NUMBER は正の整数にしてください。"
  fi
  repo="$(repository)"

  local -a args=(api --method POST "repos/$repo/issues" -f "title=$title" -F "body=@$body_file")
  if [[ -n "$labels" ]]; then
    IFS=',' read -r -a label_list <<< "$labels"
    for label in "${label_list[@]}"; do
      label="${label#"${label%%[![:space:]]*}"}"
      label="${label%"${label##*[![:space:]]}"}"
      [[ -n "$label" ]] && args+=(-f "labels[]=$label")
    done
  fi

  created="$(gh "${args[@]}")"
  issue_number="$(jq -r '.number' <<< "$created")"
  issue_id="$(jq -r '.id' <<< "$created")"

  if [[ -n "$parent_issue_number" ]]; then
    gh api --method POST "repos/$repo/issues/$parent_issue_number/sub_issues" \
      -F "sub_issue_id=$issue_id" >/dev/null
    printf 'Created sub-issue #%s under #%s: %s\n' "$issue_number" "$parent_issue_number" \
      "$(jq -r '.html_url' <<< "$created")"
  else
    printf 'Created issue #%s: %s\n' "$issue_number" "$(jq -r '.html_url' <<< "$created")"
  fi
}

create_pr() {
  local title="$1" body_file="$2" head="$3" base="$4" confirmation="$5"
  local repo
  require_nonempty PR_TITLE "$title"
  require_file PR_BODY_FILE "$body_file"
  require_nonempty PR_HEAD "$head"
  [[ -n "$base" ]] || base="main"
  require_confirmation "$confirmation"
  git show-ref --verify --quiet "refs/heads/$head" || fail "ローカルブランチが見つかりません: $head"
  git ls-remote --exit-code --heads origin "$head" >/dev/null || fail "push済みのリモートブランチが必要です: $head"
  repo="$(repository)"

  gh api --method POST "repos/$repo/pulls" \
    -f "title=$title" \
    -F "body=@$body_file" \
    -f "head=$head" \
    -f "base=$base" \
    --jq '"Created pull request #\(.number): \(.html_url)"'
}

set_project_status() {
  local issue_number="$1" status="$2" confirmation="$3" project_number="$4"
  local repo issue_id option_id item_id query mutation result metadata project_id status_field_id
  require_nonempty ISSUE_NUMBER "$issue_number"
  require_nonempty STATUS "$status"
  require_confirmation "$confirmation"
  [[ "$issue_number" =~ ^[0-9]+$ ]] || fail "ISSUE_NUMBER は正の整数にしてください。"
  metadata="$(project_metadata "$project_number")"
  project_id="$(jq -r '.data.user.projectV2.id' <<< "$metadata")"
  status_field_id="$(jq -r '.data.user.projectV2.field.id' <<< "$metadata")"
  option_id="$(jq -r --arg status "$status" '.data.user.projectV2.field.options[] | select(.name == $status) | .id' <<< "$metadata")"
  [[ -n "$option_id" ]] || fail "許可されていないStatusです: $status"
  repo="$(repository)"
  issue_id="$(gh api "repos/$repo/issues/$issue_number" --jq '.node_id')"

  read -r -d '' query <<'GRAPHQL' || true
query($projectId: ID!, $issueId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue { id }
          }
        }
      }
    }
  }
}
GRAPHQL
  result="$(gh api graphql -f query="$query" -f "projectId=$project_id" -f "issueId=$issue_id")"
  item_id="$(jq -r --arg issue_id "$issue_id" '.data.node.items.nodes[] | select(.content.id == $issue_id) | .id' <<< "$result")"
  [[ -n "$item_id" ]] || fail "Issue #$issue_number はProjectにありません。"

  read -r -d '' mutation <<'GRAPHQL' || true
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId,
    itemId: $itemId,
    fieldId: $fieldId,
    value: { singleSelectOptionId: $optionId }
  }) {
    projectV2Item { id }
  }
}
GRAPHQL
  gh api graphql \
    -f query="$mutation" \
    -f "projectId=$project_id" \
    -f "itemId=$item_id" \
    -f "fieldId=$status_field_id" \
    -f "optionId=$option_id" >/dev/null
  printf 'Issue #%s を %s へ移動しました。\n' "$issue_number" "$status"
}

main() {
  require_command gh
  require_command git
  require_command jq

  local command="${1:-}"
  case "$command" in
    check-config) check_config "${2:-}" ;;
    issue-create) create_issue "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" ;;
    pr-create) create_pr "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" ;;
    project-status) set_project_status "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
    *) fail "使い方: $0 {check-config|issue-create|pr-create|project-status}" ;;
  esac
}

main "$@"
