"""
Export the trained best model into a plain-JSON asset that the Flutter app
bundles and runs entirely on-device (no Python/Flask needed at runtime --
see IPR_Remediation_Report.docx, "On-device deployment" section).

Supports two model families:
  - logistic_regression: exports coefficients + intercept + scaler
    mean/scale. Dart reproduces sigmoid(coef . scaled_x + intercept).
  - random_forest: exports the full tree ensemble (every node's split
    feature/threshold/children plus its class-probability distribution).
    Dart re-implements a standard decision-tree traversal, averages class
    probabilities across all trees (exactly what
    RandomForestClassifier.predict_proba does), and derives per-instance
    feature contributions using the Saabas (2014) mean-decrease-path
    algorithm -- the accumulated change in predicted class probability
    attributable to each feature's splits along the decision path.

Whichever model src/train_models.py selected as best (models/best_model.json)
is the one exported -- so the on-device app always uses the model that
actually won the comparison, consistent with fixing the "SHAP applied to
the wrong model" feedback for prediction as well as explanation.
"""

import json
from pathlib import Path

import joblib
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
MODELS_DIR = ROOT / "models"
OUT_PATH = ROOT / "ppd_risk_app" / "assets" / "model" / "ppd_model.json"
OUT_PATH.parent.mkdir(parents=True, exist_ok=True)

with open(DATA_DIR / "metadata.json") as f:
    metadata = json.load(f)
with open(MODELS_DIR / "best_model.json") as f:
    best = json.load(f)

BEST_MODEL_NAME = best["best_model"]

FACTOR_LABELS = {
    "Age": "Age group",
    "Irritable towards baby & partner": "Irritability towards baby/partner",
    "Trouble sleeping at night": "Trouble sleeping at night",
    "Problems concentrating or making decision": "Difficulty concentrating or deciding",
    "Overeating or loss of appetite": "Appetite changes",
    "Feeling anxious": "Feeling anxious",
    "Feeling of guilt": "Feelings of guilt",
    "Problems of bonding with baby": "Difficulty bonding with baby",
    "Suicide attempt": "Thoughts of self-harm",
}

BAND_THRESHOLDS = {"happy": 0.2, "ok": 0.4, "sad": 0.6, "tearful": 0.8}
BAND_LABELS = ["Happy", "OK", "Sad", "Tearful", "Extreme - consult immediately"]

common = {
    "model_type": BEST_MODEL_NAME,
    "feature_order": metadata["feature_columns"],
    "age_map": metadata["age_map"],
    "symptom_maps": metadata["symptom_maps"],
    "factor_labels": FACTOR_LABELS,
    "class_values": [0, 1, 2],
    "band_thresholds": BAND_THRESHOLDS,
    "band_labels": BAND_LABELS,
    "disclaimer": (
        "This is a research prototype, not a diagnostic tool. "
        "If you are concerned about your wellbeing or safety, please contact a "
        "healthcare professional or local emergency/crisis service."
    ),
}


def export_logistic_regression():
    model = joblib.load(MODELS_DIR / "logistic_regression.joblib")
    classifier = model.named_steps["classifier"] if hasattr(model, "named_steps") else model
    scaler = model.named_steps["scaler"] if hasattr(model, "named_steps") else joblib.load(
        MODELS_DIR / "scaler.joblib"
    )
    return {
        **common,
        "scaler_mean": scaler.mean_.tolist(),
        "scaler_scale": scaler.scale_.tolist(),
        # coef_ shape is (n_classes, n_features) for multinomial LR
        "coefficients": classifier.coef_.tolist(),
        "intercept": classifier.intercept_.tolist(),
    }


def export_random_forest():
    model = joblib.load(MODELS_DIR / "random_forest.joblib")
    trees = []
    for estimator in model.estimators_:
        t = estimator.tree_
        value = t.value[:, 0, :]  # (n_nodes, n_classes) raw sample counts
        value = value / value.sum(axis=1, keepdims=True)  # normalise to probabilities
        trees.append(
            {
                "feature": t.feature.tolist(),
                "threshold": np.round(t.threshold, 6).tolist(),
                "children_left": t.children_left.tolist(),
                "children_right": t.children_right.tolist(),
                "value": np.round(value, 6).tolist(),
            }
        )
    return {**common, "n_estimators": len(trees), "trees": trees}


if BEST_MODEL_NAME == "logistic_regression":
    export = export_logistic_regression()
elif BEST_MODEL_NAME == "random_forest":
    export = export_random_forest()
else:
    raise SystemExit(
        f"export_model.py has no exporter implemented for '{BEST_MODEL_NAME}'. "
        "Add one (logistic_regression and random_forest are supported) or "
        "retrain so a supported model wins."
    )

with open(OUT_PATH, "w") as f:
    json.dump(export, f)

size_kb = OUT_PATH.stat().st_size / 1024
print(f"Exported on-device model ({BEST_MODEL_NAME}) -> {OUT_PATH} ({size_kb:.0f} KB)")
print(f"Features ({len(export['feature_order'])}): {export['feature_order']}")
if BEST_MODEL_NAME == "random_forest":
    print(f"Trees: {export['n_estimators']}, total nodes: {sum(len(t['feature']) for t in export['trees'])}")
