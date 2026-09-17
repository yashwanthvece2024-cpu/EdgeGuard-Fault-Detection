from .synthetic_dataset import generate_synthetic_dataset

if __name__ == "__main__":
    generate_synthetic_dataset(
        output=(
            "data/synthetic/"
            "synthetic_windows.npz"
        ),
        samples_per_class=1000,
        n=2048,
        fs=4096,
        seed=2026,
    )
