clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;
rng(1);

%% =========================================================
% EXPERIMENT 18D
% CLEAN vs PWM POSE-DEGRADATION ANALYSIS
%
% Purpose:
% Compare every PWM-perturbed pair against the EXACT SAME
% clean image pair.
%
% Outputs:
% 1. Rotation-error increase
% 2. Translation-direction-error increase
% 3. Pose-recovery failure rate
% 4. Median degradation
% 5. IQR
% 6. Bootstrap 95% confidence intervals
%% =========================================================

%% =========================================================
% 1. PATHS
%% =========================================================

datasetFolder = repoPaths.resultsRoot;

pwmFile = repository_input(repoPaths,'legacy_statistics/experiment18B_pairwise_results.csv');

cleanFile = repository_input(repoPaths,'legacy_statistics/experiment18C_clean_baseline_results.csv');

outputFolder = repository_output(repoPaths,'legacy_statistics');

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% =========================================================
% 2. LOAD RESULTS
%% =========================================================

PWM = readtable(pwmFile);

Clean = readtable(cleanFile);

fprintf('PWM rows loaded: %d\n',height(PWM));
fprintf('Clean pairs loaded: %d\n',height(Clean));

%% =========================================================
% 3. MATCH CLEAN BASELINE TO EACH PWM ROW
%
% PWM file contains:
% 50 pairs x 5 phases x 6 readouts = 1500 rows
%
% Each PWM row is matched to the same clean PairIndex.
%% =========================================================

nRows = height(PWM);

CleanRotationErrorDeg = ...
    nan(nRows,1);

CleanTranslationRawErrorDeg = ...
    nan(nRows,1);

CleanTranslationSignInvariantErrorDeg = ...
    nan(nRows,1);

CleanPoseRecovered = ...
    false(nRows,1);

GTTranslationMagnitude_m = ...
    nan(nRows,1);

CleanMatches = ...
    nan(nRows,1);

CleanEssentialInliers = ...
    nan(nRows,1);

for i = 1:nRows

    pairID = ...
        PWM.PairIndex(i);

    idx = ...
        find( ...
        Clean.PairIndex == pairID, ...
        1);

    if isempty(idx)

        error( ...
            'Clean pair %d not found.', ...
            pairID);

    end

    CleanRotationErrorDeg(i) = ...
        Clean.CleanRotationErrorDeg(idx);

    CleanTranslationRawErrorDeg(i) = ...
        Clean.CleanTranslationRawErrorDeg(idx);

    CleanTranslationSignInvariantErrorDeg(i) = ...
        Clean.CleanTranslationSignInvariantErrorDeg(idx);

    CleanPoseRecovered(i) = ...
        Clean.CleanPoseRecovered(idx);

    GTTranslationMagnitude_m(i) = ...
        Clean.GTTranslationMagnitude_m(idx);

    CleanMatches(i) = ...
        Clean.CleanMatches(idx);

    CleanEssentialInliers(i) = ...
        Clean.CleanEssentialInliers(idx);

end

%% =========================================================
% 4. PWM ERRORS
%% =========================================================

PWMRotationErrorDeg = ...
    PWM.RotationErrorDeg;

PWMTranslationRawErrorDeg = ...
    PWM.TranslationRawErrorDeg;

PWMTranslationSignInvariantErrorDeg = ...
    PWM.TranslationSignInvariantErrorDeg;

PWMPoseRecovered = ...
    PWM.PoseRecovered;

%% =========================================================
% 5. CLEAN -> PWM ERROR INCREASE
%
% Positive:
% PWM made the pose worse.
%
% Negative:
% PWM estimate happened to be better than clean.
%
% Failed PWM poses remain NaN because there is no valid
% recovered pose error to subtract.
%% =========================================================

DeltaRotationErrorDeg = ...
    PWMRotationErrorDeg - ...
    CleanRotationErrorDeg;

DeltaTranslationRawErrorDeg = ...
    PWMTranslationRawErrorDeg - ...
    CleanTranslationRawErrorDeg;

DeltaTranslationSignInvariantErrorDeg = ...
    PWMTranslationSignInvariantErrorDeg - ...
    CleanTranslationSignInvariantErrorDeg;

%% =========================================================
% 6. EXTRA DIAGNOSTIC VARIABLES
%% =========================================================

RotationWorsened = ...
    DeltaRotationErrorDeg > 0;

TranslationWorsened = ...
    DeltaTranslationRawErrorDeg > 0;

% Clean relative inlier reference
PWMInlierFractionOfClean = ...
    100 * ...
    PWM.PWMInliers ./ ...
    max(PWM.CleanInliers,1);

%% =========================================================
% 7. BUILD FULL PAIR-LEVEL TABLE
%% =========================================================

combined = PWM;

combined.CleanRotationErrorDeg = ...
    CleanRotationErrorDeg;

combined.CleanTranslationRawErrorDeg = ...
    CleanTranslationRawErrorDeg;

combined.CleanTranslationSignInvariantErrorDeg = ...
    CleanTranslationSignInvariantErrorDeg;

combined.CleanPoseRecovered = ...
    CleanPoseRecovered;

combined.GTTranslationMagnitude_m_Clean = ...
    GTTranslationMagnitude_m;

combined.CleanMatches = ...
    CleanMatches;

combined.CleanEssentialInliers = ...
    CleanEssentialInliers;

combined.DeltaRotationErrorDeg = ...
    DeltaRotationErrorDeg;

combined.DeltaTranslationRawErrorDeg = ...
    DeltaTranslationRawErrorDeg;

combined.DeltaTranslationSignInvariantErrorDeg = ...
    DeltaTranslationSignInvariantErrorDeg;

combined.RotationWorsened = ...
    RotationWorsened;

combined.TranslationWorsened = ...
    TranslationWorsened;

combined.PWMInlierFractionOfClean = ...
    PWMInlierFractionOfClean;

%% =========================================================
% 8. SAVE PAIR-LEVEL COMBINED RESULTS
%% =========================================================

pairOutputFile = fullfile( ...
    outputFolder, ...
    'experiment18D_pairwise_clean_vs_pwm.csv');

writetable( ...
    combined, ...
    pairOutputFile);

fprintf('\nSaved pair-level results:\n%s\n', ...
    pairOutputFile);

%% =========================================================
% 9. CONDITION DEFINITIONS
%% =========================================================

phaseOffsets = ...
    unique(PWM.PhaseOffset, ...
    'stable');

readoutTimesMs = ...
    unique(PWM.ReadoutTimeMs, ...
    'stable');

numPhases = ...
    numel(phaseOffsets);

numReadouts = ...
    numel(readoutTimesMs);

%% =========================================================
% 10. SUMMARY STORAGE
%% =========================================================

nConditions = ...
    numPhases * numReadouts;

PhaseOffset = ...
    zeros(nConditions,1);

ReadoutTimeMs = ...
    zeros(nConditions,1);

Npairs = ...
    zeros(nConditions,1);

NposeRecovered = ...
    zeros(nConditions,1);

PoseFailurePercent = ...
    zeros(nConditions,1);

MedianInlierRetentionPercent = ...
    nan(nConditions,1);

MedianPWMRotationErrorDeg = ...
    nan(nConditions,1);

MedianPWMTranslationRawErrorDeg = ...
    nan(nConditions,1);

MedianDeltaRotationErrorDeg = ...
    nan(nConditions,1);

MedianDeltaTranslationRawErrorDeg = ...
    nan(nConditions,1);

IQRDeltaRotationErrorDeg = ...
    nan(nConditions,1);

IQRDeltaTranslationRawErrorDeg = ...
    nan(nConditions,1);

RotationWorsenedPercent = ...
    nan(nConditions,1);

TranslationWorsenedPercent = ...
    nan(nConditions,1);

DeltaRotationCI95_Low = ...
    nan(nConditions,1);

DeltaRotationCI95_High = ...
    nan(nConditions,1);

DeltaTranslationCI95_Low = ...
    nan(nConditions,1);

DeltaTranslationCI95_High = ...
    nan(nConditions,1);

%% =========================================================
% 11. CONDITION SUMMARY
%% =========================================================

counter = 0;

for p = 1:numPhases

    for r = 1:numReadouts

        counter = counter + 1;

        phaseValue = ...
            phaseOffsets(p);

        readoutValue = ...
            readoutTimesMs(r);

        mask = ...
            PWM.PhaseOffset == phaseValue & ...
            PWM.ReadoutTimeMs == readoutValue;

        PhaseOffset(counter) = ...
            phaseValue;

        ReadoutTimeMs(counter) = ...
            readoutValue;

        Npairs(counter) = ...
            sum(mask);

        recoveredMask = ...
            mask & PWMPoseRecovered;

        NposeRecovered(counter) = ...
            sum(recoveredMask);

        PoseFailurePercent(counter) = ...
            100 * ...
            (1 - ...
            NposeRecovered(counter) / ...
            Npairs(counter));

        MedianInlierRetentionPercent(counter) = ...
            median( ...
            PWM.InlierRetentionPercent(mask), ...
            'omitnan');

        %% -------------------------------------------------
        % Absolute PWM pose errors
        %% -------------------------------------------------

        MedianPWMRotationErrorDeg(counter) = ...
            median( ...
            PWMRotationErrorDeg(recoveredMask), ...
            'omitnan');

        MedianPWMTranslationRawErrorDeg(counter) = ...
            median( ...
            PWMTranslationRawErrorDeg(recoveredMask), ...
            'omitnan');

        %% -------------------------------------------------
        % Clean-to-PWM degradation
        %% -------------------------------------------------

        dRot = ...
            DeltaRotationErrorDeg(recoveredMask);

        dTrans = ...
            DeltaTranslationRawErrorDeg(recoveredMask);

        MedianDeltaRotationErrorDeg(counter) = ...
            median( ...
            dRot, ...
            'omitnan');

        MedianDeltaTranslationRawErrorDeg(counter) = ...
            median( ...
            dTrans, ...
            'omitnan');

        %% -------------------------------------------------
        % IQR
        %% -------------------------------------------------

        IQRDeltaRotationErrorDeg(counter) = ...
            localIQR(dRot);

        IQRDeltaTranslationRawErrorDeg(counter) = ...
            localIQR(dTrans);

        %% -------------------------------------------------
        % Percent worsening
        %% -------------------------------------------------

        validRot = ...
            isfinite(dRot);

        if any(validRot)

            RotationWorsenedPercent(counter) = ...
                100 * ...
                mean( ...
                dRot(validRot) > 0);

        end

        validTrans = ...
            isfinite(dTrans);

        if any(validTrans)

            TranslationWorsenedPercent(counter) = ...
                100 * ...
                mean( ...
                dTrans(validTrans) > 0);

        end

        %% -------------------------------------------------
        % Bootstrap 95% CI of median degradation
        %% -------------------------------------------------

        [ ...
            DeltaRotationCI95_Low(counter), ...
            DeltaRotationCI95_High(counter)] = ...
            bootstrapMedianCI( ...
            dRot, ...
            2000);

        [ ...
            DeltaTranslationCI95_Low(counter), ...
            DeltaTranslationCI95_High(counter)] = ...
            bootstrapMedianCI( ...
            dTrans, ...
            2000);

    end

end

%% =========================================================
% 12. SUMMARY TABLE
%% =========================================================

summaryTable = table( ...
    PhaseOffset, ...
    ReadoutTimeMs, ...
    Npairs, ...
    NposeRecovered, ...
    PoseFailurePercent, ...
    MedianInlierRetentionPercent, ...
    MedianPWMRotationErrorDeg, ...
    MedianPWMTranslationRawErrorDeg, ...
    MedianDeltaRotationErrorDeg, ...
    IQRDeltaRotationErrorDeg, ...
    DeltaRotationCI95_Low, ...
    DeltaRotationCI95_High, ...
    RotationWorsenedPercent, ...
    MedianDeltaTranslationRawErrorDeg, ...
    IQRDeltaTranslationRawErrorDeg, ...
    DeltaTranslationCI95_Low, ...
    DeltaTranslationCI95_High, ...
    TranslationWorsenedPercent);

disp(summaryTable);

summaryOutputFile = fullfile( ...
    outputFolder, ...
    'experiment18D_condition_summary.csv');

writetable( ...
    summaryTable, ...
    summaryOutputFile);

fprintf('\nSaved condition summary:\n%s\n', ...
    summaryOutputFile);

%% =========================================================
% 13. PRINT IMPORTANT RESULTS
%% =========================================================

fprintf('\n\n========================================\n');
fprintf('EXPERIMENT 18D SUMMARY\n');
fprintf('========================================\n');

for i = 1:height(summaryTable)

    fprintf( ...
        ['Phase %.3f | Readout %2d ms | ' ...
         'Fail %.1f%% | ' ...
         'Median dRot %.2f deg | ' ...
         'Median dT %.2f deg\n'], ...
        summaryTable.PhaseOffset(i), ...
        summaryTable.ReadoutTimeMs(i), ...
        summaryTable.PoseFailurePercent(i), ...
        summaryTable.MedianDeltaRotationErrorDeg(i), ...
        summaryTable.MedianDeltaTranslationRawErrorDeg(i));

end

%% =========================================================
% 14. CREATE MATRICES FOR DIAGNOSTIC HEATMAPS
%% =========================================================

failureMatrix = ...
    nan(numPhases,numReadouts);

deltaRotMatrix = ...
    nan(numPhases,numReadouts);

deltaTransMatrix = ...
    nan(numPhases,numReadouts);

for p = 1:numPhases

    for r = 1:numReadouts

        idx = ...
            summaryTable.PhaseOffset == phaseOffsets(p) & ...
            summaryTable.ReadoutTimeMs == readoutTimesMs(r);

        failureMatrix(p,r) = ...
            summaryTable.PoseFailurePercent(idx);

        deltaRotMatrix(p,r) = ...
            summaryTable.MedianDeltaRotationErrorDeg(idx);

        deltaTransMatrix(p,r) = ...
            summaryTable.MedianDeltaTranslationRawErrorDeg(idx);

    end

end

%% =========================================================
% 15. DIAGNOSTIC FIGURE 1
% Pose failure
%% =========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    failureMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Rolling-Shutter Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase Offset (cycles)');

title( ...
    'Pose-Recovery Failure Rate (%)');

xticks(readoutTimesMs);

yticks(phaseOffsets);

%% =========================================================
% 16. DIAGNOSTIC FIGURE 2
% Median clean-to-PWM rotation degradation
%% =========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    deltaRotMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Rolling-Shutter Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase Offset (cycles)');

title( ...
    'Median Increase in Rotation Error (deg)');

xticks(readoutTimesMs);

yticks(phaseOffsets);

%% =========================================================
% 17. DIAGNOSTIC FIGURE 3
% Median clean-to-PWM translation degradation
%% =========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    deltaTransMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Rolling-Shutter Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase Offset (cycles)');

title( ...
    'Median Increase in Raw Translation-Direction Error (deg)');

xticks(readoutTimesMs);

yticks(phaseOffsets);

%% =========================================================
% 18. BASELINE MAGNITUDE vs PWM TRANSLATION DEGRADATION
%% =========================================================

valid = ...
    isfinite( ...
    combined.GTTranslationMagnitude_m_Clean) & ...
    isfinite( ...
    combined.DeltaTranslationRawErrorDeg);

figure;

scatter( ...
    combined.GTTranslationMagnitude_m_Clean(valid), ...
    combined.DeltaTranslationRawErrorDeg(valid), ...
    20, ...
    'filled');

xlabel( ...
    'Ground-Truth Translation Magnitude (m)');

ylabel( ...
    'Increase in Translation-Direction Error (deg)');

title( ...
    'PWM Translation Degradation vs Ground-Truth Baseline');

grid on;

%% =========================================================
% 19. OVERALL CORRELATION
%% =========================================================

if sum(valid) >= 3

    R = corrcoef( ...
        combined.GTTranslationMagnitude_m_Clean(valid), ...
        combined.DeltaTranslationRawErrorDeg(valid));

    fprintf( ...
        '\nCorrelation: GT baseline vs PWM translation-error increase = %.3f\n', ...
        R(1,2));

end

fprintf('\nAll Experiment 18D outputs saved to:\n');
fprintf('%s\n',outputFolder);

%% =========================================================
% LOCAL FUNCTION 1
% IQR WITHOUT REQUIRING A SPECIAL TOOLBOX
%% =========================================================

function value = localIQR(x)

x = ...
    x(isfinite(x));

if isempty(x)

    value = NaN;

    return;

end

x = sort(x);

q25 = ...
    localPercentile(x,25);

q75 = ...
    localPercentile(x,75);

value = ...
    q75-q25;

end

%% =========================================================
% LOCAL FUNCTION 2
% SIMPLE PERCENTILE
%% =========================================================

function value = localPercentile(x,p)

x = ...
    sort( ...
    x(isfinite(x)));

n = numel(x);

if n == 0

    value = NaN;

    return;

end

if n == 1

    value = x(1);

    return;

end

position = ...
    1 + ...
    (n-1) * ...
    p/100;

lowerIndex = ...
    floor(position);

upperIndex = ...
    ceil(position);

if lowerIndex == upperIndex

    value = ...
        x(lowerIndex);

else

    fraction = ...
        position-lowerIndex;

    value = ...
        x(lowerIndex) * ...
        (1-fraction) + ...
        x(upperIndex) * ...
        fraction;

end

end

%% =========================================================
% LOCAL FUNCTION 3
% BOOTSTRAP 95% CI FOR MEDIAN
%
% Uses simple resampling so Statistics Toolbox is not required.
%% =========================================================

function [ciLow,ciHigh] = ...
    bootstrapMedianCI( ...
    x, ...
    nBootstrap)

x = ...
    x(isfinite(x));

n = numel(x);

if n < 2

    ciLow = NaN;
    ciHigh = NaN;

    return;

end

bootstrapMedians = ...
    nan(nBootstrap,1);

for b = 1:nBootstrap

    sampleIndex = ...
        randi( ...
        n, ...
        n, ...
        1);

    sample = ...
        x(sampleIndex);

    bootstrapMedians(b) = ...
        median(sample);

end

bootstrapMedians = ...
    sort(bootstrapMedians);

ciLow = ...
    localPercentile( ...
    bootstrapMedians, ...
    2.5);

ciHigh = ...
    localPercentile( ...
    bootstrapMedians, ...
    97.5);

end