#!/usr/bin/env bash
# Niveau 0.5 : copie le code sur la machine distante et lance uvicorn (sans Docker).
# Usage : ./deploy/deploy_ssh.sh <HOST> <INITIALES> <PORT> [UTILISATEUR]
# Le mot de passe SSH n'est demandé qu'une fois (connexion SSH partagée).
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage : $0 <HOST> <INITIALES> <PORT> [UTILISATEUR]" >&2
  exit 1
fi

HOST=$1
INITIALS=$2
PORT=$3
REMOTE_USER=${4:-ubuntu}
TARGET="$REMOTE_USER@$HOST"
SSH_OPTS=(-o ControlMaster=auto -o "ControlPath=/tmp/ssh-tp-%r@%h:%p" -o ControlPersist=600)

cd "$(dirname "$0")/.."

echo ">> Création du dossier ~/$INITIALS sur $HOST"
ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p ~/$INITIALS"

echo ">> Copie du code"
scp "${SSH_OPTS[@]}" houses.csv train_model.py main.py requirements.txt "$TARGET:~/$INITIALS/"

echo ">> Installation, entraînement et lancement de uvicorn sur le port $PORT"
ssh "${SSH_OPTS[@]}" "$TARGET" bash -s <<EOF
set -e
cd ~/$INITIALS
if [ -f uvicorn.pid ]; then kill \$(cat uvicorn.pid) 2>/dev/null || true; rm -f uvicorn.pid; sleep 1; fi
if ss -ltn | grep -q ":$PORT "; then echo "Le port $PORT est déjà utilisé sur la machine, choisis-en un autre."; exit 1; fi
if [ ! -d .venv ]; then
  python3 -m venv .venv || { echo "python3-venv manquant : sudo apt install -y python3-venv"; exit 1; }
fi
.venv/bin/pip install -q -r requirements.txt
.venv/bin/python train_model.py
nohup .venv/bin/uvicorn main:app --host 0.0.0.0 --port $PORT > uvicorn.log 2>&1 < /dev/null &
echo \$! > uvicorn.pid
sleep 3
curl -s -X POST localhost:$PORT/predict -H 'Content-Type: application/json' -d '{"size":150,"nb_rooms":2,"garden":1}'
echo
EOF

echo ">> Service lancé : http://$HOST:$PORT/docs"
echo ">> Test depuis ta machine : python test_api.py http://$HOST:$PORT"
