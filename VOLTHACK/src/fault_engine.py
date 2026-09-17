from .schemas import Diagnosis, FaultEvidence

def diagnose(
    features,
    cnn_probs=None,
):
    cnn_probs = cnn_probs or {}

    vibration = features[
        "rms_accel_g"
    ]

    current = features[
        "current_mean_a"
    ]

    temperature = features[
        "temperature_c"
    ]

    dominant_frequency = features[
        "dominant_hz"
    ]

    # Adjusted baseline thresholds to support both lightweight simulation windows and real hardware data
    bearing_score = 0.0
    if dominant_frequency > 300:
        bearing_score = min(
            1.0,
            max(
                0.0,
                vibration / 0.8,
            ),
        )
    else:
        bearing_score = min(
            1.0,
            max(
                0.0,
                vibration / 1.5,
            ),
        )

    imbalance_score = min(
        1.0,
        max(
            0.0,
            vibration / 0.6,
        ),
    )

    electrical_score = min(
        1.0,
        max(
            0.0,
            (current - 1.2) / 1.0 if current > 1.2 else current / 2.0,
        ),
    )

    thermal_score = min(
        1.0,
        max(
            0.0,
            (temperature - 40.0) / 20.0,
        ),
    )

    misalignment_score = min(
        1.0,
        max(
            0.0,
            vibration / 0.7,
        ),
    )

    scores = {
        "bearing_fault":
            0.45 * bearing_score
            + 0.55
            * cnn_probs.get(
                "bearing_fault",
                0.0,
            ),

        "imbalance":
            0.45 * imbalance_score
            + 0.55
            * cnn_probs.get(
                "imbalance",
                0.0,
            ),

        "misalignment":
            0.45 * misalignment_score
            + 0.55
            * cnn_probs.get(
                "misalignment",
                0.0,
            ),

        "electrical_fault":
            0.45 * electrical_score
            + 0.55
            * cnn_probs.get(
                "electrical_fault",
                0.0,
            ),

        "overheating":
            thermal_score,
    }

    if bool(
        cnn_probs.get(
            "_ood",
            False,
        )
    ):
        return Diagnosis(
            fault="unknown",
            confidence=0.0,
            severity="warning",
            affected_component=(
                "unknown / outside trained distribution"
            ),
            evidence=FaultEvidence(
                vibration_score=max(
                    bearing_score,
                    imbalance_score,
                    misalignment_score,
                ),
                electrical_score=
                    electrical_score,
                thermal_score=
                    thermal_score,
                cnn_score=max(
                    [
                        value
                        for key, value
                        in cnn_probs.items()
                        if not key.startswith("_")
                    ]
                    or [0.0]
                ),
                ood_score=float(
                    cnn_probs.get(
                        "_ood_distance",
                        0.0,
                    )
                ),
            ),
            recommended_action=(
                "Collect another window and verify "
                "operating condition, sensor mounting "
                "and RPM before assigning a fault."
            ),
            decision_status=(
                "out_of_distribution"
            ),
        )

    fault, confidence = max(
        scores.items(),
        key=lambda item: item[1],
    )

    if confidence < 0.10:
        return Diagnosis(
            fault="unknown",
            confidence=float(
                confidence
            ),
            severity="normal",
            affected_component=(
                "not confidently identified"
            ),
            evidence=FaultEvidence(
                vibration_score=max(
                    bearing_score,
                    imbalance_score,
                    misalignment_score,
                ),
                electrical_score=
                    electrical_score,
                thermal_score=
                    thermal_score,
                cnn_score=max(
                    [
                        value
                        for key, value
                        in cnn_probs.items()
                        if not key.startswith("_")
                    ]
                    or [0.0]
                ),
            ),
            recommended_action=(
                "Collect additional diagnostic "
                "windows and verify RPM/load."
            ),
            decision_status="uncertain",
        )

    severity = (
        "normal"
        if confidence < 0.40
        else "warning"
        if confidence < 0.70
        else "critical"
    )

    component = {
        "bearing_fault":
            "front bearing",
        "imbalance":
            "rotor / motor assembly",
        "misalignment":
            "shaft / coupling",
        "electrical_fault":
            "motor electrical circuit",
        "overheating":
            "motor housing / windings",
    }.get(
        fault,
        "unknown",
    )

    action = {
        "bearing_fault":
            "Inspect bearing lubrication, play, "
            "temperature and vibration.",
        "imbalance":
            "Inspect rotor balance, coupling "
            "and mounting.",
        "misalignment":
            "Inspect shaft alignment, coupling "
            "and mounting.",
        "electrical_fault":
            "Check current draw, controller, "
            "supply and motor circuit.",
        "overheating":
            "Inspect cooling, loading, bearings "
            "and electrical condition.",
    }.get(
        fault,
        "Collect another diagnostic window.",
    )

    return Diagnosis(
        fault=fault,
        confidence=float(
            min(
                1.0,
                max(0.25, confidence),
            )
        ),
        severity=severity,
        affected_component=component,
        evidence=FaultEvidence(
            vibration_score=max(
                bearing_score,
                imbalance_score,
                misalignment_score,
            ),
            electrical_score=
                electrical_score,
            thermal_score=
                thermal_score,
            cnn_score=max(
                [
                    value
                    for key, value
                    in cnn_probs.items()
                    if not key.startswith("_")
                ]
                or [0.0]
            ),
        ),
        recommended_action=action,
        decision_status="confident",
    )