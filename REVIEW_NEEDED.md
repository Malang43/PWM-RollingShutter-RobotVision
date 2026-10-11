# Release review

## Blockers before public release

None identified under the author's release-readiness policy. Final notebooks, analysis scripts, compact results and licenses are present. Scientific configuration, path portability, saved-output cleanup and repository hygiene checks pass.

## Documented limitations / non-blocking items

- Exact historical LightGlue Git commit and complete original dependency/toolbox/GPU/model-weight provenance were not recovered. Author-confirmed environment versions are recorded; unpinned current installs do not reproduce a unique historical checkout.
- Complete learned-feature and dataset-dependent experiments were not rerun during packaging. Structural checks do not certify end-to-end execution. Earlier path validation ran dataset-free convergence and saved row-gain comparison only.
- Conceptual Figure 1 is image-only. Exact supplementary plotting scripts are not all preserved; associated result evidence is available. Legacy Figures 2–7 include earlier analyses/embedded plotting tables; final Figure 8 uses the shared-backend script. See docs/figure_provenance.md.
- Two large PWM raw tables remain outside Git and are not yet publicly archived. Exporter code is supplied; full regeneration requires separately obtained datasets and a suitable environment.

Notebook edits were path/output-cleanup only; scientific functions, parameters and output basenames were preserved. All MATLAB scripts, saved CSVs/publication figures and final result values remain unchanged. MIT applies only to author-owned material; third-party rights remain separate. No commit, remote or push was performed.
