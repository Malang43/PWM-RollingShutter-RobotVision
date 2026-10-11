# Dataset setup

Download rgbd_dataset_freiburg1_xyz and rgbd_dataset_freiburg1_desk independently from the [official TUM RGB-D download page](https://webshare.cvg.cit.tum.de/g/rgbd/dataset/). Follow the benchmark's citation and usage terms.

Extract outside this repository; preserve RGB timestamps/filenames and groundtruth.txt. Selected pairwise workflows use RGB and ground truth, not depth. Do not redistribute benchmark images here.

Timestamp-sort RGB files as original scripts do. xyz workflows assert 798 images. START_INDEX=100, GAP=3, 50 pairs; convert MATLAB one-based indexing in Python. Keep 640 x 480 images with no resizing.

Original-source paths D:\try\rgbd_dataset_freiburg1_xyz and D:\try\rgbd_dataset_freiburg1_desk are provenance only. Set paths.tumXYZ/paths.tumDesk in setup_paths_example.m or ignored matlab/setup_paths.m; outputs go under reproduction_work; see [reproduction guide](reproduction_guide.md).
