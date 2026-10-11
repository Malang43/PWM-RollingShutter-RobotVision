# Essential raw tables excluded from Git

Paths are explicitly original-source local paths, not required user locations. Configure external paths in matlab/setup_paths_example.m or ignored matlab/setup_paths.m. Generated raw data belongs under ignored reproduction_work; do not copy these tables into tracked results.

| Original filename | Original-source local path | Exact bytes | Decimal MB | Scientific role | Regenerable from repository scripts? |
|---|---|---:|---:|---|---|
| experiment18I_LightGlue_PWM_matches.csv | D:\try\FINAL_PAPER_RESULTS\experiment18I_shared_backend\LightGlue\experiment18I_LightGlue_PWM_matches.csv | 44231633 | 44.231633 | xyz PWM learned-feature raw correspondences for shared backend, sensitivity and 18M | Final xyz exporter code supplied; requires dataset/environment and configured paths; structurally verified, complete regeneration not rerun |
| fr1_desk_LightGlue_PWM_matches.csv | D:\try\FINAL_PAPER_RESULTS\experiment20_fr1_desk_LightGlue\fr1_desk_LightGlue_PWM_matches.csv | 87739612 | 87.739612 | desk PWM learned-feature raw correspondences for cross-sequence geometry | Final desk exporter code supplied; requires dataset/environment; fresh regeneration unverified |

Both files remain outside Git. xyz was conservatively excluded above 40 MB; desk exceeds 50 MB. MATLAB scripts consume but do not generate learned-feature matches.

Recommend a versioned Zenodo or OSF archive with stable identifier, checksums and provenance. Git LFS is an alternative if suitable for eventual hosting. No copy, upload, archive or LFS tracking performed. The repository contains compact derived result summaries and code/notebooks required to regenerate learned correspondences when source datasets and environment are available, subject to documented environment/reproduction limitations. Large raw tables may later be deposited in Zenodo or another research archive; not every raw output is currently hosted publicly.
