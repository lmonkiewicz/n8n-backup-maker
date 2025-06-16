# Używamy oficjalnego obrazu Alpine z preinstalowanym Git'em jako bazy.
# Jest lekki i bezpieczny.
FROM alpine/git:latest

# Instalujemy niezbędne pakiety:
# curl - do wykonywania zapytań HTTP do API n8n
# jq   - do parsowania odpowiedzi JSON
# bash - dla pełnej kompatybilności skryptu (choć można go dostosować do sh)
RUN apk add --no-cache curl jq bash

# Ustawiamy katalog roboczy wewnątrz kontenera.
WORKDIR /app/backup

# Kopiujemy skrypt backupu do kontenera i nadajemy mu prawa do wykonania.
COPY backup_workflows.sh /usr/local/bin/backup_workflows.sh
RUN chmod +x /usr/local/bin/backup_workflows.sh

# Definiujemy domyślną komendę, która zostanie uruchomiona po starcie kontenera.
CMD ["backup_workflows.sh"]
