#!/bin/bash
# Skrypt do tworzenia kopii zapasowej workflow z n8n do repozytorium Git

# Zatrzymaj wykonywanie skryptu w przypadku błędu
set -e
# Zwróć błąd, jeśli jakakolwiek komenda w potoku (pipe) zakończy się błędem
set -o pipefail

# --- Walidacja zmiennych środowiskowych ---
# Sprawdzenie, czy wszystkie wymagane zmienne środowiskowe są ustawione.
# Jeśli którejś brakuje, skrypt zakończy działanie z błędem.
required_vars=("N8N_URL" "N8N_API_KEY" "GIT_REPO_URL" "GIT_USER_NAME" "GIT_USER_EMAIL")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Błąd: Zmienna środowiskowa $var nie jest ustawiona."
    exit 1
  fi
done

# --- Konfiguracja i klonowanie repozytorium Git ---
# Katalog roboczy jest ustawiony na /app/backup w Dockerfile.

echo "Klonowanie repozytorium: ${GIT_REPO_URL}"
# Klonujemy repozytorium. W czystym kontenerze ten folder będzie pusty,
# więc `clone` jest właściwą operacją. Używamy --quiet aby zredukować logi.
git clone --quiet "${GIT_REPO_URL}" .

echo "Konfiguracja użytkownika Git..."
git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

# Sprawdzamy, czy gałąź 'main' lub 'master' istnieje w zdalnym repozytorium.
# Jeśli tak, przełączamy się na nią i pobieramy zmiany.
if git ls-remote --exit-code --heads origin main; then
    echo "Znaleziono gałąź 'main'. Synchronizacja..."
    git checkout main
    git pull origin main
elif git ls-remote --exit-code --heads origin master; then
    # Fallback dla starszych repozytoriów używających 'master'
    echo "Znaleziono gałąź 'master'. Synchronizacja..."
    git checkout master
    git pull origin master
else
    echo "Repozytorium zdalne jest puste. Inicjalizacja nowej gałęzi 'main'."
    # Jeśli nie ma żadnej gałęzi, tworzymy 'main' lokalnie.
    # Zostanie ona wypchnięta na serwer po dodaniu pierwszych plików.
    git checkout -b main
fi

# --- Pobieranie workflow z n8n ---
echo "Pobieranie listy workflow z n8n..."
# Pobieramy listę wszystkich workflow za pomocą API n8n.
# Używamy `curl` do wykonania zapytania GET i `jq` do przetworzenia odpowiedzi JSON.
workflows_json=$(curl -sS --request GET \
  --url "${N8N_URL}/api/v1/workflows" \
  --header "Accept: application/json" \
  --header "X-N8N-API-KEY: ${N8N_API_KEY}")

# Sprawdzamy, czy odpowiedź nie zawiera błędu
if echo "$workflows_json" | jq -e '.message' > /dev/null; then
    echo "Błąd podczas pobierania workflow z n8n:"
    echo "$workflows_json" | jq '.message'
    exit 1
fi

# Iterujemy po każdym workflow z listy
echo "$workflows_json" | jq -c '.data[]' | while read -r workflow_item; do
  workflow_id=$(echo "$workflow_item" | jq -r '.id')
  workflow_name=$(echo "$workflow_item" | jq -r '.name')

  # Sanityzacja nazwy workflow, aby nadawała się na nazwę folderu
  sanitized_name=$(echo "$workflow_name" | tr -s ' ' '_' | sed 's/[^a-zA-Z0-9_-]//g')
  
  mkdir -p "$sanitized_name"

  echo "Pobieranie definicji dla: '$workflow_name' (ID: $workflow_id)"
  
  # Pobieramy pełną definicję JSON dla danego workflow
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
  
  # Pobieramy aktualną nazwę gałęzi, na której jesteśmy
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  
  # Używamy --set-upstream (lub -u) dla pierwszego pusha, aby powiązać 
  # lokalną gałąź ze zdalną. Polecenie jest bezpieczne przy kolejnych użyciach.
  git push --set-upstream origin "${CURRENT_BRANCH}"
  
  echo "Zmiany zostały wypchnięte do repozytorium."
else
  echo "Brak zmian. Repozytorium jest aktualne."
fi

echo "Skrypt zakończył działanie."
