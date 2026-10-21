# MLOps : mettre un modèle de prix de maisons en production

Une régression linéaire (`size`, `nb_rooms`, `garden` → `price`) servie de trois façons :
une app Streamlit, une API FastAPI, et la même API dans un conteneur Docker sur une VM.

| Fichier | Rôle |
|---|---|
| `houses.csv`, `train_model.py` | Données et script d'entraînement fournis (génèrent `regression.joblib`) |
| `model_app.py` | Partie 3 : app Streamlit |
| `main.py` | Partie 4 : service web FastAPI, `POST /predict` |
| `test_api.py` | Client de test avec `requests` |
| `Dockerfile` | Niveau 1 : image du service web |
| `deploy/deploy_ssh.sh` | Niveau 0.5 : déploiement sur la machine distante sans Docker |
| `deploy/deploy_docker.sh` | Niveau 2 : déploiement du conteneur sur la VM |

L'historique git suit les étapes du TP (un commit par étape).

## Déploiement en ligne

Le conteneur tourne sur la VM `40.66.48.24`, dans `/home/ubuntu/ENA` :

- Swagger : http://40.66.48.24:8878/docs
- Prédiction : `POST http://40.66.48.24:8878/predict`

Le pare-feu de la VM ne laisse passer que les ports en 8xxx (le 9878 est bloqué depuis l'extérieur).

## Installation

```bash
pip install -r requirements-dev.txt
python train_model.py        # crée regression.joblib
```

## Partie 3 : Streamlit

```bash
streamlit run model_app.py
```

Trois champs `st.number_input` (taille, chambres, jardin) ; la prédiction s'affiche avec `st.write`.

## Niveau 0 : service web en local

```bash
uvicorn main:app --reload
```

`POST /predict` avec un corps JSON :

```json
{"size": 150, "nb_rooms": 2, "garden": 1}
```

réponse :

```json
{"y_pred": 274656.05}
```

Pour tester :

- **Navigateur** : `http://localhost:8000/docs` (Swagger, bouton *Try it out*). Le `GET /predict` de l'étape 1 renvoyait `{"y_pred": 2}` (voir le commit « Niveau 0.1 »).
- **Postman / Insomnia** : `POST http://localhost:8000/predict`, Body → raw → JSON, avec le JSON ci-dessus.
- **requests** : `python test_api.py`
- **curl** :
  ```bash
  curl -X POST localhost:8000/predict -H 'Content-Type: application/json' -d '{"size":150,"nb_rooms":2,"garden":1}'
  ```

Le corps est validé par Pydantic : une feature manquante ou `garden` différent de 0 ou 1 renvoie une erreur 422.

## Niveau 0.5 : sur la machine distante (sans Docker)

```bash
./deploy/deploy_ssh.sh <IP> <initiales> <port>     # ex. ./deploy/deploy_ssh.sh 1.2.3.4 td 8042
```

Le script crée `~/<initiales>`, y copie le code avec `scp`, crée un venv, entraîne le modèle,
puis lance `uvicorn --host 0.0.0.0 --port <port>` en arrière-plan. Le mot de passe SSH est demandé une seule fois.
Choisis un port que les autres stagiaires n'utilisent pas.

Pour faire la même chose à la main :

```bash
ssh ubuntu@<IP> "mkdir -p ~/td"
scp houses.csv train_model.py main.py requirements.txt ubuntu@<IP>:~/td/
ssh ubuntu@<IP>
cd ~/td && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python train_model.py
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8042
```

Vérification, depuis ta machine ou celle d'un collègue : `python test_api.py http://<IP>:8042`

## Niveau 1 : Docker en local

```bash
docker build -t houses-api .
docker run -d --name houses-api -p 8000:8000 houses-api
python test_api.py http://localhost:8000
```

Le modèle est entraîné pendant le `docker build`, donc la version de scikit-learn est la même à l'entraînement et à la prédiction.

## Niveau 2 : conteneur sur la VM cloud

```bash
./deploy/deploy_docker.sh <IP> <initiales> <port>
```

Le script copie le code dans `/home/ubuntu/<initiales>`, lance `docker build`, puis
`docker run -d --restart unless-stopped -p <port>:8000`. Le conteneur s'appelle `<initiales en minuscules>-houses-api`
(Docker refuse les majuscules dans les noms d'image). Il remplace le uvicorn du niveau 0.5 s'il tournait dans le même dossier.

Vérification : `python test_api.py http://<IP>:<port>`, ou `http://<IP>:<port>/docs` dans le navigateur.
Si le port ne répond pas depuis l'extérieur, il est sans doute bloqué par le pare-feu ou le security group de la VM.
