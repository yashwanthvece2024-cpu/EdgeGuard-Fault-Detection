from pathlib import Path
import re
import numpy as np
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit

CLASS_NAMES = [
    "healthy",
    "imbalance",
    "bearing_fault",
    "electrical_fault",
    "misalignment",
]

def ottawa_label_from_name(name):
    stem = Path(name).stem.upper()

    m = re.search(r"([A-Z])-([A-Z])", stem)
    if not m:
        m = re.search(r"([A-Z])([A-Z])", stem)
    if not m:
        return None

    a, b = m.group(1), m.group(2)

    if a == "H" and b == "H":
        return "healthy"

    if b == "U":
        return "imbalance"

    if b == "M":
        return "misalignment"

    if a == "F" and b == "B":
        return "bearing_fault"

    if a == "B":
        # Bowed rotor is kept in the mechanical family.
        return "imbalance"

    if a == "K":
        # Broken rotor bars are treated as an electrical family.
        return "electrical_fault"

    if a in {"S", "V"}:
        return "electrical_fault"

    return None

def _stream_windows(
    csv_path,
    n=2048,
    max_windows=80,
    stride=None,
):
    stride = stride or n
    chunksize = 50000
    buffer = np.empty(0, dtype=np.float32)
    windows = []

    for chunk in pd.read_csv(
        csv_path,
        header=None,
        usecols=[0],
        chunksize=chunksize,
    ):
        values = pd.to_numeric(
            chunk.iloc[:, 0],
            errors="coerce",
        ).dropna().to_numpy(np.float32)

        if len(values) == 0:
            continue

        buffer = np.concatenate(
            [buffer, values]
        )

        while (
            len(buffer) >= n
            and len(windows) < max_windows
        ):
            windows.append(
                buffer[:n].copy()
            )
            buffer = buffer[stride:]

        if len(windows) >= max_windows:
            break

    return windows

def prepare_ottawa(
    raw_dir="data/ottawa/raw",
    output="data/processed/ottawa_windows.npz",
    n=2048,
    max_windows_per_file=80,
):
    raw_dir = Path(raw_dir)
    files = sorted(
        raw_dir.rglob("*.csv")
    )

    if not files:
        raise FileNotFoundError(
            f"No CSV files found under {raw_dir}. "
            "Download/extract the University of Ottawa dataset there first."
        )

    X, y, groups, source_files = [], [], [], []
    skipped = []

    for path in files:
        label = ottawa_label_from_name(
            path.name
        )

        if label is None:
            skipped.append(path.name)
            continue

        windows = _stream_windows(
            path,
            n=n,
            max_windows=max_windows_per_file,
            stride=n,
        )

        for w in windows:
            X.append(w)
            y.append(
                CLASS_NAMES.index(label)
            )
            groups.append(path.stem)
            source_files.append(path.name)

    if not X:
        raise RuntimeError(
            "No recognized Ottawa CSV files were processed. "
            "Run the command and inspect the printed skipped filenames."
        )

    X = np.asarray(X, dtype=np.float32)
    y = np.asarray(y, dtype=np.int64)
    groups = np.asarray(groups)
    source_files = np.asarray(source_files)

    Path(output).parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    np.savez_compressed(
        output,
        X=X,
        y=y,
        groups=groups,
        source_files=source_files,
        class_names=np.asarray(CLASS_NAMES),
    )

    print(
        f"Processed {len(X)} Ottawa windows "
        f"from {len(set(groups))} recordings."
    )

    if skipped:
        print(
            "Skipped unrecognized files "
            "(first 20):",
            skipped[:20],
        )

    print("Saved:", output)

if __name__ == "__main__":
    prepare_ottawa()
