"""
Data preparation for the PPD symptom-co-occurrence project.

TARGET VARIABLE — REVISED after supervisor IPR feedback (see
IPR_Remediation_Report.docx for full rationale). The raw survey has NO
validated postpartum depression diagnosis or screening score (e.g. no
EPDS). The previous version of this script built a "composite risk score"
by summing several of these same symptom columns and then used that score
as the prediction target -- since the composite was built from the same
fields used as model inputs, the model could trivially reconstruct the
label from its own features. This is target leakage, not risk prediction,
and is exactly what the supervisor flagged.

Following the remediation plan's Option A ("reframe honestly"), this
script now:
  - Uses a SINGLE existing survey field, "Feeling sad or Tearful", as the
    target. This field is NOT touched by the predictor set at all.
  - Uses the remaining 8 fields (Age + 7 other symptoms) as predictors.
  - Makes no claim that this predicts a clinical PPD diagnosis. It predicts
    self-reported low-mood symptom co-occurrence: whether someone who
    reports certain OTHER symptoms also tends to report feeling sad/
    tearful. That is an honest, non-circular, defensible ML task on this
    dataset -- it is not, and is not claimed to be, a validated clinical
    risk score.
"""

import json
from pathlib import Path

import pandas as pd

RAW_PATH = Path(__file__).resolve().parents[2] / "post natal data.csv"
OUT_DIR = Path(__file__).resolve().parents[1] / "data"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# --- 1. Load -----------------------------------------------------------
df = pd.read_csv(RAW_PATH)
n_raw = len(df)

# --- 2. Deduplicate ------------------------------------------------------
# Timestamp is a form-submission artifact, not a feature. Dedup on the
# actual answers so repeated/bot submissions don't inflate the sample.
# (Supervisor confirmed this correction is valid and should be kept.)
df = df.drop(columns=["Timestamp"]).drop_duplicates().reset_index(drop=True)
n_unique = len(df)

# --- 3. Handle missing values --------------------------------------------
for col in df.columns:
    if df[col].isna().any():
        mode_val = df[col].mode(dropna=True)[0]
        df[col] = df[col].fillna(mode_val)

# --- 4. Explicit ordinal encoding (NOT sklearn LabelEncoder-on-everything)
# Every field below has a genuine increasing-severity order justified in
# the accompanying report; nominal fields with no such order would use
# OneHotEncoder instead, but every field in this dataset is a frequency/
# severity scale (No < Sometimes/Occasionally < Yes/Often), so an explicit,
# author-defined ordinal map is used throughout, per the supervisor's own
# suggested approach.
AGE_MAP = {"25-30": 0, "30-35": 1, "35-40": 2, "40-45": 3, "45-50": 4}

TARGET_COLUMN = "Feeling sad or Tearful"
TARGET_MAP = {"No": 0, "Sometimes": 1, "Yes": 2}
TARGET_MEANING = {"0": "No", "1": "Sometimes", "2": "Yes"}

# Predictors: Age + every OTHER symptom field. "Feeling sad or Tearful" is
# excluded entirely from this set -- it is the target, not a predictor.
PREDICTOR_MAPS = {
    "Irritable towards baby & partner": {"No": 0, "Sometimes": 1, "Yes": 2},
    "Trouble sleeping at night": {"No": 0, "Yes": 1, "Two or more days a week": 2},
    "Problems concentrating or making decision": {"No": 0, "Yes": 1, "Often": 2},
    # "Not at all" and "No" both read as "no problem" in this question; see report.
    "Overeating or loss of appetite": {"Not at all": 0, "No": 0, "Yes": 2},
    "Feeling anxious": {"No": 0, "Yes": 2},
    "Feeling of guilt": {"No": 0, "Maybe": 1, "Yes": 2},
    "Problems of bonding with baby": {"No": 0, "Sometimes": 1, "Yes": 2},
    "Suicide attempt": {"No": 0, "Not interested to say": 1, "Yes": 2},
}

encoded = pd.DataFrame(index=df.index)
encoded["Age"] = df["Age"].map(AGE_MAP)
for col, mapping in PREDICTOR_MAPS.items():
    encoded[col] = df[col].map(mapping)
encoded[TARGET_COLUMN] = df[TARGET_COLUMN].map(TARGET_MAP)

assert encoded.isna().sum().sum() == 0, "Unmapped category found during encoding"

# --- 5. Save ---------------------------------------------------------------
processed_path = OUT_DIR / "processed_data.csv"
encoded.to_csv(processed_path, index=False)

feature_columns = ["Age"] + list(PREDICTOR_MAPS.keys())

metadata = {
    "n_raw_rows": n_raw,
    "n_unique_rows": n_unique,
    "n_duplicate_rows_removed": n_raw - n_unique,
    "age_map": AGE_MAP,
    "symptom_maps": PREDICTOR_MAPS,
    "target_map": TARGET_MAP,
    "feature_columns": feature_columns,
    "target_column": TARGET_COLUMN,
    "target_meaning": TARGET_MEANING,
    "class_balance": encoded[TARGET_COLUMN].value_counts().sort_index().to_dict(),
    "leakage_note": (
        "Target ('Feeling sad or Tearful') is excluded from the predictor "
        "set. No predictor is derived from the target, directly or "
        "indirectly, unlike the previous composite-score approach."
    ),
}
with open(OUT_DIR / "metadata.json", "w") as f:
    json.dump(metadata, f, indent=2, default=str)

print(f"Raw rows: {n_raw}")
print(f"Unique rows after dedup: {n_unique} ({n_raw - n_unique} duplicates removed)")
print("Missing values imputed with column mode where present.")
print(f"Target column: {TARGET_COLUMN} ({TARGET_MEANING})")
print(f"Predictors ({len(feature_columns)}): {feature_columns}")
print(f"Class balance: {metadata['class_balance']}")
print(f"Saved processed data -> {processed_path}")
print(f"Saved metadata -> {OUT_DIR / 'metadata.json'}")
