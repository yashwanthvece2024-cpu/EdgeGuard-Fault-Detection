from pathlib import Path
import json
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)

def evaluate_predictions(
    y_true,
    probabilities,
    class_names,
    output_dir="data/processed/evaluation",
):
    Path(output_dir).mkdir(
        parents=True,
        exist_ok=True,
    )

    probabilities = np.asarray(
        probabilities
    )

    y_pred = np.argmax(
        probabilities,
        axis=1,
    )

    metrics = {
        "accuracy": float(
            accuracy_score(y_true, y_pred)
        ),
        "balanced_accuracy": float(
            balanced_accuracy_score(
                y_true,
                y_pred,
            )
        ),
        "precision_macro": float(
            precision_score(
                y_true,
                y_pred,
                average="macro",
                zero_division=0,
            )
        ),
        "recall_macro": float(
            recall_score(
                y_true,
                y_pred,
                average="macro",
                zero_division=0,
            )
        ),
        "f1_macro": float(
            f1_score(
                y_true,
                y_pred,
                average="macro",
                zero_division=0,
            )
        ),
        "f1_weighted": float(
            f1_score(
                y_true,
                y_pred,
                average="weighted",
                zero_division=0,
            )
        ),
    }

    report = classification_report(
        y_true,
        y_pred,
        target_names=class_names,
        zero_division=0,
        output_dict=True,
    )

    with open(
        Path(output_dir) / "metrics.json",
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            {
                "overall": metrics,
                "per_class": report,
            },
            f,
            indent=2,
        )

    cm = confusion_matrix(
        y_true,
        y_pred,
        labels=np.arange(
            len(class_names)
        ),
    )

    fig = plt.figure(
        figsize=(8, 7)
    )

    ax = fig.add_subplot(111)

    im = ax.imshow(cm)

    ax.set(
        xticks=np.arange(
            len(class_names)
        ),
        yticks=np.arange(
            len(class_names)
        ),
        xticklabels=class_names,
        yticklabels=class_names,
        xlabel="Predicted",
        ylabel="True",
        title="Motor Fault Confusion Matrix",
    )

    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(
                j,
                i,
                int(cm[i, j]),
                ha="center",
                va="center",
            )

    fig.colorbar(
        im,
        ax=ax,
    )

    fig.tight_layout()

    fig.savefig(
        Path(output_dir)
        / "confusion_matrix.png",
        dpi=160,
    )

    plt.close(fig)

    print(
        json.dumps(
            metrics,
            indent=2,
        )
    )

    return metrics

def evaluate_keras_model(
    model,
    X,
    y,
    class_names,
    output_dir,
    batch_size=64,
):
    probabilities = model.predict(
        X[..., None],
        batch_size=batch_size,
        verbose=0,
    )

    return evaluate_predictions(
        y,
        probabilities,
        class_names,
        output_dir,
    )
