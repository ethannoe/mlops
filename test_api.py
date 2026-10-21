"""Teste le service web avec la bibliothèque requests.

Usage :
    python test_api.py                          # http://localhost:8000
    python test_api.py http://IP_DE_LA_VM:8042  # serveur distant
"""
import sys

import requests

BASE_URL = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://localhost:8000"

houses = [
    {"size": 150, "nb_rooms": 2, "garden": 1},
    {"size": 80, "nb_rooms": 1, "garden": 0},
    {"size": 220, "nb_rooms": 3, "garden": 1},
]

for house in houses:
    response = requests.post(f"{BASE_URL}/predict", json=house, timeout=10)
    response.raise_for_status()
    print(f"{house} -> {response.json()}")
