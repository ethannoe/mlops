import joblib
import pandas as pd
import streamlit as st


@st.cache_resource
def load_model():
    return joblib.load("regression.joblib")


model = load_model()

st.title("Prédiction du prix d'une maison")

size = st.number_input("Taille (m²)", min_value=0.0, value=150.0, step=1.0)
nb_rooms = st.number_input("Nombre de chambres", min_value=0, value=2, step=1)
garden = st.number_input("Jardin (1 = oui, 0 = non)", min_value=0, max_value=1, value=1, step=1)

features = pd.DataFrame([{"size": size, "nb_rooms": nb_rooms, "garden": garden}])
y_pred = model.predict(features)[0]

st.write(f"Prix estimé : **{y_pred:,.0f} €**".replace(",", " "))
