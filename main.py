from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel, Field

MODEL_PATH = Path(__file__).parent / "regression.joblib"

app = FastAPI(title="Houses price prediction")
model = joblib.load(MODEL_PATH)


class House(BaseModel):
    size: float = Field(gt=0, description="Surface en m²")
    nb_rooms: int = Field(ge=0, description="Nombre de chambres")
    garden: int = Field(ge=0, le=1, description="1 si la maison a un jardin, 0 sinon")


@app.post("/predict")
def predict(house: House):
    features = pd.DataFrame([house.model_dump()])
    y_pred = model.predict(features)[0]
    return {"y_pred": float(y_pred)}
