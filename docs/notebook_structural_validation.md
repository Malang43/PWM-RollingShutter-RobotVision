# Notebook structural validation

Repository notebooks were structurally validated and their final experiment configuration was verified; the complete learned-feature experiments were not rerun during repository packaging.

| Structural check | xyz | desk |
|---|---|---|
| Notebook JSON loads and re-parses | PASS | PASS |
| Required torch/numpy/PIL/LightGlue/pandas imports and scientific cells | PASS | PASS |
| Static source parses after substituting notebook shell/magic syntax for inspection | PASS | PASS |
| Scientific parameters, model constructors, resize=None, linspace and rint | PASS | PASS |
| Configurable dataset/extraction/output paths in first cell | PASS | PASS |
| Dataset extraction and discovery use same configured tree | PASS | PASS |
| Final clean/PWM output filenames defined | PASS | PASS |
| No saved code-cell outputs/errors/tracebacks | PASS | PASS |
| Original scientific function bodies unchanged | PASS | PASS |
| Exact reverse proof of original cell source except added path config | PASS | PASS |

Verified constants: NUM_SAMPLES=100, START_INDEX=99 (MATLAB 100), GAP=3, N_PAIRS=50, phases=[0,0.125,0.25,0.5,0.875], readouts=[5,10,15,20,25,30] ms, PWM=100 Hz, exposure=1 ms, duty=0.25, modulation=0.90, SuperPoint(max_num_keypoints=2048), LightGlue(features="superpoint"), resize=None. RGB native dimensions remain 640x480. The xyz sample function retains num_samples with NUM_SAMPLES passed as 100; desk uses NUM_SAMPLES directly. Sampling remains endpoint-inclusive np.linspace; rounding remains np.rint before uint8 conversion.

Output basenames: xyz experiment18I_LightGlue_clean_matches.csv and experiment18I_LightGlue_PWM_matches.csv; desk fr1_desk_LightGlue_clean_matches.csv and fr1_desk_LightGlue_PWM_matches.csv. Summary/verification filenames are preserved. Validation is static and does not certify model installation, runtime dependency compatibility or dataset-dependent execution.
