# Experimental design

The model evaluates simulated photometric ideal rectangular PWM interacting with rolling-shutter row timing, feature correspondence and calibrated pairwise relative pose. No physical LED-camera experiment or full SLAM trajectory evaluation is included.

Each sequence supplies 50 deterministic image pairs. Pair k uses timestamp-sorted indices 100+k-1 and 100+k-1+3 for k=1..50; convert one-based MATLAB indices in Python. Each block is reused over 30 phase/readout conditions, giving 1500 pair-condition evaluations per method per sequence. Across xyz and desk these are 100 unique image pairs, not 3000 independent scenes. Adjacent pairs can share frames; no additional independence is claimed.

Use [main parameters](../configs/main_experiment.md) and [sweeps](../configs/parameter_sweeps.md). The final common MATLAB backend applies the same geometry/validFraction criteria to raw matches from both methods. Threshold sensitivity reuses fixed-seed geometry across validFraction settings.

18K paired cluster bootstrap resamples PairID, carrying all 30 conditions and both methods: 5000 draws, seed 1805001. 18L recovered-case accuracy also uses pair-cluster bootstrap: 5000 draws, seed 1806001. Separate recovered-case statistics from 18M all-attempt success. Observed zero failure applies only to the evaluated finite simulation grid.
