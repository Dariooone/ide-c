#!/bin/zsh
# Carica le modifiche sulla repo privata di GitHub.
# I dati di git stanno fuori dal vault (in ~/Documents/Progetti/ide-c.git), così Syncthing non li copia sul server.
# Uso: ./pubblica.sh "cosa ho cambiato"
set -e
export GIT_DIR="$HOME/Documents/Progetti/ide-c.git"
export GIT_WORK_TREE="${0:A:h}"
git add -A
git commit -q -m "${1:-Aggiornamento}" && echo "Salvato: ${1:-Aggiornamento}" || echo "Niente di nuovo da salvare."
git push -q && echo "Caricato su GitHub."
