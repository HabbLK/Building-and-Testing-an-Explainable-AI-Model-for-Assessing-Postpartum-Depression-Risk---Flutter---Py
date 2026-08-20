"""
Train and compare 3 models on the corrected, non-leaky target
("Feeling sad or Tearful", predicted from the OTHER 8 fields only).

For each model this script reports BOTH an untuned baseline (default
hyperparameters) and a GridSearchCV-tuned version (search run on the
training fold only, 5-fold CV), so the effect of tuning is itself visible
and honestly reported -- per supervisor feedback that comparing only
default-parameter models is not a real model comparison.

Preprocessing (StandardScaler for Logistic Regression) is placed inside an
sklearn Pipeline so it is re-fit on each training fold during
cross-validation, not fit once on the whole training set beforehand.
"""

import json
from pathlib import Path

import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GridSearchCV, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
MODELS_DIR = ROOT / "models"
REPORTS_DIR = ROOT / "reports"
MODELS_DIR.mkdir(exist_ok=True)
REPORTS_DIR.mkdir(exist_ok=True)

with open(DATA_DIR / "metadata.json") as f:
    metadata = json.load(f)

FEATURES = metadata["feature_columns"]
TARGET = metadata["target_column"]
CLASS_NAMES = [metadata["target_meaning"][str(c)] for c in range(3)]

df = pd.read_csv(DATA_DIR / "processed_data.csv")
X = df[FEATURES]
y = df[TARGET]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# --- Model + hyperparameter grid definitions --------------------------------
MODEL_SPECS = {
    "logistic_regression": {
        "estimator": Pipeline(
            [
                ("scaler", StandardScaler()),
                ("classifier", LogisticRegression(max_iter=2000, random_state=42)),
            ]
        ),
        "param_grid": {
            "classifier__C": [0.01, 0.1, 1, 10],
            "classifier__penalty": ["l2"],
        },
    },
    "random_forest": {
        "estimator": RandomForestClassifier(random_state=42),
        "param_grid": {
            "n_estimators": [100, 200, 300],
            "max_depth": [None, 5, 10],
            "min_samples_leaf": [1, 3, 5],
        },
    },
    "xgboost": {
        "estimator": XGBClassifier(
            objective="multi:softprob", num_class=3, eval_metric="mlogloss", random_state=42
        ),
        "param_grid": {
            "n_estimators": [100, 200],
            "max_depth": [3, 5],
            "learning_rate": [0.05, 0.1, 0.2],
        },
    },
}


def evaluate(model, X_te, y_te) -> dict:
    y_pred = model.predict(X_te)
    y_proba = model.predict_proba(X_te)
    return {
        "accuracy": accuracy_score(y_te, y_pred),
        "precision_weighted": precision_score(y_te, y_pred, average="weighted", zero_division=0),
        "recall_weighted": recall_score(y_te, y_pred, average="weighted", zero_division=0),
        "f1_weighted": f1_score(y_te, y_pred, average="weighted", zero_division=0),
        "roc_auc_ovr_weighted": roc_auc_score(y_te, y_proba, multi_class="ovr", average="weighted"),
    }


results = []
fitted_models = {}

for name, spec in MODEL_SPECS.items():
    # 1. Untuned baseline (default hyperparameters)
    baseline = spec["estimator"]
    baseline.fit(X_train, y_train)
    baseline_metrics = evaluate(baseline, X_test, y_test)
    results.append({"model": name, "variant": "untuned_baseline", "params": "default", **baseline_metrics})

    # 2. GridSearchCV-tuned version (search on training fold only)
    grid = GridSearchCV(
        spec["estimator"], spec["param_grid"], cv=5, scoring="f1_weighted", n_jobs=-1
    )
    grid.fit(X_train, y_train)
    tuned_metrics = evaluate(grid.best_estimator_, X_test, y_test)
    results.append(
        {"model": name, "variant": "tuned_gridsearchcv", "params": json.dumps(grid.best_params_), **tuned_metrics}
    )
    fitted_models[name] = grid.best_estimator_

    cm_fig, cm_ax = plt.subplots(figsize=(5, 4))
    ConfusionMatrixDisplay.from_estimator(
        grid.best_estimator_, X_test, y_test, display_labels=CLASS_NAMES, ax=cm_ax, colorbar=False
    )
    cm_ax.set_title(f"Confusion Matrix (tuned) - {name}")
    cm_fig.tight_layout()
    cm_fig.savefig(REPORTS_DIR / f"confusion_matrix_{name}.png", dpi=150)
    plt.close(cm_fig)

    joblib.dump(grid.best_estimator_, MODELS_DIR / f"{name}.joblib")

results_df = pd.DataFrame(results)
results_df.to_csv(REPORTS_DIR / "model_comparison.csv", index=False)

# --- Bar chart comparing tuned models on weighted F1 and ROC-AUC ------------
tuned_only = results_df[results_df["variant"] == "tuned_gridsearchcv"].set_index("model")
fig, ax = plt.subplots(figsize=(7, 5))
tuned_only[["accuracy", "f1_weighted", "roc_auc_ovr_weighted"]].plot(kind="bar", ax=ax)
ax.set_title("Tuned model comparison")
ax.set_ylabel("Score")
ax.set_xticklabels(tuned_only.index, rotation=0)
fig.tight_layout()
fig.savefig(REPORTS_DIR / "model_comparison_bar.png", dpi=150)
plt.close(fig)

best_row = tuned_only.sort_values("f1_weighted", ascending=False).iloc[0]
best_model_name = best_row.name

with open(MODELS_DIR / "best_model.json", "w") as f:
    json.dump(
        {
            "best_model": best_model_name,
            "uses_scaler": best_model_name == "logistic_regression",
            "selection_metric": "f1_weighted (tuned)",
            "class_names": CLASS_NAMES,
        },
        f,
        indent=2,
    )

print(f"Train size: {len(X_train)}, Test size: {len(X_test)}")
print()
print(results_df.to_string(index=False))
print()
print(f"Best model by tuned weighted F1: {best_model_name} (F1={best_row['f1_weighted']:.3f})")
print(f"Saved models -> {MODELS_DIR}")
print(f"Saved reports -> {REPORTS_DIR}")
