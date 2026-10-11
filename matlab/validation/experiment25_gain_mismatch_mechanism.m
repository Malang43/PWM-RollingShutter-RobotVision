clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');

close all;

rng(1);

%% =========================================================
% EXPERIMENT 25
% Final Mechanism Validation
%
% Inter-frame rolling-shutter row-gain mismatch
% versus:
%
% 1. SURF geometric-inlier retention
% 2. Relative-pose failure rate
%
% Data source:
% Experiments 21, 22, 23 and 24
%
% Dataset used in those experiments:
% TUM RGB-D fr1/xyz
%% =========================================================


%% =========================================================
% 1. CHECK RESULT FILES
% ==========================================================

file21 = repository_input(repoPaths,'parameter_sweeps/experiment21_frequency_phase_results.csv');

file22 = repository_input(repoPaths,'parameter_sweeps/experiment22_exposure_phase_results.csv');

file23 = repository_input(repoPaths,'parameter_sweeps/experiment23_duty_phase_results.csv');

file24 = repository_input(repoPaths,'parameter_sweeps/experiment24_modulation_phase_results.csv');


filesNeeded = {file21,file22,file23,file24};


for k = 1:length(filesNeeded)

    if ~isfile(filesNeeded{k})

        error( ...
            'Missing file: %s', ...
            filesNeeded{k});

    end

end


fprintf('All Experiment 21-24 CSV files found.\n');


%% =========================================================
% 2. LOAD PREVIOUS RESULTS
% ==========================================================

T21 = readtable(file21);

T22 = readtable(file22);

T23 = readtable(file23);

T24 = readtable(file24);


fprintf('Experiment 21 conditions: %d\n',height(T21));
fprintf('Experiment 22 conditions: %d\n',height(T22));
fprintf('Experiment 23 conditions: %d\n',height(T23));
fprintf('Experiment 24 conditions: %d\n',height(T24));


%% =========================================================
% 3. BUILD STANDARDIZED CONDITION TABLE
%
% Every row contains:
%
% Frequency
% Exposure
% Duty
% Readout
% Modulation depth
% Phase
% Retention
% Pose failure
%% ==========================================================

allRows = [];


%% =========================================================
% EXPERIMENT 21
%
% Frequency varied
%
% Fixed:
% exposure = 1 ms
% duty = 25%
% readout = 20 ms
% modulation = 90%
% ==========================================================

n = height(T21);

A = table;

A.FrequencyHz = ...
    T21.PWMFrequencyHz;

A.ExposureMs = ...
    ones(n,1)*1;

A.DutyPercent = ...
    ones(n,1)*25;

A.ReadoutMs = ...
    ones(n,1)*20;

A.ModulationPercent = ...
    ones(n,1)*90;

A.PhaseOffset = ...
    T21.PhaseOffset;

A.InlierRetentionPercent = ...
    T21.MeanSURFInlierRetentionPercent;

A.PoseFailurePercent = ...
    T21.SURFPoseFailurePercent;

A.SourceExperiment = ...
    repmat(21,n,1);

allRows = [allRows; A];


%% =========================================================
% EXPERIMENT 22
%
% Exposure varied
%
% Fixed:
% frequency = 100 Hz
% duty = 25%
% readout = 20 ms
% modulation = 90%
% ==========================================================

n = height(T22);

A = table;

A.FrequencyHz = ...
    ones(n,1)*100;

A.ExposureMs = ...
    T22.ExposureTimeMs;

A.DutyPercent = ...
    ones(n,1)*25;

A.ReadoutMs = ...
    ones(n,1)*20;

A.ModulationPercent = ...
    ones(n,1)*90;

A.PhaseOffset = ...
    T22.PhaseOffset;

A.InlierRetentionPercent = ...
    T22.MeanSURFInlierRetentionPercent;

A.PoseFailurePercent = ...
    T22.SURFPoseFailurePercent;

A.SourceExperiment = ...
    repmat(22,n,1);

allRows = [allRows; A];


%% =========================================================
% EXPERIMENT 23
%
% Duty varied
%
% Fixed:
% frequency = 100 Hz
% exposure = 2 ms
% readout = 20 ms
% modulation = 90%
% ==========================================================

n = height(T23);

A = table;

A.FrequencyHz = ...
    ones(n,1)*100;

A.ExposureMs = ...
    ones(n,1)*2;

A.DutyPercent = ...
    T23.DutyCyclePercent;

A.ReadoutMs = ...
    ones(n,1)*20;

A.ModulationPercent = ...
    ones(n,1)*90;

A.PhaseOffset = ...
    T23.PhaseOffset;

A.InlierRetentionPercent = ...
    T23.MeanSURFInlierRetentionPercent;

A.PoseFailurePercent = ...
    T23.SURFPoseFailurePercent;

A.SourceExperiment = ...
    repmat(23,n,1);

allRows = [allRows; A];


%% =========================================================
% EXPERIMENT 24
%
% Modulation depth varied
%
% Fixed:
% frequency = 100 Hz
% exposure = 2 ms
% duty = 25%
% readout = 20 ms
% ==========================================================

n = height(T24);

A = table;

A.FrequencyHz = ...
    ones(n,1)*100;

A.ExposureMs = ...
    ones(n,1)*2;

A.DutyPercent = ...
    ones(n,1)*25;

A.ReadoutMs = ...
    ones(n,1)*20;

A.ModulationPercent = ...
    T24.ModulationDepthPercent;

A.PhaseOffset = ...
    T24.PhaseOffset;

A.InlierRetentionPercent = ...
    T24.MeanSURFInlierRetentionPercent;

A.PoseFailurePercent = ...
    T24.SURFPoseFailurePercent;

A.SourceExperiment = ...
    repmat(24,n,1);

allRows = [allRows; A];


fprintf('\nTotal raw conditions = %d\n', ...
    height(allRows));


%% =========================================================
% 4. COMPUTE ROW-GAIN PROFILE METRICS
% ==========================================================

numConditions = height(allRows);

imageHeight = 480;

numSamples = 200;


GainMismatchRMS = ...
    zeros(numConditions,1);

GainMismatchMAE = ...
    zeros(numConditions,1);

GainCorrelation = ...
    zeros(numConditions,1);

RowGainStd1 = ...
    zeros(numConditions,1);

RowGainStd2 = ...
    zeros(numConditions,1);

MeanGain1 = ...
    zeros(numConditions,1);

MeanGain2 = ...
    zeros(numConditions,1);


for c = 1:numConditions

    frequency = ...
        allRows.FrequencyHz(c);

    exposureTime = ...
        allRows.ExposureMs(c)/1000;

    dutyCycle = ...
        allRows.DutyPercent(c)/100;

    readoutTime = ...
        allRows.ReadoutMs(c)/1000;

    modulationDepth = ...
        allRows.ModulationPercent(c)/100;

    phaseOffset = ...
        allRows.PhaseOffset(c);


    [gain1,gain2] = ...
        calculateRowGainProfiles( ...
        imageHeight, ...
        frequency, ...
        exposureTime, ...
        dutyCycle, ...
        modulationDepth, ...
        readoutTime, ...
        numSamples, ...
        phaseOffset);


    difference = gain1-gain2;


    GainMismatchRMS(c) = ...
        sqrt(mean(difference.^2));


    GainMismatchMAE(c) = ...
        mean(abs(difference));


    RowGainStd1(c) = ...
        std(gain1);


    RowGainStd2(c) = ...
        std(gain2);


    MeanGain1(c) = ...
        mean(gain1);


    MeanGain2(c) = ...
        mean(gain2);


    %% Correlation between the two row profiles

    if std(gain1) > 1e-12 && ...
            std(gain2) > 1e-12

        C = corrcoef(gain1,gain2);

        GainCorrelation(c) = C(1,2);

    else

        GainCorrelation(c) = 1;

    end

end


%% Add calculated metrics

allRows.GainMismatchRMS = ...
    GainMismatchRMS;

allRows.GainMismatchMAE = ...
    GainMismatchMAE;

allRows.GainCorrelation = ...
    GainCorrelation;

allRows.RowGainStd1 = ...
    RowGainStd1;

allRows.RowGainStd2 = ...
    RowGainStd2;

allRows.MeanGain1 = ...
    MeanGain1;

allRows.MeanGain2 = ...
    MeanGain2;


%% =========================================================
% 5. REMOVE DUPLICATE PHYSICAL CONDITIONS
%
% Some conditions were repeated between Experiments 21-24.
%
% We average their measured outcomes.
% ==========================================================

conditionMatrix = [ ...
    allRows.FrequencyHz, ...
    allRows.ExposureMs, ...
    allRows.DutyPercent, ...
    allRows.ReadoutMs, ...
    allRows.ModulationPercent, ...
    allRows.PhaseOffset];


[uniqueConditions,~,groupID] = ...
    unique(conditionMatrix,'rows','stable');


numUnique = ...
    size(uniqueConditions,1);


uniqueRetention = ...
    zeros(numUnique,1);

uniqueFailure = ...
    zeros(numUnique,1);

uniqueMismatchRMS = ...
    zeros(numUnique,1);

uniqueMismatchMAE = ...
    zeros(numUnique,1);

uniqueGainCorr = ...
    zeros(numUnique,1);

uniqueRowStd = ...
    zeros(numUnique,1);

uniqueMeanGain = ...
    zeros(numUnique,1);


for g = 1:numUnique

    idx = groupID==g;


    uniqueRetention(g) = ...
        mean( ...
        allRows.InlierRetentionPercent(idx), ...
        'omitnan');


    uniqueFailure(g) = ...
        mean( ...
        allRows.PoseFailurePercent(idx), ...
        'omitnan');


    uniqueMismatchRMS(g) = ...
        mean( ...
        allRows.GainMismatchRMS(idx), ...
        'omitnan');


    uniqueMismatchMAE(g) = ...
        mean( ...
        allRows.GainMismatchMAE(idx), ...
        'omitnan');


    uniqueGainCorr(g) = ...
        mean( ...
        allRows.GainCorrelation(idx), ...
        'omitnan');


    uniqueRowStd(g) = ...
        mean( ...
        (allRows.RowGainStd1(idx) + ...
        allRows.RowGainStd2(idx))/2, ...
        'omitnan');


    uniqueMeanGain(g) = ...
        mean( ...
        (allRows.MeanGain1(idx) + ...
        allRows.MeanGain2(idx))/2, ...
        'omitnan');

end


U = array2table( ...
    uniqueConditions, ...
    'VariableNames',{ ...
    'FrequencyHz', ...
    'ExposureMs', ...
    'DutyPercent', ...
    'ReadoutMs', ...
    'ModulationPercent', ...
    'PhaseOffset'});


U.GainMismatchRMS = ...
    uniqueMismatchRMS;

U.GainMismatchMAE = ...
    uniqueMismatchMAE;

U.GainCorrelation = ...
    uniqueGainCorr;

U.MeanRowGainStd = ...
    uniqueRowStd;

U.MeanIlluminationGain = ...
    uniqueMeanGain;

U.InlierRetentionPercent = ...
    uniqueRetention;

U.PoseFailurePercent = ...
    uniqueFailure;


fprintf( ...
    'Unique physical conditions = %d\n', ...
    height(U));


%% =========================================================
% 6. CORRELATION ANALYSIS
% ==========================================================

valid = ...
    isfinite(U.GainMismatchRMS) & ...
    isfinite(U.InlierRetentionPercent) & ...
    isfinite(U.PoseFailurePercent);


x = U.GainMismatchRMS(valid);

yRetention = ...
    U.InlierRetentionPercent(valid);

yFailure = ...
    U.PoseFailurePercent(valid);


%% Pearson correlation

C1 = corrcoef(x,yRetention);

rMismatchRetention = ...
    C1(1,2);


C2 = corrcoef(x,yFailure);

rMismatchFailure = ...
    C2(1,2);


%% Compare against ordinary row-gain STD

xStd = ...
    U.MeanRowGainStd(valid);


C3 = corrcoef(xStd,yRetention);

rStdRetention = ...
    C3(1,2);


C4 = corrcoef(xStd,yFailure);

rStdFailure = ...
    C4(1,2);


%% Gain-profile correlation

xCorr = ...
    U.GainCorrelation(valid);


C5 = corrcoef(xCorr,yRetention);

rProfileCorrRetention = ...
    C5(1,2);


C6 = corrcoef(xCorr,yFailure);

rProfileCorrFailure = ...
    C6(1,2);


%% =========================================================
% 7. PRINT MAIN RESULT
% ==========================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('EXPERIMENT 25 FINAL MECHANISM RESULTS\n');
fprintf('=============================================\n');

fprintf('\nNumber of unique conditions = %d\n', ...
    sum(valid));


fprintf('\n--- Gain Mismatch RMS ---\n');

fprintf( ...
    'Correlation with inlier retention = %.4f\n', ...
    rMismatchRetention);

fprintf( ...
    'Correlation with pose failure = %.4f\n', ...
    rMismatchFailure);


fprintf('\n--- Mean Row-Gain STD ---\n');

fprintf( ...
    'Correlation with inlier retention = %.4f\n', ...
    rStdRetention);

fprintf( ...
    'Correlation with pose failure = %.4f\n', ...
    rStdFailure);


fprintf('\n--- Inter-frame Gain Correlation ---\n');

fprintf( ...
    'Correlation with inlier retention = %.4f\n', ...
    rProfileCorrRetention);

fprintf( ...
    'Correlation with pose failure = %.4f\n', ...
    rProfileCorrFailure);


%% =========================================================
% 8. SIMPLE LINEAR FIT
% ==========================================================

fitRetention = ...
    polyfit(x,yRetention,1);

fitFailure = ...
    polyfit(x,yFailure,1);


xLine = ...
    linspace(min(x),max(x),200);


retentionLine = ...
    polyval(fitRetention,xLine);

failureLine = ...
    polyval(fitFailure,xLine);


%% =========================================================
% 9. SCATTER:
% MISMATCH RMS vs RETENTION
% ==========================================================

figure;

scatter( ...
    x, ...
    yRetention, ...
    55, ...
    'filled');

hold on;

plot( ...
    xLine, ...
    retentionLine, ...
    'LineWidth',2);


xlabel( ...
    'Inter-frame Row-Gain Mismatch RMS');

ylabel( ...
    'SURF Geometric-Inlier Retention (%)');

title( ...
    sprintf( ...
    'Gain Mismatch vs Inlier Retention, r = %.3f', ...
    rMismatchRetention));

grid on;


%% =========================================================
% 10. SCATTER:
% MISMATCH RMS vs POSE FAILURE
% ==========================================================

figure;

scatter( ...
    x, ...
    yFailure, ...
    55, ...
    'filled');

hold on;

plot( ...
    xLine, ...
    failureLine, ...
    'LineWidth',2);


xlabel( ...
    'Inter-frame Row-Gain Mismatch RMS');

ylabel( ...
    'Pose Failure Rate (%)');

title( ...
    sprintf( ...
    'Gain Mismatch vs Pose Failure, r = %.3f', ...
    rMismatchFailure));

ylim([0 105]);

grid on;


%% =========================================================
% 11. PROFILE CORRELATION vs RETENTION
% ==========================================================

figure;

scatter( ...
    U.GainCorrelation(valid), ...
    yRetention, ...
    55, ...
    'filled');

xlabel( ...
    'Correlation Between Frame Row-Gain Profiles');

ylabel( ...
    'SURF Geometric-Inlier Retention (%)');

title( ...
    sprintf( ...
    'Row-Profile Similarity vs Retention, r = %.3f', ...
    rProfileCorrRetention));

grid on;


%% =========================================================
% 12. PROFILE CORRELATION vs FAILURE
% ==========================================================

figure;

scatter( ...
    U.GainCorrelation(valid), ...
    yFailure, ...
    55, ...
    'filled');

xlabel( ...
    'Correlation Between Frame Row-Gain Profiles');

ylabel( ...
    'Pose Failure Rate (%)');

title( ...
    sprintf( ...
    'Row-Profile Similarity vs Pose Failure, r = %.3f', ...
    rProfileCorrFailure));

ylim([0 105]);

grid on;


%% =========================================================
% 13. COMPARE MISMATCH RMS vs ROW STD
%
% This tells us whether inter-frame mismatch is more useful
% than band strength measured separately in each image.
% ==========================================================

figure;

scatter( ...
    U.MeanRowGainStd(valid), ...
    yFailure, ...
    55, ...
    'filled');

xlabel( ...
    'Mean Individual-Frame Row-Gain STD');

ylabel( ...
    'Pose Failure Rate (%)');

title( ...
    sprintf( ...
    'Band Strength vs Pose Failure, r = %.3f', ...
    rStdFailure));

ylim([0 105]);

grid on;


%% =========================================================
% 14. BIN CONDITIONS BY MISMATCH
% ==========================================================

[sortedMismatch,order] = sort(x);

sortedRetention = ...
    yRetention(order);

sortedFailure = ...
    yFailure(order);


N = length(sortedMismatch);

numBins = 4;


binMismatch = ...
    nan(numBins,1);

binRetention = ...
    nan(numBins,1);

binFailure = ...
    nan(numBins,1);


edges = ...
    round(linspace(1,N+1,numBins+1));


for b = 1:numBins

    firstIndex = edges(b);

    lastIndex = edges(b+1)-1;


    if b == numBins
        lastIndex = N;
    end


    idx = firstIndex:lastIndex;


    binMismatch(b) = ...
        mean(sortedMismatch(idx));


    binRetention(b) = ...
        mean(sortedRetention(idx));


    binFailure(b) = ...
        mean(sortedFailure(idx));

end


%% =========================================================
% 15. BINNED RETENTION
% ==========================================================

figure;

plot( ...
    binMismatch, ...
    binRetention, ...
    '-o', ...
    'LineWidth',2, ...
    'MarkerSize',8);


xlabel( ...
    'Mean Gain-Mismatch RMS Within Bin');

ylabel( ...
    'Mean Inlier Retention (%)');

title( ...
    'Binned Relationship: Mismatch vs Feature Retention');

grid on;


%% =========================================================
% 16. BINNED POSE FAILURE
% ==========================================================

figure;

plot( ...
    binMismatch, ...
    binFailure, ...
    '-o', ...
    'LineWidth',2, ...
    'MarkerSize',8);


xlabel( ...
    'Mean Gain-Mismatch RMS Within Bin');

ylabel( ...
    'Mean Pose Failure Rate (%)');

title( ...
    'Binned Relationship: Mismatch vs Pose Failure');

ylim([0 100]);

grid on;


%% =========================================================
% 17. FIND MOST DANGEROUS CONDITIONS
% ==========================================================

[~,dangerOrder] = ...
    sortrows( ...
    [U.PoseFailurePercent ...
     U.GainMismatchRMS], ...
    [-1 -2]);


numShow = min(15,height(U));

dangerousConditions = ...
    U(dangerOrder(1:numShow),:);


fprintf('\n');
fprintf('=============================================\n');
fprintf('TOP DANGEROUS CONDITIONS\n');
fprintf('=============================================\n');

disp(dangerousConditions);


%% =========================================================
% 18. FIND SAFEST CONDITIONS
% ==========================================================

[~,safeOrder] = ...
    sortrows( ...
    [U.PoseFailurePercent ...
     -U.InlierRetentionPercent], ...
    [1 2]);


safeConditions = ...
    U(safeOrder(1:numShow),:);


fprintf('\n');
fprintf('=============================================\n');
fprintf('TOP SAFE CONDITIONS\n');
fprintf('=============================================\n');

disp(safeConditions);


%% =========================================================
% 19. SAVE FINAL CONDITION TABLE
% ==========================================================

writetable( ...
    U, ...
    repository_output(repoPaths,'mechanism_analysis/experiment25_all_unique_conditions.csv'));


%% =========================================================
% 20. SAVE CORRELATION SUMMARY
% ==========================================================

Metric = { ...
    'GainMismatchRMS'; ...
    'MeanRowGainStd'; ...
    'GainProfileCorrelation'};


CorrelationWithRetention = [ ...
    rMismatchRetention; ...
    rStdRetention; ...
    rProfileCorrRetention];


CorrelationWithPoseFailure = [ ...
    rMismatchFailure; ...
    rStdFailure; ...
    rProfileCorrFailure];


correlationSummary = table( ...
    Metric, ...
    CorrelationWithRetention, ...
    CorrelationWithPoseFailure);


disp(correlationSummary);


writetable( ...
    correlationSummary, ...
    repository_output(repoPaths,'mechanism_analysis/experiment25_correlation_summary.csv'));


save( ...
    repository_output(repoPaths,'mechanism_analysis/experiment25_mechanism_results.mat'), ...
    'U', ...
    'correlationSummary', ...
    'binMismatch', ...
    'binRetention', ...
    'binFailure');


fprintf('\n');
fprintf('Experiment 25 completed successfully.\n');


%% =========================================================
% LOCAL FUNCTION
% CALCULATE ROW-GAIN PROFILES
% ==========================================================

function [gain1,gain2] = ...
    calculateRowGainProfiles( ...
    imageHeight, ...
    pwmFreq, ...
    exposureTime, ...
    dutyCycle, ...
    modulationDepth, ...
    readoutTime, ...
    numSamples, ...
    phaseOffset)


rowTime = ...
    readoutTime/imageHeight;


gain1 = ...
    zeros(imageHeight,1);

gain2 = ...
    zeros(imageHeight,1);


for row = 1:imageHeight

    rowStart = ...
        (row-1)*rowTime;


    %% -----------------------------------------
    % Frame 1
    % ------------------------------------------

    times1 = ...
        linspace( ...
        rowStart, ...
        rowStart+exposureTime, ...
        numSamples);


    phase1 = ...
        mod( ...
        times1*pwmFreq, ...
        1);


    led1 = ...
        phase1 < dutyCycle;


    intensity1 = ...
        ones(size(times1));


    intensity1(~led1) = ...
        1-modulationDepth;


    gain1(row) = ...
        mean(intensity1);


    %% -----------------------------------------
    % Frame 2
    % ------------------------------------------

    times2 = ...
        linspace( ...
        rowStart, ...
        rowStart+exposureTime, ...
        numSamples);


    phase2 = ...
        mod( ...
        times2*pwmFreq + ...
        phaseOffset, ...
        1);


    led2 = ...
        phase2 < dutyCycle;


    intensity2 = ...
        ones(size(times2));


    intensity2(~led2) = ...
        1-modulationDepth;


    gain2(row) = ...
        mean(intensity2);

end

end