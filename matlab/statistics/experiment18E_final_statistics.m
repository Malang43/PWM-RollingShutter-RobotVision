clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;
rng(1);

%% =========================================================
% EXPERIMENT 18E
% FINAL UNCERTAINTY + STATISTICAL SUMMARY
%
% Uses Experiment 18D pair-level results.
%
% Reports for every phase x readout condition:
% 1. Pose failure rate + Wilson 95% CI
% 2. Median inlier retention + bootstrap 95% CI
% 3. Median clean-to-PWM rotation degradation + bootstrap 95% CI
% 4. Median clean-to-PWM translation degradation + bootstrap 95% CI
% 5. Number of recovered poses
%
% IMPORTANT:
% Pose-error statistics are calculated ONLY among successfully
% recovered poses.
%
% Pose-failure statistics use ALL 50 image pairs.
%% =========================================================

%% =========================================================
% 1. PATHS
%% =========================================================

datasetFolder = repoPaths.resultsRoot;

inputFile = repository_input(repoPaths,'legacy_statistics/experiment18D_pairwise_clean_vs_pwm.csv');

outputFolder = repository_output(repoPaths,'legacy_statistics');

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% =========================================================
% 2. LOAD PAIR-LEVEL DATA
%% =========================================================

T = readtable(inputFile);

fprintf('Pair-level rows loaded: %d\n',height(T));

%% =========================================================
% 3. CONDITION VALUES
%% =========================================================

phaseOffsets = ...
    unique(T.PhaseOffset,'stable');

readoutTimesMs = ...
    unique(T.ReadoutTimeMs,'stable');

numPhases = ...
    numel(phaseOffsets);

numReadouts = ...
    numel(readoutTimesMs);

numConditions = ...
    numPhases * numReadouts;

%% =========================================================
% 4. PHYSICAL PHASE OFFSET
%
% Fixed PWM frequency in Experiment 18 = 100 Hz
%
% delta t = delta phase / frequency
%% =========================================================

pwmFreq = 100;

phaseShiftMs = ...
    1000 * phaseOffsets / pwmFreq;

%% =========================================================
% 5. STORAGE
%% =========================================================

PhaseOffset = ...
    zeros(numConditions,1);

PhaseShiftMs = ...
    zeros(numConditions,1);

ReadoutTimeMs = ...
    zeros(numConditions,1);

Npairs = ...
    zeros(numConditions,1);

NposeRecovered = ...
    zeros(numConditions,1);

NposeFailed = ...
    zeros(numConditions,1);

%% Failure
PoseFailurePercent = ...
    nan(numConditions,1);

PoseFailureCI95_Low = ...
    nan(numConditions,1);

PoseFailureCI95_High = ...
    nan(numConditions,1);

%% Inlier retention
MedianInlierRetentionPercent = ...
    nan(numConditions,1);

InlierRetentionCI95_Low = ...
    nan(numConditions,1);

InlierRetentionCI95_High = ...
    nan(numConditions,1);

%% Rotation degradation
MedianDeltaRotationErrorDeg = ...
    nan(numConditions,1);

DeltaRotationCI95_Low = ...
    nan(numConditions,1);

DeltaRotationCI95_High = ...
    nan(numConditions,1);

IQRDeltaRotationErrorDeg = ...
    nan(numConditions,1);

%% Translation degradation
MedianDeltaTranslationErrorDeg = ...
    nan(numConditions,1);

DeltaTranslationCI95_Low = ...
    nan(numConditions,1);

DeltaTranslationCI95_High = ...
    nan(numConditions,1);

IQRDeltaTranslationErrorDeg = ...
    nan(numConditions,1);

%% Percentage of recovered poses that worsened
RotationWorsenedPercent = ...
    nan(numConditions,1);

TranslationWorsenedPercent = ...
    nan(numConditions,1);

%% Reliability flag
ConditionalErrorEstimateReliable = ...
    false(numConditions,1);

%% =========================================================
% 6. LOOP THROUGH CONDITIONS
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
            T.PhaseOffset == phaseValue & ...
            T.ReadoutTimeMs == readoutValue;

        conditionData = ...
            T(mask,:);

        %% ---------------------------------------------
        % Basic numbers
        %% ---------------------------------------------

        n = ...
            height(conditionData);
recovered = ...
    logical(conditionData.PoseRecovered);

        nRecovered = ...
            sum(recovered);

        nFailed = ...
            n - nRecovered;

        PhaseOffset(counter) = ...
            phaseValue;

        PhaseShiftMs(counter) = ...
            1000 * phaseValue / pwmFreq;

        ReadoutTimeMs(counter) = ...
            readoutValue;

        Npairs(counter) = ...
            n;

        NposeRecovered(counter) = ...
            nRecovered;

        NposeFailed(counter) = ...
            nFailed;

        %% =============================================
        % 7. POSE FAILURE + WILSON 95% CI
        %% =============================================

        failureFraction = ...
            nFailed / n;

        PoseFailurePercent(counter) = ...
            100 * failureFraction;

        [lowCI,highCI] = ...
            wilsonCI( ...
            nFailed, ...
            n, ...
            1.96);

        PoseFailureCI95_Low(counter) = ...
            100 * lowCI;

        PoseFailureCI95_High(counter) = ...
            100 * highCI;

        %% =============================================
        % 8. INLIER RETENTION
        %
        % All pairs included.
        %% =============================================

        inlierValues = ...
            conditionData.InlierRetentionPercent;

        inlierValues = ...
            inlierValues( ...
            isfinite(inlierValues));

        if ~isempty(inlierValues)

            MedianInlierRetentionPercent(counter) = ...
                median(inlierValues);

            [lowCI,highCI] = ...
                bootstrapMedianCI( ...
                inlierValues, ...
                5000);

            InlierRetentionCI95_Low(counter) = ...
                lowCI;

            InlierRetentionCI95_High(counter) = ...
                highCI;

        end

        %% =============================================
        % 9. ROTATION DEGRADATION
        %
        % ONLY successfully recovered PWM poses.
        %% =============================================

        dRot = ...
            conditionData.DeltaRotationErrorDeg( ...
            recovered);

        dRot = ...
            dRot(isfinite(dRot));

        if ~isempty(dRot)

            MedianDeltaRotationErrorDeg(counter) = ...
                median(dRot);

            IQRDeltaRotationErrorDeg(counter) = ...
                localIQR(dRot);

            [lowCI,highCI] = ...
                bootstrapMedianCI( ...
                dRot, ...
                5000);

            DeltaRotationCI95_Low(counter) = ...
                lowCI;

            DeltaRotationCI95_High(counter) = ...
                highCI;

            RotationWorsenedPercent(counter) = ...
                100 * ...
                mean(dRot > 0);

        end

        %% =============================================
        % 10. TRANSLATION DEGRADATION
        %
        % RAW translation direction.
        % ONLY successfully recovered PWM poses.
        %% =============================================

        dTrans = ...
            conditionData.DeltaTranslationRawErrorDeg( ...
            recovered);

        dTrans = ...
            dTrans(isfinite(dTrans));

        if ~isempty(dTrans)

            MedianDeltaTranslationErrorDeg(counter) = ...
                median(dTrans);

            IQRDeltaTranslationErrorDeg(counter) = ...
                localIQR(dTrans);

            [lowCI,highCI] = ...
                bootstrapMedianCI( ...
                dTrans, ...
                5000);

            DeltaTranslationCI95_Low(counter) = ...
                lowCI;

            DeltaTranslationCI95_High(counter) = ...
                highCI;

            TranslationWorsenedPercent(counter) = ...
                100 * ...
                mean(dTrans > 0);

        end

        %% =============================================
        % 11. CONDITIONAL ERROR RELIABILITY FLAG
        %
        % We use N >= 10 as a reporting flag only.
        % This is NOT a statistical validity threshold.
        %% =============================================

        ConditionalErrorEstimateReliable(counter) = ...
            nRecovered >= 10;

    end

end

%% =========================================================
% 12. FINAL STATISTICS TABLE
%% =========================================================

finalStats = table( ...
    PhaseOffset, ...
    PhaseShiftMs, ...
    ReadoutTimeMs, ...
    Npairs, ...
    NposeRecovered, ...
    NposeFailed, ...
    PoseFailurePercent, ...
    PoseFailureCI95_Low, ...
    PoseFailureCI95_High, ...
    MedianInlierRetentionPercent, ...
    InlierRetentionCI95_Low, ...
    InlierRetentionCI95_High, ...
    MedianDeltaRotationErrorDeg, ...
    IQRDeltaRotationErrorDeg, ...
    DeltaRotationCI95_Low, ...
    DeltaRotationCI95_High, ...
    RotationWorsenedPercent, ...
    MedianDeltaTranslationErrorDeg, ...
    IQRDeltaTranslationErrorDeg, ...
    DeltaTranslationCI95_Low, ...
    DeltaTranslationCI95_High, ...
    TranslationWorsenedPercent, ...
    ConditionalErrorEstimateReliable);

disp(finalStats);

%% =========================================================
% 13. SAVE FINAL STATISTICS CSV
%% =========================================================

statsFile = fullfile( ...
    outputFolder, ...
    'experiment18E_final_statistics.csv');

writetable( ...
    finalStats, ...
    statsFile);

fprintf('\nSaved final statistics:\n%s\n',statsFile);

%% =========================================================
% 14. PRINT REVIEWER-FRIENDLY SUMMARY
%% =========================================================

fprintf('\n\n========================================\n');
fprintf('EXPERIMENT 18E FINAL STATISTICAL SUMMARY\n');
fprintf('========================================\n');

for i = 1:height(finalStats)

    fprintf('\nPhase %.3f cycles (%.2f ms), Readout %d ms\n', ...
        finalStats.PhaseOffset(i), ...
        finalStats.PhaseShiftMs(i), ...
        finalStats.ReadoutTimeMs(i));

    fprintf( ...
        '  Pose failure: %.1f%% [95%% CI %.1f - %.1f]\n', ...
        finalStats.PoseFailurePercent(i), ...
        finalStats.PoseFailureCI95_Low(i), ...
        finalStats.PoseFailureCI95_High(i));

    fprintf( ...
        '  Median retention: %.2f%% [95%% CI %.2f - %.2f]\n', ...
        finalStats.MedianInlierRetentionPercent(i), ...
        finalStats.InlierRetentionCI95_Low(i), ...
        finalStats.InlierRetentionCI95_High(i));

    fprintf( ...
        '  Recovered poses: %d/%d\n', ...
        finalStats.NposeRecovered(i), ...
        finalStats.Npairs(i));

    if finalStats.NposeRecovered(i) > 0

        fprintf( ...
            '  Median delta rotation: %.2f deg [95%% CI %.2f - %.2f]\n', ...
            finalStats.MedianDeltaRotationErrorDeg(i), ...
            finalStats.DeltaRotationCI95_Low(i), ...
            finalStats.DeltaRotationCI95_High(i));

        fprintf( ...
            '  Median delta translation: %.2f deg [95%% CI %.2f - %.2f]\n', ...
            finalStats.MedianDeltaTranslationErrorDeg(i), ...
            finalStats.DeltaTranslationCI95_Low(i), ...
            finalStats.DeltaTranslationCI95_High(i));

    else

        fprintf( ...
            '  Pose-error statistics: not available because no poses recovered.\n');

    end

    if finalStats.NposeRecovered(i) < 10

        fprintf( ...
            '  NOTE: conditional pose-error estimate based on <10 recovered poses.\n');

    end

end

%% =========================================================
% 15. PREPARE MATRICES FOR FIGURES
%% =========================================================

failureMatrix = ...
    nan(numPhases,numReadouts);

failureLowMatrix = ...
    nan(numPhases,numReadouts);

failureHighMatrix = ...
    nan(numPhases,numReadouts);

retentionMatrix = ...
    nan(numPhases,numReadouts);

deltaRotMatrix = ...
    nan(numPhases,numReadouts);

deltaTransMatrix = ...
    nan(numPhases,numReadouts);

recoveredMatrix = ...
    nan(numPhases,numReadouts);

for p = 1:numPhases

    for r = 1:numReadouts

        idx = ...
            finalStats.PhaseOffset == phaseOffsets(p) & ...
            finalStats.ReadoutTimeMs == readoutTimesMs(r);

        failureMatrix(p,r) = ...
            finalStats.PoseFailurePercent(idx);

        failureLowMatrix(p,r) = ...
            finalStats.PoseFailureCI95_Low(idx);

        failureHighMatrix(p,r) = ...
            finalStats.PoseFailureCI95_High(idx);

        retentionMatrix(p,r) = ...
            finalStats.MedianInlierRetentionPercent(idx);

        deltaRotMatrix(p,r) = ...
            finalStats.MedianDeltaRotationErrorDeg(idx);

        deltaTransMatrix(p,r) = ...
            finalStats.MedianDeltaTranslationErrorDeg(idx);

        recoveredMatrix(p,r) = ...
            finalStats.NposeRecovered(idx);

    end

end

%% =========================================================
% 16. PUBLICATION FIGURE
%
% 4-panel summary:
% A = Pose failure
% B = Median inlier retention
% C = Rotation-error degradation
% D = Translation-error degradation
%% =========================================================

fig = figure( ...
    'Position', ...
    [100 100 1250 900]);

tiledlayout( ...
    2, ...
    2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

%% ---------------------------------------------------------
% PANEL A
%% ---------------------------------------------------------

nexttile;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    failureMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase (cycles)');

title( ...
    '(a) Pose Failure Rate (%)');

xticks(readoutTimesMs);
yticks(phaseOffsets);

for p = 1:numPhases

    for r = 1:numReadouts

        text( ...
            readoutTimesMs(r), ...
            phaseOffsets(p), ...
            sprintf('%.0f', ...
            failureMatrix(p,r)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end

%% ---------------------------------------------------------
% PANEL B
%% ---------------------------------------------------------

nexttile;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    retentionMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase (cycles)');

title( ...
    '(b) Median Inlier Retention (%)');

xticks(readoutTimesMs);
yticks(phaseOffsets);

for p = 1:numPhases

    for r = 1:numReadouts

        text( ...
            readoutTimesMs(r), ...
            phaseOffsets(p), ...
            sprintf('%.1f', ...
            retentionMatrix(p,r)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end

%% ---------------------------------------------------------
% PANEL C
%% ---------------------------------------------------------

nexttile;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    deltaRotMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase (cycles)');

title( ...
    '(c) Median Increase in Rotation Error (deg)');

xticks(readoutTimesMs);
yticks(phaseOffsets);

for p = 1:numPhases

    for r = 1:numReadouts

        if isfinite(deltaRotMatrix(p,r))

            labelText = ...
                sprintf( ...
                '%.1f\nN=%d', ...
                deltaRotMatrix(p,r), ...
                recoveredMatrix(p,r));

        else

            labelText = ...
                'FAIL';

        end

        text( ...
            readoutTimesMs(r), ...
            phaseOffsets(p), ...
            labelText, ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end

%% ---------------------------------------------------------
% PANEL D
%% ---------------------------------------------------------

nexttile;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    deltaTransMatrix);

set(gca,'YDir','normal');

colorbar;

xlabel( ...
    'Readout Time (ms)');

ylabel( ...
    'Relative PWM Phase (cycles)');

title( ...
    '(d) Median Increase in Translation Error (deg)');

xticks(readoutTimesMs);
yticks(phaseOffsets);

for p = 1:numPhases

    for r = 1:numReadouts

        if isfinite(deltaTransMatrix(p,r))

            labelText = ...
                sprintf( ...
                '%.1f\nN=%d', ...
                deltaTransMatrix(p,r), ...
                recoveredMatrix(p,r));

        else

            labelText = ...
                'FAIL';

        end

        text( ...
            readoutTimesMs(r), ...
            phaseOffsets(p), ...
            labelText, ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end

sgtitle( ...
    'PWM Phase–Readout Effects on Correspondence and Relative Pose');

%% =========================================================
% 17. SAVE PUBLICATION FIGURE
%% =========================================================

pngFile = fullfile( ...
    outputFolder, ...
    'Figure_phase_readout_pose_accuracy_statistics.png');

pdfFile = fullfile( ...
    outputFolder, ...
    'Figure_phase_readout_pose_accuracy_statistics.pdf');

exportgraphics( ...
    fig, ...
    pngFile, ...
    'Resolution',300);

exportgraphics( ...
    fig, ...
    pdfFile, ...
    'ContentType','vector');

fprintf('\nSaved publication figure:\n');
fprintf('%s\n',pngFile);
fprintf('%s\n',pdfFile);

%% =========================================================
% 18. SEPARATE FAILURE-RATE FIGURE WITH 95% CI
%
% This explicitly shows uncertainty.
%% =========================================================

fig2 = figure( ...
    'Position', ...
    [100 100 900 650]);

hold on;

for r = 1:numReadouts

    y = ...
        failureMatrix(:,r);

    yLow = ...
        failureLowMatrix(:,r);

    yHigh = ...
        failureHighMatrix(:,r);

    lowerError = ...
        y - yLow;

    upperError = ...
        yHigh - y;

    errorbar( ...
        phaseOffsets, ...
        y, ...
        lowerError, ...
        upperError, ...
        '-o', ...
        'LineWidth',1.4, ...
        'MarkerSize',6);

end

xlabel( ...
    'Relative PWM Phase Offset (cycles)');

ylabel( ...
    'Pose Failure Rate (%)');

title( ...
    'Pose Failure Rate with Wilson 95% Confidence Intervals');

legend( ...
    string(readoutTimesMs) + " ms", ...
    'Location','best');

ylim([0 105]);

xticks(phaseOffsets);

grid on;

hold off;

pngFile2 = fullfile( ...
    outputFolder, ...
    'Figure_pose_failure_Wilson_CI.png');

pdfFile2 = fullfile( ...
    outputFolder, ...
    'Figure_pose_failure_Wilson_CI.pdf');

exportgraphics( ...
    fig2, ...
    pngFile2, ...
    'Resolution',300);

exportgraphics( ...
    fig2, ...
    pdfFile2, ...
    'ContentType','vector');

%% =========================================================
% 19. SAVE LOW-N CONDITIONS SEPARATELY
%% =========================================================

lowN = ...
    finalStats( ...
    finalStats.NposeRecovered < 10, ...
    :);

lowNFile = fullfile( ...
    outputFolder, ...
    'experiment18E_low_recovered_pose_conditions.csv');

writetable( ...
    lowN, ...
    lowNFile);

fprintf('\nLow-N conditions saved:\n%s\n',lowNFile);

fprintf('\n========================================\n');
fprintf('EXPERIMENT 18E COMPLETE\n');
fprintf('========================================\n');

%% =========================================================
% LOCAL FUNCTION 1
% WILSON BINOMIAL CONFIDENCE INTERVAL
%% =========================================================

function [lower,upper] = ...
    wilsonCI(k,n,z)

if n == 0

    lower = NaN;
    upper = NaN;

    return;

end

p = ...
    k/n;

denominator = ...
    1 + ...
    z^2/n;

centre = ...
    p + ...
    z^2/(2*n);

adjustment = ...
    z * ...
    sqrt( ...
    p*(1-p)/n + ...
    z^2/(4*n^2));

lower = ...
    (centre-adjustment) / ...
    denominator;

upper = ...
    (centre+adjustment) / ...
    denominator;

lower = ...
    max(0,lower);

upper = ...
    min(1,upper);

end

%% =========================================================
% LOCAL FUNCTION 2
% BOOTSTRAP 95% CI FOR MEDIAN
%% =========================================================

function [ciLow,ciHigh] = ...
    bootstrapMedianCI(x,nBootstrap)

x = ...
    x(isfinite(x));

n = ...
    numel(x);

if n == 0

    ciLow = NaN;
    ciHigh = NaN;

    return;

end

if n == 1

    ciLow = NaN;
    ciHigh = NaN;

    return;

end

bootMedian = ...
    nan(nBootstrap,1);

for b = 1:nBootstrap

    indices = ...
        randi( ...
        n, ...
        n, ...
        1);

    bootMedian(b) = ...
        median( ...
        x(indices));

end

ciLow = ...
    localPercentile( ...
    bootMedian, ...
    2.5);

ciHigh = ...
    localPercentile( ...
    bootMedian, ...
    97.5);

end

%% =========================================================
% LOCAL FUNCTION 3
% IQR
%% =========================================================

function value = ...
    localIQR(x)

x = ...
    x(isfinite(x));

if isempty(x)

    value = NaN;

    return;

end

q25 = ...
    localPercentile( ...
    x, ...
    25);

q75 = ...
    localPercentile( ...
    x, ...
    75);

value = ...
    q75-q25;

end

%% =========================================================
% LOCAL FUNCTION 4
% PERCENTILE WITHOUT STATISTICS TOOLBOX
%% =========================================================

function value = ...
    localPercentile(x,p)

x = ...
    sort( ...
    x(isfinite(x)));

n = ...
    numel(x);

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
    (n-1)*p/100;

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