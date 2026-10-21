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
NAME="$INITIALS-houses-api"
SSH_OPTS=(-o ControlMaster=auto -o "ControlPath=/tmp/ssh-tp-%r@%h:%p" -o ControlPersist=120)

cd "$(dirname "$0")/.."

echo ">> Création du dossier $REMOTE_DIR sur $HOST"
ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p $REMOTE_DIR"

echo ">> Copie du code"
scp "${SSH_OPTS[@]}" Dockerfile .dockerignore houses.csv train_model.py main.py requirements.txt "$TARGET:$REMOTE_DIR/"

echo ">> docker build + docker run (port $PORT de la VM -> 8000 du conteneur)"
ssh "${SSH_OPTS[@]}" "$TARGET" bash -s <<EOF
set -e
cd $REMOTE_DIR
DOCKER=docker
docker info > /dev/null 2>&1 || DOCKER="sudo docker"
\$DOCKER build -t $NAME .
\$DOCKER rm -f $NAME > /dev/null 2>&1 || true
\$DOCKER run -d --name $NAME --restart unless-stopped -p $PORT:8000 $NAME
sleep 3
\$DOCKER ps --filter name=$NAME
curl -s -X POST localhost:$PORT/predict -H 'Content-Type: application/json' -d '{"size":150,"nb_rooms":2,"garden":1}'
echo
EOF

echo ">> Conteneur $NAME déployé : http://$HOST:$PORT/docs"
echo ">> Test depuis ta machine : python test_api.py http://$HOST:$PORT"
