# Final LightGlue notebook verification

Both author-designated final correspondence exporters exist. This is a static source/configuration inspection, not a successful fresh Colab execution. Scientific code/parameters are preserved; documented path edits and saved-output cleanup are described in [notebook portability](notebook_portability.md).

| Parameter | fr1/xyz notebook | fr1/desk notebook | Expected final value | Status |
|---|---|---|---|---|
| Temporal samples | 100 | 100 | 100 | PASS |
| Python start index | 99 | 99 | 99 | PASS |
| Pair count | 50 | 50 | 50 | PASS |
| Frame gap | 3 | 3 | 3 | PASS |
| Relative phases | [0.0, 0.125, 0.25, 0.5, 0.875] | [0.0, 0.125, 0.25, 0.5, 0.875] | [0, 0.125, 0.25, 0.5, 0.875] | PASS |
| Readouts (ms) | [5, 10, 15, 20, 25, 30] | [5, 10, 15, 20, 25, 30] | [5, 10, 15, 20, 25, 30] | PASS |
| PWM frequency | 100.0 | 100.0 | 100 Hz | PASS |
| Exposure | 1.0 ms | 0.001 s | 1 ms | PASS |
| Duty | 0.25 | 0.25 | 0.25 | PASS |
| Modulation depth | 0.9 | 0.9 | 0.90 | PASS |
| Rounding before uint8 | np.rint before uint8 | np.rint before uint8 | np.rint before uint8 | PASS |
| SuperPoint keypoints | 2048 | 2048 | 2048 | PASS |
| LightGlue features | superpoint | superpoint | superpoint | PASS |
| Extractor resizing | None | None | None | PASS |
| Exposure sample spacing | np.linspace(0.0, exposure_s, num_samples); called with NUM_SAMPLES=100 | np.linspace(0.0, exposure_s, NUM_SAMPLES) | 100 endpoint-inclusive samples | PASS |
| RGB image dimensions | PIL RGB; recorded shape (480, 640, 3); no resizing | PIL RGB; H=480, W=640 and shape check | 640 x 480 RGB | PASS |

Python index 99 corresponds to MATLAB index 100. The xyz function uses the local argument num_samples (default 100), with NUM_SAMPLES passed explicitly by the final PWM exporter. NumPy linspace includes both endpoints by default; neither exporter overrides endpoint. Both apply np.rint followed by clipping before uint8 conversion. The xyz image size is supported by recorded inspection and native RGB loading; unlike desk it lacks an explicit size guard.

Configuration status: xyz PASS; desk PASS. Path portability: both PASS. All saved outputs/errors were removed. Extraction/discovery paths are centralized and consistent. Complete learned-feature experiments were not rerun; see [structural validation](notebook_structural_validation.md). The unpinned checkout cannot recover the historical LightGlue revision; that is a disclosed reproducibility limitation.
