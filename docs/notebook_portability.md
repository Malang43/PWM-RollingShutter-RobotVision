# Notebook portability changes

Notebook edits were path/output-cleanup only. Scientific calculations, function bodies, parameter values, algorithms, pairing, thresholds, rounding and output basenames were preserved. Both notebooks have a new first configuration cell. Edit WORK_ROOT, DATASET_ZIP, DATASET_EXTRACT_ROOT, RESULTS_ROOT, LIGHTGLUE_DIR, RESULT_ARCHIVE_BASE and VERIFICATION_ROOT there, using absolute paths appropriate to the runtime.

By default WORK_ROOT is the initial notebook working directory, captured before checkout installation changes directory. Upload the specified dataset ZIP into WORK_ROOT, or configure DATASET_ZIP directly. Extraction and subsequent discovery use the same configured sequence tree. Result files remain under RESULTS_ROOT; verification artifacts use VERIFICATION_ROOT; archive/download paths use RESULT_ARCHIVE_BASE.

xyz: checkout/install commands use LIGHTGLUE_DIR; the initial install returns to WORK_ROOT for upload widgets. All dataset inspection/extraction/discovery paths now refer to the configured tree. The legacy duplicate unzip cell uses the existing Python zipfile extraction routine with the same archive/root, removing its unrelated relative destination. Verification PNG/CSV paths and result archive/download paths are configurable.

desk: the existing ZIP_PATH, EXTRACT_ROOT and OUTPUT_ROOT aliases use the new configuration. Dataset-not-found messages display the configured ZIP_PATH. Feature extraction, pair loops and match export were unchanged.

All saved code-cell outputs and execution counts were cleared, including xyz's 12 old error/traceback cells and upload widgets. Widget state metadata and any cell attachments were removed. This cleanup does not establish successful execution.

Exact source replacements were reversed programmatically to verify all original cells reconstruct exactly. Every original Python function AST is unchanged. Structural validation parsed both notebooks and checked final settings without installing dependencies, loading models or running experiments.

| Notebook | Modified original cells (zero-based, before new config cell) | Current SHA-256 |
|---|---|---|
| xyz | 1, 3, 4, 5, 6, 7, 8, 9, 10, 22, 34, 35, 36, 37 | 81630bd16f2dfdb01096aa852692cd0e9253b6392fe296297994aaf68d18461f |
| desk | 0 | 717a6b47fe7f004060e050c33042c3911adce77b44c66da5db724e6ae073df6e |

See [structural validation](notebook_structural_validation.md) and [configuration table](lightglue_notebook_verification.md).
