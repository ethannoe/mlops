from fastapi import FastAPI

app = FastAPI(title="Houses price prediction")


@app.get("/predict")
def predict():
    return {"y_pred": 2}
