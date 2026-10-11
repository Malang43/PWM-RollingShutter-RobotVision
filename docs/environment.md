# Recorded experiment environment

## Author-confirmed

The author confirms MATLAB R2025b, version 25.2.0.2998904, was used for the final MATLAB analyses. Required Computer Vision Toolbox functions include detectSURFFeatures, extractFeatures, matchFeatures, estimateFundamentalMatrix, estimateEssentialMatrix and relativeCameraPose; ORB validation also uses detectORBFeatures. Toolbox versions have not been supplied and are not inferred.

Confirmed original Colab environment: Python 3.13.15; PyTorch 2.11.0+cu130; SuperPoint; LightGlue package version 0.0. LightGlue reported dependencies: kornia, matplotlib, numpy, opencv-python, torch and torchvision. Exact dependency versions, GPU driver/runtime details and model-weight provenance remain unrecorded.

The original Colab environment used an editable LightGlue checkout at /content/LightGlue. The installed package reported version 0.0. The exact upstream Git commit was not preserved and therefore cannot be stated reliably.

## Not recovered — documented reproducibility limitations

Exact original LightGlue Git commit; complete original pip freeze; exact original GPU model; full toolbox/dependency versions and model-weight provenance are not recovered or author-confirmed. Historical xyz saved output displayed Tesla T4, but this does not establish the original GPU for every final run. No GPU model is invented.

The unavailable historical revision and other unrecovered provenance are disclosed limitations, not release blockers. Version 0.0 is not a unique upstream revision. The supplied desk notebook installs an unpinned current GitHub checkout, so a future run may use different code.

LightGlue is distributed under [Apache License 2.0](https://github.com/cvg/LightGlue/blob/main/LICENSE). No upstream LightGlue package source is vendored; notebooks import it as an external dependency. The repository MIT license applies only to author-owned material.

Capture available environment information using [environment capture instructions](environment_capture_instructions.md). Full end-to-end feature extraction and geometric reproduction has not been run during release preparation.
