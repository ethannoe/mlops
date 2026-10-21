#!/usr/bin/env bash
# Niveau 2 : copie le code dans /home/<UTILISATEUR>/<INITIALES> sur la VM, build l'image et lance le conteneur.
# Usage : ./deploy/deploy_docker.sh <HOST> <INITIALES> <PORT> [UTILISATEUR]
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
REMOTE_DIR="/home/$REMOTE_USER/$INITIALS"
# Docker n'accepte que des minuscules dans les noms d'image
NAME="$(echo "$INITIALS" | tr "[:upper:]" "[:lower:]")-houses-api"
SSH_OPTS=(-o ConnectTimeout=15 -o ControlMaster=auto -o "ControlPath=/tmp/ssh-tp-%r@%h:%p" -o ControlPersist=600)

cd "$(dirname "$0")/.."

echo ">> Création du dossier $REMOTE_DIR sur $HOST"
ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p $REMOTE_DIR"

echo ">> Copie du code"
scp "${SSH_OPTS[@]}" Dockerfile .dockerignore houses.csv train_model.py main.py requirements.txt "$TARGET:$REMOTE_DIR/"

echo ">> docker build + docker run (port $PORT de la VM -> 8000 du conteneur)"
ssh "${SSH_OPTS[@]}" "$TARGET" bash -s <<EOF
set -e
cd $REMOTE_DIR
command -v docker > /dev/null || { echo "Docker n'est pas installé sur la VM."; exit 1; }
DOCKER=docker
docker info > /dev/null 2>&1 || DOCKER="sudo docker"
# Remplace un déploiement précédent : ancien conteneur, ou uvicorn du niveau 0.5 sur le même port
\$DOCKER rm -f $NAME > /dev/null 2>&1 || true
if [ -f uvicorn.pid ]; then kill \$(cat uvicorn.pid) 2>/dev/null || true; rm -f uvicorn.pid; sleep 1; fi
if ss -ltn | grep -q ":$PORT "; then echo "Le port $PORT est déjà utilisé sur la VM, choisis-en un autre."; exit 1; fi
\$DOCKER build -t $NAME .
\$DOCKER run -d --name $NAME --restart unless-stopped -p $PORT:8000 $NAME
\$DOCKER ps --filter name=$NAME
# Le premier démarrage peut être lent (import de pandas/scikit-learn) : on attend jusqu'à 60 s
for i in \$(seq 1 60); do
  curl -sf -X POST localhost:$PORT/predict -H 'Content-Type: application/json' -d '{"size":150,"nb_rooms":2,"garden":1}' && break
  sleep 1
done
echo
EOF

echo ">> Conteneur $NAME déployé : http://$HOST:$PORT/docs"
echo ">> Test depuis ta machine : python test_api.py http://$HOST:$PORT"
