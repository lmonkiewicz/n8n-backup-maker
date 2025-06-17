# n8n Git backup maker

Ten projekt umożliwia automatyczne tworzenie kopii zapasowych wszystkich workflow z Twojej instancji n8n do dedykowanego repozytorium Git. Proces jest uruchamiany w kontenerze Docker i może być łatwo wdrożony na platformach hostingowych, takich jak Railway.app, z cyklicznym uruchamianiem za pomocą crona.

---

## Wymagane Zmienne Środowiskowe

Do poprawnego działania skryptu musisz ustawić następujące zmienne środowiskowe.

| Zmienna          | Opis                                                                                                                                                               | Przykład                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| `N8N_URL`        | Pełny adres URL Twojej instancji n8n, bez ukośnika na końcu.                                                                                                        | `https://n8n.twojadomena.pl`                                                      |
| `N8N_API_KEY`    | Klucz API wygenerowany w Twojej instancji n8n. Znajdziesz go w *Settings > API*.                                                                                    | `n8n-api-key-goes-here`                                                           |
| `GIT_REPO_URL`   | Adres URL repozytorium Git **z osadzonym Personal Access Token (PAT)**. Jest to kluczowe dla automatyzacji.                                                          | `https://nazwa_uzytkownika:token@github.com/uzytkownik/repozytorium.git`          |
| `GIT_USER_NAME`  | Nazwa użytkownika, która będzie widoczna jako autor commitów. Może to być nazwa bota.                                                                              | `n8n-backup-bot`                                                                  |
| `GIT_USER_EMAIL` | Adres e-mail, który będzie widoczny jako autor commitów.                                                                                                           | `bot@example.com`                                                                 |

---

## Uruchomienie lokalne (Docker)

1.  Upewnij się, że masz zainstalowanego Dockera na swoim komputerze.
2.  Umieść pliki `Dockerfile` oraz `backup_workflows.sh` w jednym folderze.
3.  W tym samym folderze utwórz plik `.env` i uzupełnij go swoimi zmiennymi:
    ```
    N8N_URL=[https://n8n.twojadomena.pl](https://n8n.twojadomena.pl)
    N8N_API_KEY=twoj-klucz-api
    GIT_REPO_URL=https://uzytkownik:twoj-token@github.com/uzytkownik/repo.git
    GIT_USER_NAME=n8n-backup-bot
    GIT_USER_EMAIL=bot@example.com
    ```
4.  Zbuduj obraz Docker:
    ```sh
    docker build -t n8n-backup-agent .
    ```
5.  Uruchom kontener:
    ```sh
    docker run --rm --env-file .env n8n-backup-agent
    ```

---

## Wdrożenie na Railway.app

Możesz łatwo wdrożyć ten projekt na Railway, aby uruchamiał się automatycznie. Poniższa instrukcja zakłada, że masz już utworzony projekt w Railway i chcesz dodać do niego nową usługę (service) na podstawie tego repozytorium.

### Krok 1: Wdróż to repozytorium

1.  Zaloguj się na swoje konto w [Railway.app](https://railway.app) i przejdź do swojego projektu.
2.  Kliknij **New** i wybierz opcję **GitHub Repo**.
3.  Wybierz **to repozytorium** z listy. Railway automatycznie wykryje plik `Dockerfile` i rozpocznie proces budowania usługi.

### Krok 2: Ustaw zmienne środowiskowe

1.  Po zakończeniu wdrożenia, kliknij na nowo utworzoną usługę (service) w Twoim projekcie.
2.  Przejdź do zakładki **Variables**.
3.  Dodaj wszystkie wymagane zmienne środowiskowe, które zostały opisane w tabeli powyżej. Po dodaniu zmiennych Railway automatycznie uruchomi ponowne wdrożenie z nową konfiguracją.

### Krok 3: Skonfiguruj Cron Job

1.  W ustawieniach tej samej usługi przejdź do zakładki **Settings**.
2.  Zjedź na dół do sekcji **Cron**.
3.  W polu **Cron Schedule** wpisz harmonogram uruchamiania, używając standardowej składni crona.

**Przykładowe harmonogramy:**

* `0 2 * * *` - Uruchom skrypt **codziennie o 2:00 w nocy**.
* `0 */6 * * *` - Uruchom skrypt **co 6 godzin**.
* `0 0 * * 1` - Uruchom skrypt **w każdy poniedziałek o północy**.

Po wprowadzeniu harmonogramu Railway automatycznie zapisze ustawienia i będzie uruchamiać Twoją usługę zgodnie z podanym czasem.