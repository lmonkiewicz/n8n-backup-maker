# Używamy lekkiego i standardowego obrazu Alpine jako bazy.
FROM alpine:latest

# Instalujemy niezbędne pakiety:
# git  - do operacji na repozytorium (teraz instalowany ręcznie)
# curl - do wykonywania zapytań HTTP do API n8n
# jq   - do parsowania odpowiedzi JSON
# bash - dla pełnej kompatybilności skryptu
RUN apk add --no-cache git curl jq bash

# Ustawiamy katalog roboczy wewnątrz kontenera.
WORKDIR /app/backup

# Kopiujemy skrypt backupu do kontenera i nadajemy mu prawa do wykonania.
COPY backup_workflows.sh /usr/local/bin/backup_workflows.sh
RUN chmod +x /usr/local/bin/backup_workflows.sh

# Definiujemy domyślną komendę, która zostanie uruchomiona po starcie kontenera.
# Obraz bazowy `alpine` uruchomi tę komendę bezpośrednio w domyślnej powłoce.
CMD ["backup_workflows.sh"]
