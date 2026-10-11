# Final release-readiness audit

Repository ready for GitHub: **YES**, under the author's publication policy. This means packaging/structural requirements pass; it does not certify an end-to-end experimental rerun.

## Blockers before public release

None identified. Both final learned-feature notebooks, major final MATLAB analysis scripts, compact final summaries, MIT license and third-party notices are present.

## Documented limitations / non-blocking items

Exact original LightGlue upstream commit, complete original pip freeze and complete GPU/toolbox/model-weight provenance were not recovered. Confirmed environment versions are recorded. Complete learned-feature experiments were not rerun during packaging. Some exact figure plotting scripts are not preserved; all images and available underlying result evidence are documented. The conceptual illustration is image-only. Large raw PWM tables remain outside Git and have not yet been archived publicly. These are disclosed limitations under the author's release policy.

## Verification evidence

| Check | Result |
|---|---|
| Final xyz and desk notebooks exist | PASS |
| Expected scientific configuration | xyz PASS; desk PASS, programmatic static checks |
| Notebook JSON/imports/cells/output filenames | PASS for both |
| Configurable paths | PASS; first configuration cell centralizes dataset, extraction, outputs and checkout; xyz extraction/discovery roots agree |
| Saved notebook errors/tracebacks | None; all saved outputs/counts cleared |
| Scientific notebook edits | Path/output-cleanup only; exact reverse proof reconstructs original cells; original scientific function ASTs unchanged |
| Scientific results | All 66 CSVs, 21 publication assets and expected_results.md match original saved hashes |
| MATLAB modifications | No changes this turn; 29 existing path-only script hashes preserved, four path helpers unchanged |
| Original files outside repository | Remaining original content hashes and metadata unchanged; original xyz notebook was author-moved before prior cleanup |
| TUM data | No RGB/depth images, dataset directories or notebook image outputs/attachments |
| Credentials | No secret-pattern hits in public text/source files |
| Executable historical drive paths | None in MATLAB/Python/notebooks |
| User-documentation historical paths | Only explicitly labeled provenance/original-source locations in manifest/dataset/large-file documents |
| Local documentation links | All resolve |
| Reproduction script references | All exist; optional ignored setup_paths.m is documented as optional |
| Manifest repository/original-source paths | All resolve; current notebook sizes/hashes updated |
| Duplicate final scripts | No byte-identical MATLAB duplicates |
| Figure provenance | All 21 assets / 14 groups mapped; script, actual inputs versus supporting data, and limitations disclosed |
| Files over 50 MB | None in repository |
| Files over 100 MB | None |
| Large raw PWM tables | Excluded and ignored; xyz 44,231,633 bytes, desk 87,739,612 bytes outside repository |
| License | MIT for author-owned material; TUM/LightGlue/third-party rights distinguished; no upstream package source vendored |
| Environment | Author-confirmed MATLAB R2025b / 25.2.0.2998904; Python 3.13.15; PyTorch 2.11.0+cu130; LightGlue package 0.0, original editable /content/LightGlue |
| Git | Staged only; no commits, no remotes, no push |

Repository notebooks were structurally validated and their final experiment configuration was verified; the complete learned-feature experiments were not rerun during repository packaging.

See [notebook portability](docs/notebook_portability.md), [structural validation](docs/notebook_structural_validation.md), [figure provenance](docs/figure_provenance.md), [environment](docs/environment.md) and [review](REVIEW_NEEDED.md). Prior dataset-free MATLAB convergence and saved gain checks remain recorded in docs/path_portability.md. Scientific conclusions and values are unchanged.
