# MATLAB repository path modifications

Original files outside the repository untouched. Edits are input/output path assignments, helper bootstrap, path comments/logs and E_18M input file discovery; no scientific parameters, thresholds, seeds, metrics, algorithm or output basename changed.

Helpers: [setup_paths_example.m](../matlab/setup_paths_example.m), [repository_paths.m](../matlab/repository_paths.m), [repository_input.m](../matlab/repository_input.m), [repository_output.m](../matlab/repository_output.m). Set dataset placeholders and external raw PWM paths. resultsRoot holds saved inputs, outputRoot is under ignored reproduction_work. Local setup_paths.m ignored. Canonical output containment requires MATLAB with Java enabled.

Inputs prefer generated file, saved repository file, external excluded PWM file in that order. E_18M discovery targets the two intended LightGlue filenames rather than the mixed SURF/LightGlue directory. Legacy journal mechanism scan uses saved tables. Recorded replacements are exactly reversible to pre-edit full script text; original local function bodies are separately checked unchanged.

| Modified repository script | Path edits | Path-only | Current SHA-256 |
|---|---:|---|---|
| [E_01_export_SURF_raw_matches.m](../matlab\core\E_01_export_SURF_raw_matches.m) | 3 | Yes | d2386c756e4b1cb3b2e908fbd1fb1817d1c9f76e39ed35e15bf7779e2499db86 |
| [E_04_generate_final_shared_backend_figure.m](../matlab\figure_generation\E_04_generate_final_shared_backend_figure.m) | 4 | Yes | 01f6e64b572c11a0f474c5e64be8f18c183d27403cc9fb8279e4ba50885eabc2 |
| [regenerate_final_journal_figures.m](../matlab\figure_generation\regenerate_final_journal_figures.m) | 11 | Yes | 285c3e5a251cda882876608ddd0c2aa2ab18a5da4a163c4d54ae1e71145ceef0 |
| [E_02_shared_backend_SURF_vs_LightGlue.m](../matlab\shared_backend\E_02_shared_backend_SURF_vs_LightGlue.m) | 11 | Yes | db3b544240b45c721b08b8563e8978424b0ff4de986b21aa213a1741ff9901ea |
| [E_03_recover_shared_backend_results.m](../matlab\shared_backend\E_03_recover_shared_backend_results.m) | 5 | Yes | f1158bacdd3c0c34cfc96c107a2b90966ed1dc0f545abf9b2586a5f1281f6a58 |
| [E_20B_fr1_desk_shared_backend.m](../matlab\shared_backend\E_20B_fr1_desk_shared_backend.m) | 7 | Yes | d73236c89dc278025322d8f8d018545e9bc4975023642720e2360cf142507dd6 |
| [experiment18D_clean_vs_pwm_degradation.m](../matlab\statistics\experiment18D_clean_vs_pwm_degradation.m) | 6 | Yes | b8a070afa9046bb2d0a7b92f12ba1629d0e905e6a87058de6d5cf4e265adfc85 |
| [experiment18E_final_statistics.m](../matlab\statistics\experiment18E_final_statistics.m) | 5 | Yes | 51e25b7ac29f0367c648b72096e367687173c35d77b48f03b913f5f9c0793ca8 |
| [E_05_paired_bootstrap_shared_backend.m](../matlab\statistics\E_05_paired_bootstrap_shared_backend.m) | 3 | Yes | 26308f255635ea268615c54b486574f470654cd43718a4472c49170c00595548 |
| [E_06_shared_backend_pose_accuracy.m](../matlab\statistics\E_06_shared_backend_pose_accuracy.m) | 3 | Yes | b82a88b8882f987b61b0fb42ce0aaf72c12e0c10d6e534d38243694a0549051c |
| [E_18M_accuracy_based_pose_success.m](../matlab\statistics\E_18M_accuracy_based_pose_success.m) | 10 | Yes | aa999662cc099c4db3b3fb192db68bcda1bd14fcd477c2fe699f0301171fd1c9 |
| [compare_images_matlab_python.m](../matlab\validation\compare_images_matlab_python.m) | 3 | Yes | eda2a8af21f4c70c4e0483f777beb526ef79bc373e1e916cd92d471034fee1f0 |
| [compare_rowgain_matlab_python.m](../matlab\validation\compare_rowgain_matlab_python.m) | 3 | Yes | 88f87b3be7971763f71f49b2805ccedf76b6e69d3ac503ce42f9f0a75a2c5098 |
| [experiment16_brightness_matched_control.m](../matlab\validation\experiment16_brightness_matched_control.m) | 3 | Yes | fe9ea8ea7d6252d7e5b1e45db529c2a495b75026a3ad7d183cbed84b383d0b2e |
| [experiment18C_clean_baseline_pose_check.m](../matlab\validation\experiment18C_clean_baseline_pose_check.m) | 3 | Yes | ac45dc523798eb5eec5f8f13c99cc0c05084d6ae26919988ac951e603dcf2632 |
| [experiment18_phase_readout_ma.m](../matlab\validation\experiment18_phase_readout_ma.m) | 3 | Yes | 5a2c14fa1048c613e2eeaddfe7c6a2823cc22e3b31a00f2fb89db57c86d14413 |
| [experiment19_orb_phase_readout_map.m](../matlab\validation\experiment19_orb_phase_readout_map.m) | 4 | Yes | d6ec4bf2ff5a0f7b55bb5a7a7874f430766eceadec515c3882712957142e29e1 |
| [experiment21_frequency_phase_map.m](../matlab\validation\experiment21_frequency_phase_map.m) | 4 | Yes | d1cf3d0aa08dea6e3e7fdc41af3dfd3c83958883f10c4c54abb163d57f8e15ff |
| [experiment22_exposure_phase_map.m](../matlab\validation\experiment22_exposure_phase_map.m) | 4 | Yes | 787a8bee3b95932f121840349533043aaa1ecd695d3650d8a503cd38c4b53feb |
| [experiment23_duty_phase_map.m](../matlab\validation\experiment23_duty_phase_map.m) | 4 | Yes | 8e93b587fde957b362961ca6a99e8a35187d350f5407652df06eb30b91f440d0 |
| [experiment24_modulation_phase_map.m](../matlab\validation\experiment24_modulation_phase_map.m) | 4 | Yes | bca551457084cfae313a44aae117bb135b1e6932fa69553f0548b549db1473a7 |
| [experiment25_gain_mismatch_mechanism.m](../matlab\validation\experiment25_gain_mismatch_mechanism.m) | 8 | Yes | 89d336410ade5481a2dfeb3f2e0a2cb13b2f6f970c82a86bb071a67981ced59f |
| [E_02B_threshold_sensitivity.m](../matlab\validation\E_02B_threshold_sensitivity.m) | 9 | Yes | 31b8242731059a91b593ac572bdd3c0449ef424f40fcaa5cfb6b0bf436213c34 |
| [E_18N_pair_selection_robustness.m](../matlab\validation\E_18N_pair_selection_robustness.m) | 3 | Yes | 64544caf03b47752e38e6f1c72b697623394d51128399207d37aa163a5243c86 |
| [E_26_temporal_sampling_convergence.m](../matlab\validation\E_26_temporal_sampling_convergence.m) | 3 | Yes | 16c0f7c39332239239555cdc51a1186d70d23f992b3c8b83d79bf0294cddc895 |
| [verify_all1500_input_equivalence.m](../matlab\validation\verify_all1500_input_equivalence.m) | 5 | Yes | 1001b035d522ab903232758c7e83da7799ab885db6cff44e6d594577a0976414 |
| [verify_fullgrid_matlab_python_images.m](../matlab\validation\verify_fullgrid_matlab_python_images.m) | 5 | Yes | 6f6abba875e21a7ef7a2768729ab623f47b81ffc8cc0ad39826a31ceb14f6b48 |
| [verify_image_matlab.m](../matlab\validation\verify_image_matlab.m) | 4 | Yes | d6fce133a3a0bceff7a41a633dccf6a4a28079167ea7af88e7db8bbbb6a81a8a |
| [verify_rowgain_matlab.m](../matlab\validation\verify_rowgain_matlab.m) | 3 | Yes | 171ef25b1470fc61c48c8a72f70f8b7c8236092deac42ff03a9eb531d02671d4 |
