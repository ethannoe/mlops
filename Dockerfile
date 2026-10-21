FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY houses.csv train_model.py main.py ./
# Entraîne le modèle dans l'image : même version de scikit-learn à l'entraînement et à la prédiction
RUN python train_model.py

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
