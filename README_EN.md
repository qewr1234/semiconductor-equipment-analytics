# Semiconductor Equipment Data Projects: English Summary

One-page summary of two personal projects on public PHM Society data-challenge datasets, written for sharing with an overseas HQ. All numbers are the same as in the Korean [`README.md`](README.md), [`cmp2016/README.md`](cmp2016/README.md) and [`cmp2016/FAB.md`](cmp2016/FAB.md), which are the documents of record.

| Project | Equipment | Task | Headline result |
|---|---|---|---|
| Ion-mill FlowCool fault early warning (PHM 2018) | Ion mill etch tools (20) | Detect 3 helium-cooling (FlowCool) faults one hour ahead | At 1% false alarms, 21–30x better than random |
| CMP removal-rate prediction (PHM 2016) | Chemical mechanical planarization | Predict per-wafer material removal rate; interpret consumable wear | Test MSE 6.29 (best of contest top 5: 7.07; post-contest papers 6.33–6.36, within test noise) |

## 1. Ion-mill FlowCool fault early warning (PHM 2018 Data Challenge)

**Data.** Public PHM Society 2018 Data Challenge data: 20 ion mill etch tools, 4-second sensor logs, 82.19 million training rows (5.4 GB compressed, 34 GB extracted). The organizer was affiliated with Seagate; the equipment vendor is undisclosed. Sensor values are pre-standardized (no physical units).

**Goal.** For each row, predict whether each of three FlowCool faults will occur within the next hour: *FlowCool Pressure Dropped Below Limit* (741 recorded faults), *Flowcool Pressure Too High Check Flowcool Pump* (332), *Flowcool leak* (137).

**Validation.** Per tool, the first 75% of the period is used for training and the last 25% for validation (the contest test set is the period immediately following, on the same tools).

| Fault | AUC | Recall at 1% false alarms | vs. random |
|---|---|---|---|
| Pressure dropped below limit | 0.850 | 21.4% | 21x |
| Pressure too high (check pump) | 0.822 | 29.9% | 30x |
| Leak | 0.881 | 30.1% | 30x |

**Method.** (1) Stream the tar.gz without extracting it into per-tool Parquet (about 10 min, 3.2 GB) so that 82M rows can be processed with 15 GB RAM and 4 cores. (2) 206 causal row-level features: 1-minute to 1-day rolling statistics, z-scores against per-recipe-step normal values (fitted on the training period only), the residual from a pressure-to-flow curve fitted on normal data, time since excursions and stops, and recent occurrence counts (half of same-type faults recur within a day). (3) LightGBM multiclass over 13 time-to-failure bins, then a decision rule that minimizes the expected penalty under the official scoring. (4) A single-file dashboard (`dashboard/index.html`).

**Honest limits.** Under the official (S1+S2)/2 score, the expected-penalty rule answers NaN everywhere, so the validation score (76.284) equals an all-NaN submission. Faults are rare (0.07–0.31% of rows are within one hour of a fault), so at 1% false alarms the approximate alarm precision is only 2–6%: the alarm is an inspection recommendation, not an interlock. One tool (03_M02) accounts for 298 of the 741 pressure-drop faults (40%).

**Deliverables for support work.** `docs/flowcool_alarm_guide.md` (customer-facing alarm response memo in Korean: symptoms, check order, hypothesized causes, actions, escalation), `service/` (FastAPI alarm REST API with SQLite alarm history and a Dockerfile; demo on synthetic data), `assistant/` (retrieval-based Q&A helper over the project documents).

## 2. CMP removal-rate prediction (PHM 2016 Data Challenge)

**Data.** 1,981 training wafer-stages, 424 test and 424 validation wafers, with published answers.

**Results (MSE, lower is better).** Final ensemble: test 6.29 / validation 6.03. Best of the contest top 5: 7.07. Post-contest papers: 6.33 and 6.36; the difference from 6.29 is well inside the test-set noise (bootstrap standard error of the test MSE about 0.6). Adding tabular foundation models (TabPFN v2 and TabICLv2; Built with PriorLabs-TabPFN) improved nested CV from 6.61 to 6.31 with a paired-bootstrap 95% interval that excludes zero; on test and validation the direction is the same but the interval includes zero.

**Method.** 580 features (112 base, 418 sequence-shape features from the raw 1 Hz traces, 50 neighbor features computed with inner folds to avoid leakage). Members: per-regime LightGBM, a 1D-CNN + tabular fusion network, a Gaussian process, TabPFN v2 and TabICLv2. Per-regime NNLS blending with clipping. Model and feature selection used nested 5-fold CV only; test and validation answers were used only for the final report. A Kaggle file sometimes used as "test labels" is not the official answer file (all 424 rows differ) and was not used.

**Mechanical-engineering view.** In chamber 4, removal rate fell about 11–14% as the dresser wore. Dresser replacements (a natural experiment: 3 replacements in about 65 days) and within-life slopes (−0.80 ± 0.07 and −0.85 ± 0.09 per 100 usage units) confirm it. Pressure × velocity varied 6–9% between wafers but did not explain removal-rate differences (rank correlation −0.15 / 0.02), so the variation comes from polishing efficiency (consumable state), not from set points.

**Factory-condition findings (`cmp2016/FAB.md`).** The contest setting uses answers of wafers processed before *and after* the target wafer. Re-evaluated causally (only metrology that has already arrived, in processing order; deployment period days 30–65):

| Condition | MSE |
|---|---|
| Real-time VM, metrology delay 1 h (baseline) | 12.90 (12.31 with a TabICLv2 member) |
| Real-time VM, delay 0 | 9.26 |
| Real-time VM, delay 1 h, EWMA + Kalman only (no LightGBM) | 15.78 |
| Real-time VM, delay 1 h, 1 of 5 wafers measured | 15.70 |
| Phase-2 VM confirmed 24 h after polishing (test / validation) | 6.99 / 7.30 (contest-style, same period: 6.76 / 6.87) |

- Metrology delay matters more than the model: delay 1 h to 0 gives 12.9 to 9.3, more than the best model change (12.9 to 12.3).
- For run-to-run polishing-time control, metrology feedback itself does most of the work (RMS error 14.6% to 4.8% with EWMA; ML barely improves on it).
- 90% adaptive conformal prediction intervals kept about 89% coverage across delay settings.
- The service is event-driven (`VMService`): `on_metrology()` validates and stores arriving measurements and updates the estimators, `on_wafer()` returns the prediction, 90% interval and confidence flags, `maybe_retrain()` refits once a day. 3.8 ms per prediction, 2.9 s for the daily refit.
- Limits: 65 days, 3 chamber/recipe regimes, fixed delay assumption, no thickness targets; the fusion network is not in the real-time version.

## 3. AI-use disclosure

The code, analyses and documents were written with the AI coding assistant Claude (Claude Code); 19 of the 20 commits are authored by Claude. The applicant set the problems and goals (the choice of the two datasets, targeting the contest score, the dashboard, the mechanical-engineering view of dresser wear, the demand to re-evaluate under factory conditions, the 2022–2026 literature check), decided what to keep (nested CV and honest alarm precision instead of optimistic numbers, correcting the Kaggle-label description), reviewed results and asked for corrections. All numbers come from runs stored in the repository (`dashboard/data.json`, `cmp2016/*.json`).

## 4. How to run

```bash
pip install -r requirements.txt
# PHM 2018: convert -> sample -> fit -> dashboard (15 GB RAM, 4 cores; download link in README.md)
python convert_rows.py --archive data/raw/phm_data_challenge_2018.tar.gz --out data/rows
python train_rows.py sample --rows-dir data/rows --out data/samples/rows_v3.parquet
python train_rows.py fit --sample data/samples/rows_v3.parquet --save-proba data/val_proba_v5.npz
python build_dashboard.py --sample data/samples/rows_v3.parquet --proba data/val_proba_v5.npz
# Alarm service and assistant (work without the raw data)
python -m service.demo                 # synthetic-data demo with SQLite alarm history
python -m uvicorn service.app:app      # FlowCool alarm REST API
python -m assistant.build_index && python -m assistant.ask 'question'   # first run downloads the ~470 MB embedding model
# PHM 2016 CMP (download commands in cmp2016/README.md)
python cmp2016/run_cmp.py && python cmp2016/build_cmp_dashboard.py
python cmp2016/fab_run.py --stage main
# Tests
python -m pytest
```

A `Dockerfile` (repository root, dependencies in `requirements-service.txt`) packages the alarm API; it could not be built in the development environment (no Docker daemon).
