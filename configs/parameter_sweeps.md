# Parameter sweeps

Main phases [0, 0.125, 0.25, 0.5, 0.875]; readouts [5, 10, 15, 20, 25, 30] ms at 100 Hz, 1 ms exposure, 25% duty, 90% modulation and 100 samples.

Original supplementary scripts use the same phases and 20 ms readout:

| Experiment | Parameter | Values | Fixed photometric settings |
|---|---|---|---|
| 21 | Frequency, Hz | 100, 200, 300, 500, 1000 | 1 ms, 25% duty, 90% modulation |
| 22 | Exposure, ms | 1, 2, 5, 8, 10 | 100 Hz, 25% duty, 90% modulation |
| 23 | Duty, % | 10, 25, 50, 75, 90 | 100 Hz, 2 ms, 90% modulation |
| 24 | Modulation, % | 10, 30, 50, 70, 90 | 100 Hz, 2 ms, 25% duty |

Supplementary 2 ms settings do not replace the central 1 ms setting.
Geometry: [1.0, 1.5, 2.0] pixels x validFraction [0.4, 0.5, 0.6] = 9 combinations.
Convergence: [25, 50, 100, 200, 500, 1000] samples against exact analytical integration.
Pair selection: START_INDEX [50, 100, 200], GAP=3, 50 pairs per block.
