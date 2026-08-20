"""
SHAP explainability for the ACTUAL best model selected in train_models.py
(previously the report explained Random Forest by default regardless of
which model scored best -- supervisor feedback item 5. This script reads
models/best_model.json and explains whichever model actually won).

Target is 3-class ("Feeling sad or Tearful": No/Sometimes/Yes). Predictions
are summarised as a single continuous 0-1 "expected symptom severity"
score -- the probability-weighted average of the ordinal class values
(0=No, 1=Sometimes, 2=Yes), normalised by the max class index -- which is
then mapped to one of 5 descriptive bands (see BAND_THRESHOLDS below).
This is NOT a validated clinical severity scale; it is a transparent,
author-defined presentation convenience for a continuous score, consistent
with the project's honest reframing (see IPR_Remediation_Report.docx).
"""

import json
from pathlib import Path

import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import shap

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
MODELS_DIR = ROOT / "models"
REPORTS_DIR = ROOT / "reports"

with open(DATA_DIR / "metadata.json") as f:
    METADATA = json.load(f)
with open(MODELS_DIR / "best_model.json") as f:
    BEST = json.load(f)

FEATURES = METADATA["feature_columns"]
N_CLASSES = 3
CLASS_VALUES = np.array([0, 1, 2])  # No / Sometimes / Yes, ordinal
BEST_MODEL_NAME = BEST["best_model"]
USES_SCALER = BEST["uses_scaler"]

# --- 5-band mood scale (as specified by the project author) ----------------
BAND_THRESHOLDS = [0.2, 0.4, 0.6, 0.8]
BAND_LABELS = [
    "Happy",
    "OK",
    "Sad",
    "Tearful",
    "Extreme - consult immediately",
]


def band_for(score: float) -> str:
    for threshold, label in zip(BAND_THRESHOLDS, BAND_LABELS):
        if score < threshold:
            return label
    return BAND_LABELS[-1]


def severity_score(proba_3class) -> float:
    """Probability-weighted expected class value, normalised to 0-1."""
    return float(np.dot(proba_3class, CLASS_VALUES) / CLASS_VALUES.max())


def load_explainer():
    model = joblib.load(MODELS_DIR / f"{BEST_MODEL_NAME}.joblib")
    scaler = joblib.load(MODELS_DIR / "scaler.joblib") if USES_SCALER else None
    df = pd.read_csv(DATA_DIR / "processed_data.csv")
    background = df[FEATURES].sample(n=min(100, len(df)), random_state=42)
    background_for_model = scaler.transform(background) if USES_SCALER else background
    # Passing the model object (not model.predict_proba) lets SHAP auto-select
    # TreeExplainer for tree-based models -- exact and millisecond-fast,
    # instead of falling back to a slow model-agnostic permutation explainer.
    explainer = shap.Explainer(model, background_for_model, feature_names=FEATURES)
    return model, scaler, explainer


def explain_instance(feature_dict: dict, model=None, scaler=None, explainer=None, top_n=3):
    """feature_dict: {feature_name: ordinal_value}. Returns the 0-1 severity
    score, its band label, and the top contributing factors toward that
    score as [{"feature": str, "contribution": float}, ...]."""
    if explainer is None:
        model, scaler, explainer = load_explainer()

    row = pd.DataFrame([[feature_dict[f] for f in FEATURES]], columns=FEATURES)
    row_for_model = scaler.transform(row) if scaler is not None else row

    proba = model.predict_proba(row_for_model)[0]
    score = severity_score(proba)

    sv = explainer(row_for_model)
    values = sv.values[0]  # shape (n_features, n_classes) for multiclass
    if values.ndim == 1:  # binary/regression fallback
        severity_contrib = values
    else:
        # Combine per-class SHAP contributions using the same ordinal
        # weights used for the severity score itself, so "why did the
        # score move" stays consistent with "what is the score."
        severity_contrib = values @ CLASS_VALUES / CLASS_VALUES.max()

    contributions = list(zip(FEATURES, severity_contrib.tolist()))
    contributions.sort(key=lambda x: abs(x[1]), reverse=True)
    top = [{"feature": f, "contribution": round(v, 4)} for f, v in contributions[:top_n]]

    return {
        "severity_score": round(score, 4),
        "band": band_for(score),
        "top_factors": top,
    }


if __name__ == "__main__":
    model, scaler, explainer = load_explainer()
    df = pd.read_csv(DATA_DIR / "processed_data.csv")
    X = df[FEATURES]
    X_for_model = scaler.transform(X) if scaler is not None else X

    sv = explainer(X_for_model)
    values = sv.values
    if values.ndim == 3:
        severity_values = values @ CLASS_VALUES / CLASS_VALUES.max()
    else:
        severity_values = values

    plt.figure(figsize=(8, 6))
    shap.summary_plot(severity_values, X, feature_names=FEATURES, show=False, plot_type="bar")
    plt.title(f"Global Feature Importance toward Severity Score - {BEST_MODEL_NAME}")
    plt.tight_layout()
    plt.savefig(REPORTS_DIR / "shap_global_importance.png", dpi=150)
    plt.close()

    plt.figure(figsize=(8, 6))
    shap.summary_plot(severity_values, X, feature_names=FEATURES, show=False)
    plt.title(f"SHAP Summary (toward severity score) - {BEST_MODEL_NAME}")
    plt.tight_layout()
    plt.savefig(REPORTS_DIR / "shap_summary_beeswarm.png", dpi=150)
    plt.close()

    print(f"Explained model (the ACTUAL best model, not automatically Random Forest): {BEST_MODEL_NAME}")
    print("Saved global SHAP plots -> reports/shap_global_importance.png, reports/shap_summary_beeswarm.png")

    sample = {f: int(X.iloc[0][f]) for f in FEATURES}
    result = explain_instance(sample, model=model, scaler=scaler, explainer=explainer)
    print("\nExample single-instance explanation:")
    print(json.dumps(result, indent=2))
