#!/bin/bash
# Skrypt do tworzenia kopii zapasowej workflow z n8n do repozytorium Git
# Wersja odporna na wielokrotne uruchomienia w tym samym środowisku.

# Zatrzymaj wykonywanie skryptu w przypadku błędu
set -e
# Zwróć błąd, jeśli jakakolwiek komenda w potoku (pipe) zakończy się błędem
set -o pipefail

# --- Walidacja zmiennych środowiskowych ---
required_vars=("N8N_URL" "N8N_API_KEY" "GIT_REPO_URL" "GIT_USER_NAME" "GIT_USER_EMAIL")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Błąd: Zmienna środowiskowa $var nie jest ustawiona."
    exit 1
  fi
done

# --- Inicjalizacja lub aktualizacja repozytorium Git ---
# Katalog roboczy jest ustawiony na /app/backup w Dockerfile.

# Sprawdź, czy repozytorium jest już sklonowane (czy istnieje folder .git)
if [ -d ".git" ]; then
    echo "Repozytorium już istnieje. Aktualizowanie..."
    # Upewnij się, że zdalny URL jest poprawny (na wypadek zmiany tokenu)
    git remote set-url origin "${GIT_REPO_URL}"
else
    echo "Klonowanie repozytorium: ${GIT_REPO_URL}"
    # Usuń ewentualne pozostałości, aby klonowanie się powiodło
    rm -rf ./*
    # Klonujemy repozytorium do bieżącego folderu.
    git clone --quiet "${GIT_REPO_URL}" .
fi

echo "Konfiguracja użytkownika Git..."
git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

# Sprawdzamy, czy gałąź 'main' lub 'master' istnieje w zdalnym repozytorium.
if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    echo "Synchronizacja z gałęzią 'main'..."
    git checkout main
    git pull origin main
elif git ls-remote --exit-code --heads origin master >/dev/null 2>&1; then
    echo "Synchronizacja z gałęzią 'master'..."
    git checkout master
    git pull origin master
else
    echo "Repozytorium zdalne jest puste. Inicjalizacja nowej gałęzi 'main'."
    git checkout -B main
fi

# --- Pobieranie workflow z n8n ---
echo "Pobieranie listy workflow z n8n..."
workflows_json=$(curl -sS --request GET \
  --url "${N8N_URL}/api/v1/workflows" \
  --header "Accept: application/json" \
  --header "X-N8N-API-KEY: ${N8N_API_KEY}")

if echo "$workflows_json" | jq -e '.message' > /dev/null; then
    echo "Błąd podczas pobierania workflow z n8n:"
    echo "$workflows_json" | jq '.message'
    exit 1
fi

echo "$workflows_json" | jq -c '.data[]' | while read -r workflow_item; do
  workflow_id=$(echo "$workflow_item" | jq -r '.id')
  workflow_name=$(echo "$workflow_item" | jq -r '.name')
  sanitized_name=$(echo "$workflow_name" | tr -s ' ' '_' | sed 's/[^a-zA-Z0-9_-]//g')
  
  mkdir -p "$sanitized_name"
  echo "Pobieranie definicji dla: '$workflow_name' (ID: $workflow_id)"
  
  curl -sS --request GET \
    --url "${N8N_URL}/api/v1/workflows/${workflow_id}" \
    --header "Accept: application/json" \
    --header "X-N8N-API-KEY: ${N8N_API_KEY}" | jq . > "${sanitized_name}/workflow.json"
done
echo "Proces pobierania zakończony."

# --- Commit i push zmian do Git ---
echo "Sprawdzanie zmian w repozytorium..."
if [[ -n $(git status --porcelain) ]]; then
  echo "Wykryto zmiany. Dodawanie, commitowanie i wypychanie..."
  git add .
  git commit -m "Automatyczna aktualizacja workflow n8n - $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push --set-upstream origin "${CURRENT_BRANCH}"
  
  echo "Zmiany zostały wypchnięte do repozytorium."
else
  echo "Brak zmian. Repozytorium jest aktualne."
fi

echo "Skrypt zakończył działanie."
