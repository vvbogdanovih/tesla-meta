#!/usr/bin/env bash
#
# Стягує (клонує або оновлює) застосунки проєкту в ./repos/.
# repos/ навмисно НЕ в git tesla-meta — кожен застосунок має власний репозиторій.
#
# Використання:
#   ./scripts/clone-repos.sh
#
# Базу remote можна перевизначити (напр. SSH-аліас або HTTPS):
#   REPO_BASE="git@github_vvbogdanovih:vvbogdanovih" ./scripts/clone-repos.sh
#   REPO_BASE="https://github.com/vvbogdanovih" ./scripts/clone-repos.sh

set -euo pipefail

REPO_BASE="${REPO_BASE:-git@github.com:vvbogdanovih}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/repos"

REPOS=(tesla-frontend tesla-admin tesla-backend)

mkdir -p "$DEST"
echo "📦 База: $REPO_BASE"
echo "📂 Призначення: $DEST"
echo

for r in "${REPOS[@]}"; do
  target="$DEST/$r"
  if [ -d "$target/.git" ]; then
    echo "↻ $r — оновлення (git pull --ff-only)"
    git -C "$target" pull --ff-only || echo "  ⚠️  не вдалось fast-forward — перевірте локальні зміни"
  else
    echo "⬇ $r — клонування"
    git clone "$REPO_BASE/$r.git" "$target"
  fi
  echo
done

echo "✅ Готово. Застосунки — у repos/"
