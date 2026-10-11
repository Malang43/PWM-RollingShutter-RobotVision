# Result definitions

Operational pose recovery includes validFraction >= 0.5; recovery alone does not certify accurate pose. Failure rates use all attempts. Consult scripts for failure stages and degeneracies.

Inlier retention compares perturbed geometric inliers against each clean pair reference. The headline statistic is the mean across conditions of condition-level median retention, not a pooled median or average of correspondences. Preserve original invalid/undefined clean-reference handling.

18L is conditional on recovered cases. 18M combined accuracy success uses all 1500 attempts per method: recovered AND rotation error <5 degrees AND raw translation-direction error <15 degrees. Unrecovered attempts are unsuccessful. Do not substitute sign-invariant translation error.

Threshold retention advantages are percentage points. PairID is the repeated-condition sampling unit for paired bootstrap. Original 18, shared backend 18J and alternative blocks 18N are distinct analyses; do not alter differing rates to reconcile them. [Expected results](expected_results.md) preserves supplied numbers.
