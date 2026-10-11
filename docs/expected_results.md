# Author supplied expected results

Transcribed unchanged from preparation request, not new estimates. Limited to evaluated simulation settings. Evidence mapped in [result evidence](result_evidence.md).

1. Primary fr1/xyz shared-backend comparison:
SURF failure = 66.733%
SuperPoint+LightGlue observed failure = 0.000%
SURF mean condition-level median inlier retention = 3.606%
LightGlue = 78.491%

2. fr1/desk shared-backend replication:
SURF failure = 71.333%
LightGlue failure = 0.000%
SURF retention = 3.429%
LightGlue retention = 76.217%

Together:
100 unique image pairs across two TUM sequences.
Do NOT describe 3000 pair-condition evaluations as 3000 independent scenes.

3. Geometric-threshold sensitivity:
RANSAC thresholds:
1.0, 1.5, 2.0 pixels

validFraction thresholds:
0.4, 0.5, 0.6

9 combinations total.

SURF failure range:
66.733%–68.133%

LightGlue failure range:
0.000%–0.133%

LightGlue-minus-SURF retention advantage:
74.753–75.059 percentage points

4. MATLAB–Python perturbation equivalence:
Complete final grid verified.
Maximum row-gain difference:
1.33226762955019e-15

Residual image differences:
maximum individual pixel difference = 1 8-bit intensity level
no differences > 1 level

5. Temporal-sampling convergence:
Compared discrete temporal integration against exact analytical rectangular-PWM exposure integration.

Sample counts:
25, 50, 100, 200, 500, 1000

At Ns = 100:
mean absolute row-gain error = 0.00068875
RMS error = 0.001883786703
95th percentile error = 0.004875
99th percentile error = 0.007875
maximum error = 0.009

6. Accuracy-based pose-success analysis, Experiment 18M:
1500 attempts per method.

Illustrative criteria:
rotation error < 5 degrees
raw translation-direction error < 15 degrees

Unrecovered cases count as unsuccessful.

SURF:
recovery = 33.267% (499/1500)
rotation < 5 deg = 24.733% (371/1500)
translation < 15 deg = 5.200% (78/1500)
combined success = 4.667% (70/1500)
median recovered rotation error = 3.513 deg
median recovered translation-direction error = 42.366 deg

SuperPoint+LightGlue:
recovery = 100.000% (1500/1500)
rotation < 5 deg = 97.133% (1457/1500)
translation < 15 deg = 56.533% (848/1500)
combined success = 56.133% (842/1500)
median recovered rotation error = 2.747 deg
median recovered translation-direction error = 13.210 deg

7. Pair-selection robustness, Experiment 18N:

START_INDEX = 50:
clean recovery = 100%
PWM failure = 74.133%
mean condition-level median retention = 2.3911%

START_INDEX = 100:
clean recovery = 100%
PWM failure = 67.400%
mean condition-level median retention = 3.6614%

START_INDEX = 200:
clean recovery = 98%
PWM failure = 74.733%
mean condition-level median retention = 4.3275%

Pattern correlation against START_INDEX=100:

START_INDEX 50:
failure correlation = 0.9045
retention correlation = 0.95046

START_INDEX 200:
failure correlation = 0.94286
retention correlation = 0.95389

Interpretation:
absolute aggregate rates change somewhat across pair blocks, but the main 30-condition failure and retention patterns remain highly similar.

8. Existing ORB validation:
mean failure across 30 conditions = 65.0%
mean inlier retention = 2.86%

9. Brightness-matched control:
uniform dimming did not reproduce the structured-PWM pose failures.

10. Mechanism analysis:
inter-frame RMS row-gain mismatch vs SURF pose-failure rate:
r = +0.642

Mismatch vs retention:
r = -0.414
