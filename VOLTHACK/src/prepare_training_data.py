from pathlib import Path
import numpy as np
from sklearn.model_selection import GroupShuffleSplit

from .synthetic_dataset import (
    generate_synthetic_dataset
)

SYNTHETIC = Path(
    "data/synthetic/"
    "synthetic_windows.npz"
)

OTTAWA = Path(
    "data/processed/"
    "ottawa_windows.npz"
)

OUT = Path(
    "data/processed"
)

def load_npz(path):
    data = np.load(
        path,
        allow_pickle=True,
    )

    return (
        np.asarray(
            data["X"],
            dtype=np.float32,
        ),
        np.asarray(
            data["y"],
            dtype=np.int64,
        ),
        np.asarray(
            data["groups"]
        ).astype(str),
    )

def split_groups(
    X,
    y,
    groups,
    seed=2026,
):
    """
    Split by recording/group rather than by individual windows.
    This is the key leakage-control mechanism.
    """

    gss = GroupShuffleSplit(
        n_splits=1,
        test_size=0.20,
        random_state=seed,
    )

    train_idx, temp_idx = next(
        gss.split(
            X,
            y,
            groups,
        )
    )

    X_train = X[
        train_idx
    ]

    y_train = y[
        train_idx
    ]

    g_train = groups[
        train_idx
    ]

    X_temp = X[
        temp_idx
    ]

    y_temp = y[
        temp_idx
    ]

    g_temp = groups[
        temp_idx
    ]

    gss2 = GroupShuffleSplit(
        n_splits=1,
        test_size=0.50,
        random_state=seed + 1,
    )

    val_idx, test_idx = next(
        gss2.split(
            X_temp,
            y_temp,
            g_temp,
        )
    )

    return (
        (
            X_train,
            y_train,
            g_train,
        ),
        (
            X_temp[val_idx],
            y_temp[val_idx],
            g_temp[val_idx],
        ),
        (
            X_temp[test_idx],
            y_temp[test_idx],
            g_temp[test_idx],
        ),
    )

def save_split(
    name,
    X,
    y,
    groups,
):
    output = (
        OUT / f"{name}.npz"
    )

    np.savez_compressed(
        output,
        X=np.asarray(
            X,
            dtype=np.float32,
        ),
        y=np.asarray(
            y,
            dtype=np.int64,
        ),
        groups=np.asarray(
            groups
        ),
    )

    print(
        f"{name}: "
        f"{len(X)} windows, "
        f"{len(set(groups))} groups"
    )

def main():
    OUT.mkdir(
        parents=True,
        exist_ok=True,
    )

    if not SYNTHETIC.exists():
        print(
            "Synthetic dataset missing. "
            "Creating it..."
        )

        generate_synthetic_dataset(
            output=str(
                SYNTHETIC
            ),
            samples_per_class=1000,
            n=2048,
            fs=4096,
            seed=2026,
        )

    Xs, ys, gs = load_npz(
        SYNTHETIC
    )

    if OTTAWA.exists():
        Xr, yr, gr = load_npz(
            OTTAWA
        )

        real_train, real_val, real_test = (
            split_groups(
                Xr,
                yr,
                gr,
                seed=77,
            )
        )

        syn_train, syn_val, _ = (
            split_groups(
                Xs,
                ys,
                gs,
                seed=78,
            )
        )

        X_train = np.concatenate(
            [
                syn_train[0],
                real_train[0],
            ],
            axis=0,
        )

        y_train = np.concatenate(
            [
                syn_train[1],
                real_train[1],
            ],
            axis=0,
        )

        g_train = np.concatenate(
            [
                np.asarray(
                    [
                        "synthetic_" + g
                        for g in syn_train[2]
                    ]
                ),
                np.asarray(
                    [
                        "ottawa_" + g
                        for g in real_train[2]
                    ]
                ),
            ]
        )

        X_val = np.concatenate(
            [
                syn_val[0],
                real_val[0],
            ],
            axis=0,
        )

        y_val = np.concatenate(
            [
                syn_val[1],
                real_val[1],
            ],
            axis=0,
        )

        g_val = np.concatenate(
            [
                np.asarray(
                    [
                        "synthetic_" + g
                        for g in syn_val[2]
                    ]
                ),
                np.asarray(
                    [
                        "ottawa_" + g
                        for g in real_val[2]
                    ]
                ),
            ]
        )

        # The final test is REAL Ottawa data only.
        X_test, y_test, g_test = (
            real_test
        )

        save_split(
            "train",
            X_train,
            y_train,
            g_train,
        )

        save_split(
            "val",
            X_val,
            y_val,
            g_val,
        )

        save_split(
            "test",
            X_test,
            y_test,
            [
                "OTTAWA_TEST_" + g
                for g in g_test
            ],
        )

        print(
            "\nFINAL TEST = REAL OTTAWA ONLY"
        )

    else:
        syn_train, syn_val, syn_test = (
            split_groups(
                Xs,
                ys,
                gs,
            )
        )

        save_split(
            "train",
            *syn_train,
        )

        save_split(
            "val",
            *syn_val,
        )

        save_split(
            "test",
            *syn_test,
        )

        print(
            "\nWARNING: Ottawa data not found."
        )

        print(
            "This is synthetic-only evaluation."
        )

if __name__ == "__main__":
    main()
