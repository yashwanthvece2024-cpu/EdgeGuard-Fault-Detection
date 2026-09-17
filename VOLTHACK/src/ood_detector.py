from pathlib import Path
import numpy as np

class EmbeddingOODDetector:
    """
    Lightweight OOD detector based on distance from
    class centroids in the CNN embedding space.
    """

    def __init__(
        self,
        model,
        threshold=None,
    ):
        self.model = model
        self.threshold = threshold
        self.centroids = None
        self.scale = None

        import tensorflow as tf

        try:
            self.encoder = tf.keras.Model(
                model.input,
                model.get_layer(
                    "embedding"
                ).output,
            )
        except Exception as exc:
            raise RuntimeError(
                "CNN must contain an 'embedding' layer."
            ) from exc

    def fit(
        self,
        X,
        y,
        quantile=0.95,
    ):
        embeddings = (
            self.encoder.predict(
                X[..., None],
                verbose=0,
            )
        )

        self.centroids = {}

        distances = []

        for c in np.unique(y):
            ec = embeddings[
                y == c
            ]

            centroid = np.mean(
                ec,
                axis=0,
            )

            self.centroids[
                int(c)
            ] = centroid

            distances.extend(
                np.linalg.norm(
                    ec - centroid,
                    axis=1,
                ).tolist()
            )

        distances = np.asarray(
            distances
        )

        self.threshold = float(
            np.quantile(
                distances,
                quantile,
            )
        )

        self.scale = float(
            np.std(distances)
            + 1e-8
        )

        return self

    def score(self, X):
        embeddings = (
            self.encoder.predict(
                X[..., None],
                verbose=0,
            )
        )

        scores = []

        for embedding in embeddings:
            distance = min(
                float(
                    np.linalg.norm(
                        embedding
                        - centroid
                    )
                )
                for centroid
                in self.centroids.values()
            )

            scores.append(
                distance
            )

        return np.asarray(
            scores,
            dtype=np.float32,
        )

    def is_ood(self, X):
        return (
            self.score(X)
            > self.threshold
        )

    def save(
        self,
        path="models/ood_detector.npz",
    ):
        Path(path).parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        keys = np.asarray(
            sorted(
                self.centroids.keys()
            ),
            dtype=np.int64,
        )

        centroids = np.stack(
            [
                self.centroids[
                    int(k)
                ]
                for k in keys
            ]
        )

        np.savez_compressed(
            path,
            class_ids=keys,
            centroids=centroids,
            threshold=np.asarray(
                [self.threshold],
                dtype=np.float32,
            ),
            scale=np.asarray(
                [self.scale],
                dtype=np.float32,
            ),
        )

    def load(
        self,
        path="models/ood_detector.npz",
    ):
        data = np.load(path)

        keys = data[
            "class_ids"
        ]

        centroids = data[
            "centroids"
        ]

        self.centroids = {
            int(k):
                centroids[i]
            for i, k
            in enumerate(keys)
        }

        self.threshold = float(
            data["threshold"][0]
        )

        self.scale = float(
            data["scale"][0]
        )

        return self
