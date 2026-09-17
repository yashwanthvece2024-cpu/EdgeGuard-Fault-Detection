# VoltHacks AI Data Policy

## Synthetic data

`data/synthetic/` is controlled development data. It is useful for debugging and proving that the pipeline works, but its accuracy must never be presented as industrial validation.

## University of Ottawa data

Place the real CSV files under:

`data/ottawa/raw/`

The University of Ottawa dataset contains vibration, acoustic and temperature measurements from eight D396 Marathon Electric three-phase motors, with 420,000 samples per 10-second file at 42 kHz. Its filenames encode health condition, speed and load. The preprocessing code uses the first accelerometer column for the vibration CNN.

## Paderborn

`data/paderborn/raw/` is reserved for cross-domain bearing validation. Do not merge it blindly with Ottawa labels because the experimental setup and label taxonomy differ.

## CWRU

`data/cwru/raw/` is reserved for an independent bearing benchmark.

## Leakage rule

Never randomly split overlapping windows from the same recording into train and test. Split by recording/run/machine group first.

## Reporting rule

Report:
- accuracy
- balanced accuracy
- precision
- recall
- macro F1
- weighted F1
- confusion matrix
- calibration
- OOD/unknown rejection
- inference latency

A synthetic 100% score is a development result, not industrial accuracy.
