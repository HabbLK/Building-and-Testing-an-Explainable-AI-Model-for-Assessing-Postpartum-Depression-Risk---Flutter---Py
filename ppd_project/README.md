# Explainable ML Prototype for Postpartum Depression (PPD) Risk Estimation

> **⚠ Superseded target variable — read `IPR_Remediation_Report.docx` (project
> root, one level up) first.** After supervisor IPR feedback identified target
> leakage in the composite-score approach described below, the target was
> redefined: the model now predicts a single existing field ("Feeling sad or
> Tearful") from the other 8 fields, with zero leakage, and Random Forest
> (not Logistic Regression) is the selected/deployed model. Most of this
> README predates that fix and describes the retired approach for historical
> context; the docx report is the current, authoritative description of the
> pipeline, the 3-model comparison, and the 5-band mood-scale output.

Implementation of the pipeline described in *"Design and Evaluation of an
Explainable Machine Learning Prototype for Postpartum Depression Risk
Estimation"* (DPP, 7COM1040): data preparation → model comparison (Logistic
Regression / Random Forest / XGBoost) → SHAP explainability → Flask + MongoDB
API → Flutter mobile prototype.

```
ppd_project/
├── data/                    processed_data.csv, metadata.json (encoding + target rules)
├── src/
│   ├── data_prep.py         cleaning, encoding, target derivation
│   ├── train_models.py      trains & compares the 3 models
│   └── explain.py           SHAP global + per-instance explanations
├── models/                  saved .joblib models, scaler, best_model.json
├── reports/                 confusion matrices, ROC curves, SHAP plots, model_comparison.csv
├── .env                     MongoDB connection string (NOT committed — see Security section)
├── api/
│   ├── app.py                Flask API: prediction + auth + history + community insights
│   └── db.py                 MongoDB connection, collections, indexes
└── ppd_risk_app/             Flutter mobile prototype (Android/iOS/Web), 12 screens:
    lib/
    ├── screens/
    │   ├── splash_screen.dart        1. Splash (routes to onboarding/login/home)
    │   ├── onboarding_screen.dart    2. Onboarding carousel (shown once)
    │   ├── login_screen.dart         3. Login
    │   ├── register_screen.dart      4. Register
    │   ├── main_shell.dart           bottom-nav shell for the 5 tabs below
    │   ├── home_screen.dart          5. Home dashboard (+ streak, community-insights tile)
    │   ├── assessment_screen.dart    6. Check-in wizard (9 questions)
    │   ├── result_screen.dart        7. Result (gauge + SHAP factors + private note)
    │   ├── history_screen.dart       8. History (fl_chart trend + past check-ins + notes)
    │   ├── resources_screen.dart     9. Resources / self-care tips
    │   ├── help_screen.dart          10. Help & crisis support contacts
    │   ├── profile_screen.dart       11. Profile / dark mode / stats / logout
    │   └── insights_screen.dart      12. Community Insights (anonymized, cross-user)
    ├── theme/
    │   ├── app_theme.dart            light + dark ThemeData, colors, typography
    │   └── theme_controller.dart     app-wide dark-mode ValueNotifier
    ├── widgets/illustrations.dart    hand-authored SVG vector illustrations (flutter_svg)
    ├── utils/streak.dart             consecutive-day check-in streak calculation
    ├── assets/model/ppd_model.json   exported model weights, bundled into the app (see below)
    └── services/
        ├── on_device_model.dart      runs the risk model + explanation locally, no server needed
        ├── api_service.dart          talks to the Flask API (auth + history + insights only)
        └── local_store.dart          on-device session cache + dark-mode preference only
```

## The risk prediction runs on-device — no Python needed at runtime

Earlier builds called `POST /predict` on the Flask API for every check-in.
That's fine on a laptop where you're running `python api/app.py` yourself,
but **it silently breaks the moment this app is packaged as a real APK** —
there is no Python interpreter on a phone, so the actual point of the
project (the explainable ML prediction) would just fail with a network
error for every real user.

Fixed by porting the trained model into pure Dart:

- `src/export_model.py` reads the already-trained `logistic_regression.joblib`
  + `scaler.joblib` and dumps the raw numbers (coefficients, intercept,
  StandardScaler mean/scale, the encoding maps, factor labels) into
  `ppd_risk_app/assets/model/ppd_model.json`. Re-run this any time the model
  is retrained.
- `lib/services/on_device_model.dart` loads that JSON as a bundled asset and
  reproduces both the prediction (`sigmoid(coef · scaled_x + intercept)`)
  and the explanation. Logistic regression's SHAP explanation for a linear
  model reduces to `coefficient_i × scaled_feature_i`, which is what's
  computed here — no `shap` library, no Python, no network call.
- Verified against the real Python output: for a sample input, the on-device
  probability matched the Flask API's SHAP-based probability exactly
  (0.9964 both ways); the top-3 factor ranking and direction (increases/
  decreases) also matched. Magnitudes differ slightly (~10–15%) because the
  Python SHAP explainer's baseline comes from a 100-row background sample
  average rather than the exact scaled-zero baseline used here — an
  acceptable, documented approximation for a mobile app; the probability,
  risk band, and factor ranking (what the UI actually shows) are unaffected.
- Confirmed end-to-end with the Flask process fully killed (`Stop-Process`,
  then `curl` to `/health` failed) — the check-in wizard, prediction, and
  Result screen with explanations all still worked, only the "save to
  history" step failed gracefully with a visible message.

**What still needs a live server, and why that's fine:** `POST
/auth/register`, `/auth/login`, `/assessments/*`, and `/insights` still call
the Flask+MongoDB API, because syncing an account and history *across
devices* inherently requires a server — that's true for any app with
real accounts, language notwithstanding. Home/History/Profile already
degrade gracefully (try/catch around every network call) if that server is
unreachable; only the core "get a risk estimate" flow needed to be made
fully self-contained, and now is.

**If you build a real APK** (`flutter build apk`), the on-device model
travels with it automatically since it's a bundled asset — check-ins will
work with the phone in airplane mode. Auth/history/insights will show their
"could not reach server"-style fallback until the phone has internet and
`kApiBaseUrl` in `api_service.dart` points at a real deployed instance of
`api/app.py` (a phone can never reach `127.0.0.1:5000` — that's the phone
itself. You'd need to deploy the Flask API somewhere reachable, e.g. a small
cloud VM, and update `kApiBaseUrl` before building for real devices.)

## Backend: Flask + MongoDB

Accounts and check-in history now live in **MongoDB** (previously on-device
only). Three collections in a dedicated `motherwell_ppd` database:

- `users` — `{name, email (unique), password_hash, created_at}`. Passwords
  are hashed with Werkzeug's `generate_password_hash` (salted) — never
  stored or transmitted in plaintext after registration.
- `assessments` — `{user_id, timestamp, risk_probability, risk_band, top_factors, note}`.
- `sessions` — `{token, user_id, created_at}`, a simple bearer-token session
  store checked by the `require_auth` decorator on every protected route.

New endpoints (full list in `api/app.py`'s module docstring): `POST /auth/register`,
`POST /auth/login`, `POST /auth/logout`, `GET /me`, `PATCH /me`,
`POST /assessments/save`, `GET /assessments`, `PATCH /assessments/<id>/note`,
and `GET /insights` (public, aggregated, no auth).

**This is prototype-grade auth, not production security**: tokens never
expire, there's no rate limiting, no email verification, and the dev server
doesn't enforce HTTPS. Fine for a research demo; say so if this is assessed
as-is.

### Security note on the database credential

The MongoDB URI (with a real username/password) lives in `ppd_project/.env`,
loaded via `python-dotenv`, and `.gitignore` excludes it from version
control. The app uses an isolated `motherwell_ppd` database — nothing else
on the shared cluster is touched or queried. **If this project is ever
pushed to a Git remote, double-check `.env` is not staged**, and rotate the
password if it's ever exposed (pasted into a public issue, shared screen,
committed by accident, etc).

### Novel / extra features added on top of the original brief

- **Real accounts** — register/login backed by MongoDB with hashed passwords, replacing the earlier on-device-only demo auth.
- **Private journaling notes** — after a check-in, add a free-text note ("rough night, baby was unwell...") attached to that result via `PATCH /assessments/<id>/note`. Visible only to that user, shown inline in History.
- **Community Insights** *(12th screen)* — anonymized, aggregated stats across every user's check-ins via a MongoDB aggregation pipeline: risk-band distribution (pie chart) and the most common contributing factors community-wide. No individual result is identifiable. This reuses the project's own SHAP output as population-level insight, tying the explainability angle back into the live product rather than leaving it only in offline plots.
- **Check-in streak** — a 🔥 N-day streak computed from consecutive check-in dates (`lib/utils/streak.dart`), shown on Home and Profile as a light gamification/engagement nudge.
- **Dark mode** — a complete dark `ThemeData` variant, toggled from Profile, persisted locally, applied instantly app-wide via a `ValueNotifier<ThemeMode>`.
- **Home dashboard**: greeting, streak chip, "last result" summary card, gradient hero CTA, 5-tile quick actions (Check-in, History, Resources, Crisis Help, Community Insights).
- **Redesigned check-in** — one-question-per-page wizard with a progress bar instead of one long scrolling form.
- **Redesigned result** — animated circular risk gauge (`percent_indicator`) + success badge, auto-saved to MongoDB the moment it's shown.
- **History** — a trend line chart (`fl_chart`) once there are 2+ check-ins, an expandable list of past results, and any saved notes.
- **Resources** — 6 self-care tips with icons, plus a link through to Community Insights.
- **Help & Crisis Support** — a dedicated page with Samaritans/NHS/emergency contacts and a clear "this app can't respond in an emergency" warning.
- **Profile** — avatar, editable name (synced to MongoDB via `PATCH /me`), check-in/last-result/streak stats, dark mode switch, About sheet, logout.
- **Vector illustrations**: all imagery (`lib/widgets/illustrations.dart`) is hand-authored inline SVG via `flutter_svg` — no external image assets or network calls, zero third-party image dependency.

## 1. The most important assumption in this project — read this first

**The raw dataset (`post natal data.csv`) has no ground-truth PPD diagnosis
or risk label.** It is a 9-question Yes/No/Sometimes screening survey with
no outcome column. Objective 3–4 of the proposal (train and evaluate
classifiers) is impossible without a label, so `src/data_prep.py` **derives**
one:

1. Each of the 9 screening answers is ordinal-encoded (0 = no symptom, up to
   2 = most severe).
2. A **weighted composite score** is computed, with heavier weight on items
   associated with more severe clinical concern (`Suicide attempt` ×3,
   `Feeling of guilt` / `Problems of bonding with baby` / `Feeling sad or
   Tearful` ×2, `Feeling anxious` / `Irritable towards baby & partner` ×1.5,
   the remaining three items ×1). Weights are a clinically-motivated,
   documented modelling choice — not derived from the data or from a
   validated clinical instrument like the EPDS.
3. Respondents scoring **above the sample median** are labelled `1 —
   Elevated risk`; the rest are `0 — Lower risk` (see `data/metadata.json`
   for the exact threshold and weights used).

**Implication for the results below:** because the label is a
(near-)linear function of the same 9 items used as model features, Logistic
Regression can recover it almost perfectly — that's expected, not a bug,
and it's exactly why SHAP on a linear model reproduces the weighting scheme.
The genuinely useful output of this project is *not* "99% test accuracy"
(that's circular by construction) but **which items the model — and a
clinician — should weight most heavily**, and a working demonstration of
how a risk-estimation + explanation UI could be presented to a user. Report
this limitation explicitly in the dissertation; do not present the accuracy
figures as evidence of real-world diagnostic performance.

If a supervisor/marker wants a non-circular target, the cleanest fix is to
instead use `Suicide attempt` alone as the label (recoded Yes=1 else 0) and
drop it from the feature set — this avoids the label being an explicit
function of the same features. That variant is a one-line change in
`data_prep.py` and is noted there.

## 2. Dataset quality issues found and handled

- **72% duplicate rows** (1,088 of 1,503) — almost certainly repeat/bot form
  submissions within a single 26-hour window. `data_prep.py` deduplicates
  down to **326 unique respondents** before any modelling. Always report
  both the raw and de-duplicated counts — using 1,503 as "sample size" would
  be misleading.
- **Missing values** in 3 columns (6–12 rows each) — imputed with the column
  mode.
- **Inconsistent category scales** across questions (e.g. "Two or more days
  a week" vs "Yes"/"No"; "Not at all" vs "No") — resolved via explicit
  per-column ordinal maps in `data_prep.py` (documented there).
- Age is only available as 5-year bands (25–50), not continuous, and the
  dataset has no respondents under 25.

## 3. Model comparison (test set, n=66, 80/20 stratified split)

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC |
|---|---|---|---|---|---|
| Logistic Regression | 0.985 | 1.000 | 0.969 | 0.984 | 1.000 |
| XGBoost | 0.924 | 0.909 | 0.938 | 0.923 | 0.985 |
| Random Forest | 0.879 | 0.900 | 0.844 | 0.871 | 0.947 |

Full numbers: `reports/model_comparison.csv`. Confusion matrices and ROC
curves: `reports/confusion_matrix_*.png`, `reports/roc_curves_comparison.png`.
Logistic Regression is selected as the best model (`models/best_model.json`)
and is the one served by the API — again, expected given the near-linear
label construction described above.

## 4. Explainability (SHAP)

`src/explain.py` produces global feature importance
(`reports/shap_global_importance.png`, `reports/shap_summary_beeswarm.png`)
and exposes `explain_instance()`, used live by the API to return each
respondent's top 3 contributing factors. Across the dataset, `Suicide
attempt`, `Problems of bonding with baby`, `Feeling of guilt`, and `Feeling
sad or Tearful` are consistently the strongest drivers — consistent with
how they were weighted in step 1, and also consistent with clinical PPD
screening literature (EPDS item 10 on self-harm is treated as a critical
flag; bonding and guilt are core PPD symptoms). These per-user SHAP factors
are also what feed the Community Insights aggregation (§ above).

## 5. How to run everything

```bash
# 1. Regenerate data / models / SHAP plots (optional — already run once)
cd ppd_project
python src/data_prep.py
python src/train_models.py
python src/explain.py
python src/export_model.py   # re-run this whenever the model is retrained

# 2. Start the API — only needed for accounts/history/insights, NOT for check-ins (needs .env with MONGO_URI / MONGO_DB_NAME — must be running before the app)
python api/app.py            # http://127.0.0.1:5000

# 3. Run the Flutter app
cd ppd_risk_app
flutter run -d chrome        # quickest way to demo (web)
# or: flutter run -d windows
# or, on a physical Android/iOS device: flutter run
#   (then change kApiBaseUrl in lib/services/api_service.dart to your machine's
#    LAN IP, or 10.0.2.2 for the Android emulator, since 127.0.0.1 means "the phone itself")
```

**To build a real installable APK**: `flutter build apk` from `ppd_risk_app/`
(output: `build/app/outputs/flutter-apk/app-release.apk`). The risk model
works fully offline on the installed app; auth/history/insights need
`kApiBaseUrl` pointed at a deployed instance of `api/app.py` first (a phone
can never reach `127.0.0.1`).

`GET /schema` on the API drives the check-in form (question labels + options)
so the questionnaire and the model's expected inputs never drift apart.
`POST /predict` returns `risk_probability`, a `risk_band` (Low/Moderate/High,
bucketed from the probability for the UI), and the top 3 SHAP-driven factors
in plain language; it's stateless and unauthenticated. Everything after that
— saving it, listing history, adding a note, computing community insights —
goes through the authenticated MongoDB-backed endpoints described above.

**If testing in a browser and you rebuild the app**, hard-clear the tab first
(Flutter web registers a service worker that aggressively caches the old
build) — DevTools → Application → clear service workers + storage, or just
open in a private window, otherwise you'll keep seeing the previous build.

A working demo account already exists in the database from testing:
`priya.demo@motherwell.app` / `demo1234`.

## 6. Ethical considerations (Objective/Methodology step 8)

- Uses only the publicly available Kaggle survey for model training; no real
  respondent data from that survey is exposed through the app. Real app
  users' own accounts/check-ins are a separate concern — see the auth
  security caveats above.
- The app and API both surface a disclaimer: **this is a research
  prototype, not a diagnostic tool**, with guidance to contact a healthcare
  professional or crisis service (also a dedicated Help & Crisis Support page).
- The `Suicide attempt` question is clinically sensitive. It is used here as
  a modelling feature (and, in the derivation, as the highest-weighted
  contributor to the label) — the dissertation should discuss the risk of a
  prototype like this being over-relied upon, and that a real deployment
  would need clinical sign-off, a human-in-the-loop, and a validated
  instrument (e.g., EPDS) rather than a re-weighted ad hoc survey.
- No demographic variables beyond a 5-year age band are available, so
  fairness/bias analysis across other protected characteristics (ethnicity,
  income, etc.) is not possible with this dataset — worth flagging as a
  limitation for Objective 5/6.
- Community Insights aggregates data across real app users. It only ever
  returns counts/percentages (never raw per-user records), but with a very
  small number of users a "community" statistic could still be
  re-identifiable — worth a line in the dissertation's privacy discussion if
  this is deployed beyond a handful of testers.

## 7. Mapping back to the proposal's objectives

| Objective | Status |
|---|---|
| 1. Literature review | Not covered by this codebase — separate write-up |
| 2. Identify & prepare dataset | Done — `src/data_prep.py`, with limitations documented above |
| 3. Develop & compare ML models | Done — `src/train_models.py` |
| 4. Evaluate with classification metrics | Done — `reports/model_comparison.csv` |
| 5. Identify most influential factors | Done — `src/explain.py`, SHAP plots, now also surfaced live via Community Insights |
| 6. Mobile prototype with risk + explanation | Done — `ppd_risk_app/` (Flutter, 12 screens) + `api/app.py` + MongoDB |
