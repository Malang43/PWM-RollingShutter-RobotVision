# Characterizing PWM LED–Rolling-Shutter Timing Failure Regions for Feature-Based Robot Vision

**Author:** Muhammad Farhat Mehdi
**Affiliation:** Department of Computer Engineering, University of Engineering and Technology Taxila, Taxila, Pakistan

This repository documents simulated PWM LED illumination interacting with rolling-shutter row timing and its effect on feature correspondence and calibrated pairwise relative pose. It preserves journal MATLAB workflows, compact result evidence and publication figures with explicit provenance.

Scope: simulated photometric PWM–rolling-shutter perturbations and pairwise relative pose. No physical LED-camera experiment is included. Full SLAM trajectory performance is not evaluated. Claims are limited to the evaluated simulation settings.

**Release status:** ready for GitHub publication under the documented packaging policy. Notebook configurations and portable paths are structurally verified; known reproducibility limitations are disclosed in [REVIEW_NEEDED.md](REVIEW_NEEDED.md).

## Dataset and configuration

Independently download TUM RGB-D Freiburg 1 fr1/xyz and fr1/desk; see [dataset setup](docs/dataset_setup.md) and the [official TUM download page](https://webshare.cvg.cit.tum.de/g/rgbd/dataset/). Benchmark images are not distributed.

640 x 480; fx=517.3, fy=516.5, cx=318.6, cy=255.3. START_INDEX=100, GAP=3, 50 pairs per sequence. Phases [0, 0.125, 0.25, 0.5, 0.875]; readouts [5, 10, 15, 20, 25, 30] ms. PWM 100 Hz, exposure 1 ms, duty 25%, modulation 90%, samples 100. Fundamental RANSAC: 2000 max trials, 1.5 pixels, 99.9% confidence. Pose validFraction >=0.5. SURF, ORB validation, SuperPoint (2048 keypoints) + LightGlue (features="superpoint", resize=None). [Main parameters](configs/main_experiment.md), [intrinsics](configs/camera_intrinsics.md), [sweeps](configs/parameter_sweeps.md).

## Expected results and design

| Sequence | SURF failure | LightGlue observed failure | SURF retention | LightGlue retention |
|---|---:|---:|---:|---:|
| fr1/xyz | 66.733% | 0.000% | 3.606% | 78.491% |
| fr1/desk | 71.333% | 0.000% | 3.429% | 76.217% |

Retention is mean condition-level median inlier retention. Together: 100 unique image pairs. Image pairs are repeated-condition sampling units; 1500 or 3000 pair-condition evaluations are not independent scenes. Paired cluster bootstrap retains every condition and both methods per resampled PairID; see [design](docs/experimental_design.md), [definitions](docs/result_definitions.md).

Nine geometry combinations: SURF failure 66.733%–68.133%, LightGlue 0.000%–0.133%, retention advantage 74.753–75.059 percentage points. 18M illustrative combined accuracy success: SURF 4.667% (70/1500), LightGlue 56.133% (842/1500), counting unrecovered cases unsuccessful. All supplied results, including pair blocks, ORB, brightness and mechanism, appear unchanged in [expected results](docs/expected_results.md) and are mapped to [original evidence](docs/result_evidence.md).

MATLAB–Python complete final-grid verification: maximum row-gain difference 1.33226762955019e-15; maximum pixel difference 1 8-bit intensity level; no differences >1 level. Python row-gain/single-image source is included in the final xyz notebook; successful fresh execution remains to be verified. Convergence compares [25, 50, 100, 200, 500, 1000] samples against exact analytical rectangular-PWM integration. At Ns=100: mean absolute error 0.00068875, RMS 0.001883786703, 95th percentile 0.004875, 99th percentile 0.007875, max 0.009.

## Contents, requirements and reproduction

| Folder | Contents |
|---|---|
| docs | Design, setup, workflow, definitions, environment, evidence |
| matlab/core | Final raw SURF export |
| matlab/shared_backend | Common geometry and desk replication |
| matlab/validation | Controls, sensitivity, convergence, pair robustness and equivalence |
| matlab/statistics | Bootstrap, pose accuracy/success, legacy figure statistics |
| matlab/figure_generation | Final shared-backend and legacy journal generators |
| python | Final author-supplied xyz/desk SuperPoint + LightGlue exporters; verification and source-status notes |
| configs | Main parameters, calibration, supplementary sweeps |
| results | Original summaries, downstream pairwise inputs, small raw tables |
| figures | Main and supplementary publication graphics |

MATLAB R2025b / 25.2.0.2998904 was used for final analyses. Confirmed Colab: Python 3.13.15, PyTorch 2.11.0+cu130, SuperPoint and LightGlue package version 0.0. Exact upstream LightGlue revision is unavailable. See [environment](docs/environment.md).

Follow the 12-step [reproduction guide](docs/reproduction_guide.md): download data, set paths, generate matches, common backend, bootstrap, desk replication, sensitivity, convergence, accuracy success, pair robustness and figures. Configure paths once in [setup_paths_example.m](matlab/setup_paths_example.m) or ignored matlab/setup_paths.m. Scripts read saved inputs and write under ignored reproduction_work; see [path-only changes](docs/path_portability.md).

## Citation, availability and license

Muhammad Farhat Mehdi, Department of Computer Engineering, University of Engineering and Technology Taxila, Taxila, Pakistan. Cite the manuscript title above; [CITATION.cff](CITATION.cff) records repository version 1.0.0. Journal publication metadata and DOI are not claimed.

Compact evidence/figures included. Obtain benchmark data independently. Essential excluded tables and later archival options: [large files](docs/large_files.md). [MANIFEST.md](MANIFEST.md) records source paths, purpose, sizes, hashes and exclusions. No remote archive uploaded.

Author-owned repository code/material is licensed under the [MIT License](LICENSE), copyright 2026 Muhammad Farhat Mehdi.

### Third-party software and dataset rights

TUM RGB-D benchmark remains subject to its original dataset terms. LightGlue and associated third-party code remain subject to their original licenses, including [Apache License 2.0](https://github.com/cvg/LightGlue/blob/main/LICENSE) where applicable. The repository MIT license does not relicense third-party datasets or software. No TUM images or upstream LightGlue package source are redistributed.

## Reproducibility status

Final MATLAB analysis scripts and final xyz/desk SuperPoint+LightGlue notebooks are included, together with compact result summaries. TUM datasets must be downloaded separately. Large raw correspondence tables are excluded from Git and [documented](docs/large_files.md). Notebook configurations and configurable paths were structurally verified during packaging; full experiments were not rerun solely for packaging. The exact original LightGlue Git commit was not preserved. Some publication figures rely on preserved tables/images where the original plotting script is unavailable; see [figure provenance](docs/figure_provenance.md).
