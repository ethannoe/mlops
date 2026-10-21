from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="Houses price prediction")


class House(BaseModel):
    size: float = Field(gt=0, description="Surface en m²")
    nb_rooms: int = Field(ge=0, description="Nombre de chambres")
    garden: int = Field(ge=0, le=1, description="1 si la maison a un jardin, 0 sinon")


@app.post("/predict")
def predict(house: House):
    return {"y_pred": 2}
