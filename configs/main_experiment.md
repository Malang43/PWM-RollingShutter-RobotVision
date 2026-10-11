# Final main configuration

| Setting | Value |
|---|---|
| Dataset | TUM RGB-D Freiburg 1 |
| Sequences | fr1/xyz, fr1/desk |
| Resolution | 640 x 480, no resizing |
| START_INDEX | 100, MATLAB one-based |
| GAP | 3 |
| Unique pairs | 50 per sequence |
| Phase (cycles) | 0, 0.125, 0.25, 0.5, 0.875 |
| Readout (ms) | 5, 10, 15, 20, 25, 30 |
| PWM frequency | 100 Hz |
| Exposure | 1 ms |
| Duty cycle | 25% |
| Modulation depth | 90% |
| Temporal samples | 100 |
| Fundamental RANSAC max trials | 2000 |
| Distance threshold | 1.5 pixels |
| Confidence | 99.9% |
| Pose criterion | validFraction >= 0.5 |
| Pipelines | SURF, ORB validation, SuperPoint + LightGlue |
| SuperPoint | max_num_keypoints=2048 |
| LightGlue | features="superpoint" |
| Image loading | resize=None |
| Python temporal grid | np.linspace(0.0, exposure_s, num_samples) |
| Python 8-bit rounding | np.rint |

Both author-designated final xyz/desk exporters pass static configuration checks. Both have configurable paths and cleared saved outputs; complete experiments were not rerun during packaging. Original MATLAB backend estimates F and E independently. See [camera intrinsics](camera_intrinsics.md).
