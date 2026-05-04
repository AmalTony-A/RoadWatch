from __future__ import annotations

from typing import Any

import numpy as np

from app.db.repository import DataRepository

try:
    from sklearn.ensemble import RandomForestClassifier
except Exception:  # pragma: no cover
    RandomForestClassifier = None


class RiskPredictionService:
    def __init__(self, repository: DataRepository):
        self.repository = repository
        self.model = None
        self._fit_model()

    def _fit_model(self):
        if RandomForestClassifier is None:
            return

        rows = self.repository.get_risk_training_data()
        if not rows:
            return

        x = np.array(
            [
                [r["weather_index"], r["traffic_index"], r["complaint_count_30d"]]
                for r in rows
            ],
            dtype=float,
        )
        y = np.array([r["deteriorated"] for r in rows], dtype=int)

        model = RandomForestClassifier(n_estimators=120, random_state=42, max_depth=5)
        model.fit(x, y)
        self.model = model

    def predict(
        self,
        road_id: str,
        weather_index: float,
        traffic_index: float,
        complaint_count_30d: int,
    ) -> dict[str, Any]:
        if self.model is not None:
            features = np.array([[weather_index, traffic_index, complaint_count_30d]], dtype=float)
            probability = float(self.model.predict_proba(features)[0][1])
        else:
            probability = min(
                0.98,
                max(
                    0.02,
                    0.36 * weather_index
                    + 0.39 * traffic_index
                    + 0.025 * complaint_count_30d,
                ),
            )

        if probability >= 0.75:
            risk_level = "High"
            days = 14
        elif probability >= 0.45:
            risk_level = "Medium"
            days = 28
        else:
            risk_level = "Low"
            days = 45

        return {
            "road_id": road_id,
            "risk_level": risk_level,
            "probability_of_deterioration": round(probability, 2),
            "predicted_days_to_decline": days,
        }
