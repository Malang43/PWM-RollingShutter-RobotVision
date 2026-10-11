# Capture the original experimental environment

Run in the environment that produced the final results, not a newly installed environment. Save output as text and review before publication.

MATLAB Command Window:

    version
    ver

Python terminal (prefix with ! in Colab):

    python --version
    pip freeze

GPU, where applicable:

    nvidia-smi

From the LightGlue clone actually used:

    git rev-parse HEAD
    git status --short

Record local modifications alongside commit, OS, GPU, CUDA/driver details, model-weight provenance and xyz/desk notebook filenames. Current clones or installed MATLAB versions cannot recover missing original-run provenance.
