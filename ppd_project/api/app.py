"""
Flask API for the PPD risk prototype, backed by MongoDB.

Endpoints
---------
GET  /schema             -> question labels + allowed answer options
POST /predict             -> stateless risk prediction + SHAP explanation (no auth)
GET  /health              -> liveness check

POST /auth/register       -> {name, email, password} -> {token, name, email}
POST /auth/login          -> {email, password} -> {token, name, email}
POST /auth/logout         -> (Bearer token) invalidates the session
GET  /me                  -> (Bearer token) current user info

POST /assessments/save    -> (Bearer token) persist a completed check-in
GET  /assessments         -> (Bearer token) this user's check-in history
PATCH /assessments/<id>/note -> (Bearer token) attach/update a private note

GET  /insights             -> anonymized, aggregated stats across all users (no auth)
"""

import json
import secrets
import sys
from datetime import datetime, timezone
from functools import wraps
from pathlib import Path

from bson import ObjectId
from bson.errors import InvalidId
from flask import Flask, g, jsonify, request
from flask_cors import CORS
from werkzeug.security import check_password_hash, generate_password_hash

import db

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from explain import FEATURES, explain_instance, load_explainer  # noqa: E402

with open(ROOT / "data" / "metadata.json") as f:
    METADATA = json.load(f)

AGE_MAP = METADATA["age_map"]
SYMPTOM_MAPS = METADATA["symptom_maps"]

# NOTE ON FIELD NAMES: the JSON/DB field names "risk_probability" and
# "risk_band" are historical (kept to avoid renaming across the whole
# Flutter app + MongoDB documents). Semantically they now hold the 0-1
# "severity_score" and one of the 5 mood bands (Happy/OK/Sad/Tearful/
# Extreme) computed in src/explain.py -- see IPR_Remediation_Report.docx.
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

app = Flask(__name__)
CORS(app)

_model, _scaler, _explainer = load_explainer()


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/schema")
def schema():
    return jsonify(
        {
            "age": {"label": "Age group", "options": list(AGE_MAP.keys())},
            "symptoms": [
                {"key": key, "label": FACTOR_LABELS.get(key, key), "options": list(opts.keys())}
                for key, opts in SYMPTOM_MAPS.items()
            ],
            "disclaimer": (
                "This is a research prototype, not a diagnostic tool. "
                "If you are concerned about your wellbeing or safety, please contact a "
                "healthcare professional or local emergency/crisis service."
            ),
        }
    )


@app.post("/predict")
def predict():
    payload = request.get_json(force=True)
    if not payload:
        return jsonify({"error": "JSON body required"}), 400

    try:
        encoded = {"Age": AGE_MAP[payload["Age"]]}
        for key, opts in SYMPTOM_MAPS.items():
            encoded[key] = opts[payload[key]]
    except KeyError as e:
        return jsonify({"error": f"Missing or invalid field: {e}"}), 400

    result = explain_instance(encoded, model=_model, scaler=_scaler, explainer=_explainer, top_n=3)
    score = result["severity_score"]

    factors = []
    for f in result["top_factors"]:
        direction = "increases" if f["contribution"] > 0 else "decreases"
        factors.append(
            {
                "factor": FACTOR_LABELS.get(f["feature"], f["feature"]),
                "direction": direction,
                "magnitude": abs(f["contribution"]),
            }
        )

    return jsonify(
        {
            "risk_probability": score,
            "risk_band": result["band"],
            "top_factors": factors,
            "disclaimer": (
                "This is a research prototype, not a diagnostic tool. "
                "If you are concerned about your wellbeing or safety, please contact a "
                "healthcare professional or local emergency/crisis service."
            ),
        }
    )


def _serialize_user(user: dict) -> dict:
    return {"name": user["name"], "email": user["email"]}


def _serialize_assessment(a: dict) -> dict:
    return {
        "id": str(a["_id"]),
        "timestamp": a["timestamp"].isoformat(),
        "risk_probability": a["risk_probability"],
        "risk_band": a["risk_band"],
        "top_factors": a["top_factors"],
        "note": a.get("note", ""),
    }


def require_auth(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify({"error": "Missing bearer token"}), 401
        token = header.removeprefix("Bearer ").strip()
        session = db.sessions.find_one({"token": token})
        if not session:
            return jsonify({"error": "Invalid or expired session"}), 401
        user = db.users.find_one({"_id": session["user_id"]})
        if not user:
            return jsonify({"error": "User not found"}), 401
        g.user = user
        return view(*args, **kwargs)

    return wrapped


def _create_session(user_id) -> str:
    token = secrets.token_hex(24)
    db.sessions.insert_one(
        {"token": token, "user_id": user_id, "created_at": datetime.now(timezone.utc)}
    )
    return token


@app.post("/auth/register")
def register():
    payload = request.get_json(force=True) or {}
    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""

    if not name or "@" not in email or len(password) < 4:
        return jsonify({"error": "Provide a valid name, email, and password (4+ chars)"}), 400

    if db.users.find_one({"email": email}):
        return jsonify({"error": "An account with this email already exists"}), 409

    user_doc = {
        "name": name,
        "email": email,
        "password_hash": generate_password_hash(password),
        "created_at": datetime.now(timezone.utc),
    }
    result = db.users.insert_one(user_doc)
    token = _create_session(result.inserted_id)
    return jsonify({"token": token, **_serialize_user(user_doc)})


@app.post("/auth/login")
def login():
    payload = request.get_json(force=True) or {}
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""

    user = db.users.find_one({"email": email})
    if not user or not check_password_hash(user["password_hash"], password):
        return jsonify({"error": "Incorrect email or password"}), 401

    token = _create_session(user["_id"])
    return jsonify({"token": token, **_serialize_user(user)})


@app.post("/auth/logout")
@require_auth
def logout():
    header = request.headers.get("Authorization", "")
    token = header.removeprefix("Bearer ").strip()
    db.sessions.delete_one({"token": token})
    return jsonify({"status": "ok"})


@app.get("/me")
@require_auth
def me():
    return jsonify(_serialize_user(g.user))


@app.patch("/me")
@require_auth
def update_me():
    payload = request.get_json(force=True) or {}
    name = (payload.get("name") or "").strip()
    if not name:
        return jsonify({"error": "Name cannot be empty"}), 400
    db.users.update_one({"_id": g.user["_id"]}, {"$set": {"name": name}})
    return jsonify({"name": name, "email": g.user["email"]})


@app.post("/assessments/save")
@require_auth
def save_assessment():
    payload = request.get_json(force=True) or {}
    required = {"risk_probability", "risk_band", "top_factors"}
    if not required.issubset(payload):
        return jsonify({"error": f"Body must include {required}"}), 400

    doc = {
        "user_id": g.user["_id"],
        "timestamp": datetime.now(timezone.utc),
        "risk_probability": payload["risk_probability"],
        "risk_band": payload["risk_band"],
        "top_factors": payload["top_factors"],
        "note": (payload.get("note") or "").strip(),
    }
    result = db.assessments.insert_one(doc)
    doc["_id"] = result.inserted_id
    return jsonify(_serialize_assessment(doc))


@app.get("/assessments")
@require_auth
def get_assessments():
    docs = db.assessments.find({"user_id": g.user["_id"]}).sort("timestamp", -1)
    return jsonify([_serialize_assessment(d) for d in docs])


@app.patch("/assessments/<assessment_id>/note")
@require_auth
def update_note(assessment_id):
    payload = request.get_json(force=True) or {}
    note = (payload.get("note") or "").strip()
    try:
        oid = ObjectId(assessment_id)
    except InvalidId:
        return jsonify({"error": "Invalid assessment id"}), 400

    result = db.assessments.update_one(
        {"_id": oid, "user_id": g.user["_id"]}, {"$set": {"note": note}}
    )
    if result.matched_count == 0:
        return jsonify({"error": "Assessment not found"}), 404
    return jsonify({"status": "ok", "note": note})


@app.get("/insights")
def insights():
    total = db.assessments.count_documents({})
    if total == 0:
        return jsonify({"total_checkins": 0, "band_distribution": {}, "top_factors": []})

    band_pipeline = [{"$group": {"_id": "$risk_band", "count": {"$sum": 1}}}]
    band_counts = {row["_id"]: row["count"] for row in db.assessments.aggregate(band_pipeline)}
    band_distribution = {
        band: round(count / total * 100, 1) for band, count in band_counts.items()
    }

    factor_pipeline = [
        {"$unwind": "$top_factors"},
        {
            "$group": {
                "_id": {"factor": "$top_factors.factor", "direction": "$top_factors.direction"},
                "count": {"$sum": 1},
            }
        },
        {"$sort": {"count": -1}},
        {"$limit": 5},
    ]
    top_factors = [
        {
            "factor": row["_id"]["factor"],
            "direction": row["_id"]["direction"],
            "count": row["count"],
        }
        for row in db.assessments.aggregate(factor_pipeline)
    ]

    return jsonify(
        {
            "total_checkins": total,
            "band_distribution": band_distribution,
            "top_factors": top_factors,
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
