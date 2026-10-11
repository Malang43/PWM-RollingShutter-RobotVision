clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');

close all;

%% ============================================================
% EXPERIMENT 26
% TEMPORAL-SAMPLING CONVERGENCE OF PWM EXPOSURE INTEGRATION
%
% PURPOSE
% ------------------------------------------------------------
% Verify whether the final choice N_s = 100 temporal samples per
% row exposure is sufficiently converged.
%
% IMPORTANT
% ------------------------------------------------------------
% No dataset, images, SURF, LightGlue, RANSAC, or pose estimation
% are required.
%
% The discrete simulator used in the manuscript is compared directly
% against the EXACT analytical exposure integral of the ideal
% rectangular PWM waveform.
%
% Final model settings:
%   PWM frequency      = 100 Hz
%   Exposure           = 1 ms
%   Duty cycle         = 25 %
%   Modulation depth   = 90 %
%   Image height       = 480 rows
%
% Phase values:
%   [0, 0.125, 0.25, 0.5, 0.875]
%
% Readout times:
%   [5, 10, 15, 20, 25, 30] ms
%
% Tested temporal sample counts:
%   [25 50 100 200 500 1000]
%
% Exact reference:
%   Analytical integration of rectangular PWM waveform
%% ============================================================


%% ============================================================
% 1. OUTPUT FOLDER
%% ============================================================

baseRoot = repoPaths.outputRoot;

outRoot = repository_output(repoPaths,'temporal_convergence');

if ~exist(outRoot,'dir')
    mkdir(outRoot);
end


%% ============================================================
% 2. FINAL SIMULATION PARAMETERS
%% ============================================================

H = 480;

pwmFreq = 100;              % Hz

exposureTime = 0.001;       % 1 ms

dutyCycle = 0.25;           % 25 %

modulationDepth = 0.90;     % 90 %

offIntensity = ...
    1 - modulationDepth;


phaseOffsets = [ ...
    0 ...
    0.125 ...
    0.25 ...
    0.5 ...
    0.875];


readoutTimesMs = [ ...
    5 10 15 20 25 30];


readoutTimes = ...
    readoutTimesMs / 1000;


sampleCounts = [ ...
    25 ...
    50 ...
    100 ...
    200 ...
    500 ...
    1000];


fprintf('\n');
fprintf('=============================================\n');
fprintf('TEMPORAL-SAMPLING CONVERGENCE CHECK\n');
fprintf('=============================================\n');

fprintf('PWM frequency       : %.1f Hz\n', pwmFreq);
fprintf('Exposure            : %.3f ms\n', exposureTime*1000);
fprintf('Duty cycle          : %.1f %%\n', dutyCycle*100);
fprintf('Modulation depth    : %.1f %%\n', modulationDepth*100);
fprintf('Rows                : %d\n', H);

fprintf('\nSample counts:\n');
disp(sampleCounts);

fprintf('\nExact analytical integration is used as reference.\n');


%% ============================================================
% 3. STORAGE
%% ============================================================

conditionRows = table();

summaryRows = table();


%% ============================================================
% 4. LOOP OVER TEMPORAL SAMPLE COUNTS
%% ============================================================

for nIndex = 1:numel(sampleCounts)

    Ns = sampleCounts(nIndex);

    fprintf('\n');
    fprintf('=============================================\n');
    fprintf('N_s = %d\n', Ns);
    fprintf('=============================================\n');


    % Store every row error from every condition and both frames.
    allAbsErrors = [];

    worstError = -inf;

    worstPhase = NaN;

    worstReadout = NaN;

    worstFrame = NaN;

    worstRow = NaN;


    %% ========================================================
    % 5. LOOP THROUGH 30 FINAL CONDITIONS
    %% ========================================================

    for r = 1:numel(readoutTimes)

        readoutTime = ...
            readoutTimes(r);

        readoutMs = ...
            readoutTimesMs(r);


        for p = 1:numel(phaseOffsets)

            phase2 = ...
                phaseOffsets(p);


            %% ------------------------------------------------
            % FRAME 1
            % Controlled phase = 0
            %% ------------------------------------------------

            sampled1 = ...
                sampledRowGain( ...
                H, ...
                readoutTime, ...
                exposureTime, ...
                pwmFreq, ...
                dutyCycle, ...
                modulationDepth, ...
                0, ...
                Ns);


            exact1 = ...
                exactRowGain( ...
                H, ...
                readoutTime, ...
                exposureTime, ...
                pwmFreq, ...
                dutyCycle, ...
                modulationDepth, ...
                0);


            error1 = ...
                abs(sampled1 - exact1);


            %% ------------------------------------------------
            % FRAME 2
            % Controlled relative phase = phase2
            %% ------------------------------------------------

            sampled2 = ...
                sampledRowGain( ...
                H, ...
                readoutTime, ...
                exposureTime, ...
                pwmFreq, ...
                dutyCycle, ...
                modulationDepth, ...
                phase2, ...
                Ns);


            exact2 = ...
                exactRowGain( ...
                H, ...
                readoutTime, ...
                exposureTime, ...
                pwmFreq, ...
                dutyCycle, ...
                modulationDepth, ...
                phase2);


            error2 = ...
                abs(sampled2 - exact2);


            %% ------------------------------------------------
            % CONDITION-LEVEL STATISTICS
            %% ------------------------------------------------

            combinedError = [ ...
                error1;
                error2];


            meanAbsError = ...
                mean(combinedError);


            medianAbsError = ...
                median(combinedError);


            maxAbsError = ...
                max(combinedError);


            rmsError = ...
                sqrt(mean(combinedError.^2));


            meanExactGain = ...
                mean([exact1; exact2]);


            if meanExactGain > 0

                relativeMeanErrorPercent = ...
                    100 * ...
                    meanAbsError / ...
                    meanExactGain;

            else

                relativeMeanErrorPercent = NaN;

            end


            %% ------------------------------------------------
            % Find worst row/frame
            %% ------------------------------------------------

            [max1,row1] = max(error1);

            [max2,row2] = max(error2);


            if max1 >= max2

                localWorst = max1;

                localFrame = 1;

                localRow = row1;

            else

                localWorst = max2;

                localFrame = 2;

                localRow = row2;

            end


            if localWorst > worstError

                worstError = ...
                    localWorst;

                worstPhase = ...
                    phase2;

                worstReadout = ...
                    readoutMs;

                worstFrame = ...
                    localFrame;

                worstRow = ...
                    localRow;

            end


            allAbsErrors = [ ...
                allAbsErrors;
                combinedError];


            %% ------------------------------------------------
            % Save condition
            %% ------------------------------------------------

            newRow = table( ...
                Ns, ...
                phase2, ...
                readoutMs, ...
                meanAbsError, ...
                medianAbsError, ...
                rmsError, ...
                maxAbsError, ...
                relativeMeanErrorPercent, ...
                'VariableNames',{ ...
                'NumSamples', ...
                'Phase', ...
                'ReadoutMs', ...
                'MeanAbsoluteRowGainError', ...
                'MedianAbsoluteRowGainError', ...
                'RMSRowGainError', ...
                'MaximumAbsoluteRowGainError', ...
                'RelativeMeanErrorPercent'});


            conditionRows = [ ...
                conditionRows;
                newRow];

        end

    end


    %% ========================================================
    % 6. GLOBAL STATISTICS FOR THIS SAMPLE COUNT
    %% ========================================================

    globalMean = ...
        mean(allAbsErrors);


    globalMedian = ...
        median(allAbsErrors);


    globalRMS = ...
        sqrt(mean(allAbsErrors.^2));


    globalMaximum = ...
        max(allAbsErrors);


    percentile95 = ...
        prctile(allAbsErrors,95);


    percentile99 = ...
        prctile(allAbsErrors,99);


    summaryRow = table( ...
        Ns, ...
        globalMean, ...
        globalMedian, ...
        globalRMS, ...
        percentile95, ...
        percentile99, ...
        globalMaximum, ...
        worstPhase, ...
        worstReadout, ...
        worstFrame, ...
        worstRow, ...
        'VariableNames',{ ...
        'NumSamples', ...
        'MeanAbsoluteRowGainError', ...
        'MedianAbsoluteRowGainError', ...
        'RMSRowGainError', ...
        'P95AbsoluteRowGainError', ...
        'P99AbsoluteRowGainError', ...
        'MaximumAbsoluteRowGainError', ...
        'WorstPhase', ...
        'WorstReadoutMs', ...
        'WorstFrame', ...
        'WorstRow'});


    summaryRows = [ ...
        summaryRows;
        summaryRow];


    fprintf('Mean absolute error    = %.10f\n', globalMean);

    fprintf('Median absolute error  = %.10f\n', globalMedian);

    fprintf('RMS error              = %.10f\n', globalRMS);

    fprintf('95th percentile error  = %.10f\n', percentile95);

    fprintf('99th percentile error  = %.10f\n', percentile99);

    fprintf('Maximum absolute error = %.10f\n', globalMaximum);

    fprintf( ...
        'Worst case: phase %.3f, readout %d ms, frame %d, row %d\n', ...
        worstPhase, ...
        worstReadout, ...
        worstFrame, ...
        worstRow);

end


%% ============================================================
% 7. DISPLAY FINAL SUMMARY
%% ============================================================

fprintf('\n\n');
fprintf('============================================================\n');
fprintf('FINAL TEMPORAL-SAMPLING CONVERGENCE SUMMARY\n');
fprintf('============================================================\n');

disp(summaryRows);


%% ============================================================
% 8. SPECIFIC N_s = 100 RESULT
%% ============================================================

idx100 = ...
    summaryRows.NumSamples == 100;


if any(idx100)

    R100 = ...
        summaryRows(idx100,:);


    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('FINAL N_s = 100 CHECK\n');
    fprintf('============================================================\n');


    fprintf( ...
        'Mean absolute row-gain error = %.12f\n', ...
        R100.MeanAbsoluteRowGainError);


    fprintf( ...
        'Median absolute row-gain error = %.12f\n', ...
        R100.MedianAbsoluteRowGainError);


    fprintf( ...
        'RMS row-gain error = %.12f\n', ...
        R100.RMSRowGainError);


    fprintf( ...
        '95th percentile error = %.12f\n', ...
        R100.P95AbsoluteRowGainError);


    fprintf( ...
        '99th percentile error = %.12f\n', ...
        R100.P99AbsoluteRowGainError);


    fprintf( ...
        'Maximum absolute row-gain error = %.12f\n', ...
        R100.MaximumAbsoluteRowGainError);


    fprintf( ...
        'Worst condition: phase = %.3f, readout = %d ms, frame = %d, row = %d\n', ...
        R100.WorstPhase, ...
        R100.WorstReadoutMs, ...
        R100.WorstFrame, ...
        R100.WorstRow);

end


%% ============================================================
% 9. SAVE CSV FILES
%% ============================================================

summaryFile = fullfile( ...
    outRoot, ...
    'temporal_sampling_convergence_summary.csv');


conditionFile = fullfile( ...
    outRoot, ...
    'temporal_sampling_convergence_by_condition.csv');


writetable( ...
    summaryRows, ...
    summaryFile);


writetable( ...
    conditionRows, ...
    conditionFile);


fprintf('\nSaved:\n');

fprintf('%s\n', summaryFile);

fprintf('%s\n', conditionFile);


%% ============================================================
% 10. CONVERGENCE PLOT
%% ============================================================

figure;

loglog( ...
    summaryRows.NumSamples, ...
    summaryRows.MeanAbsoluteRowGainError, ...
    '-o', ...
    'LineWidth',1.5);

hold on;

loglog( ...
    summaryRows.NumSamples, ...
    summaryRows.MaximumAbsoluteRowGainError, ...
    '-s', ...
    'LineWidth',1.5);

xlabel( ...
    'Temporal samples per row exposure, N_s');

ylabel( ...
    'Absolute row-gain error');

title( ...
    'Temporal-Sampling Convergence Against Exact PWM Integration');

legend( ...
    'Mean absolute error', ...
    'Maximum absolute error', ...
    'Location','best');

grid on;


plotFile = fullfile( ...
    outRoot, ...
    'temporal_sampling_convergence.png');


exportgraphics( ...
    gcf, ...
    plotFile, ...
    'Resolution',300);


fprintf('%s\n', plotFile);


%% ============================================================
% 11. OPTIONAL: COMPARE SUCCESSIVE SAMPLE COUNTS
%% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('ERROR REDUCTION WITH INCREASING N_s\n');
fprintf('============================================================\n');


for k = 2:height(summaryRows)

    previousError = ...
        summaryRows.MeanAbsoluteRowGainError(k-1);


    currentError = ...
        summaryRows.MeanAbsoluteRowGainError(k);


    reduction = ...
        100 * ...
        (previousError-currentError) / previousError;


    fprintf( ...
        '%d -> %d samples: mean-error reduction = %.3f%%\n', ...
        summaryRows.NumSamples(k-1), ...
        summaryRows.NumSamples(k), ...
        reduction);

end


fprintf('\n');
fprintf('============================================================\n');
fprintf('TEMPORAL-SAMPLING CONVERGENCE CHECK COMPLETE\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTION 1
% DISCRETE TEMPORAL-SAMPLING MODEL
%
% This exactly follows the final simulation convention:
%
% linspace(rowStart, rowStart + exposureTime, Ns)
%
% Every temporal sample receives equal weight.
%% ============================================================

function gain = sampledRowGain( ...
    H, ...
    readoutTime, ...
    exposureTime, ...
    pwmFreq, ...
    dutyCycle, ...
    modulationDepth, ...
    phaseOffset, ...
    Ns)


rowTime = ...
    readoutTime / H;


gain = zeros( ...
    H, ...
    1);


for row = 1:H

    rowStart = ...
        (row-1) * rowTime;


    sampleTimes = ...
        linspace( ...
        rowStart, ...
        rowStart + exposureTime, ...
        Ns);


    phase = mod( ...
        sampleTimes*pwmFreq + ...
        phaseOffset, ...
        1);


    ledOn = ...
        phase < dutyCycle;


    intensity = ...
        ones(size(sampleTimes));


    intensity(~ledOn) = ...
        1 - modulationDepth;


    gain(row) = ...
        mean(intensity);

end

end


%% ============================================================
% LOCAL FUNCTION 2
% EXACT ANALYTICAL PWM EXPOSURE INTEGRATION
%
% For rectangular PWM:
%
% L(t) = (1-M) + M*s(t)
%
% Therefore:
%
% exact gain =
% (1-M) + M * exact_ON_fraction
%
% The exact ON fraction is calculated analytically in PWM-cycle
% coordinates, so no temporal discretization is used here.
%% ============================================================

function gain = exactRowGain( ...
    H, ...
    readoutTime, ...
    exposureTime, ...
    pwmFreq, ...
    dutyCycle, ...
    modulationDepth, ...
    phaseOffset)


rowTime = ...
    readoutTime / H;


gain = zeros( ...
    H, ...
    1);


offIntensity = ...
    1 - modulationDepth;


for row = 1:H

    rowStart = ...
        (row-1) * rowTime;


    t0 = ...
        rowStart;


    t1 = ...
        rowStart + exposureTime;


    % Convert time interval to PWM cycle coordinates.
    u0 = ...
        pwmFreq*t0 + phaseOffset;


    u1 = ...
        pwmFreq*t1 + phaseOffset;


    % Exact amount of ON-state interval measured in PWM cycles.
    onCycles = ...
        cumulativeOnCycles( ...
        u1, ...
        dutyCycle) ...
        - ...
        cumulativeOnCycles( ...
        u0, ...
        dutyCycle);


    totalCycles = ...
        u1 - u0;


    if totalCycles <= 0

        onFraction = 0;

    else

        onFraction = ...
            onCycles / totalCycles;

    end


    % Numerical safety
    onFraction = ...
        min( ...
        max(onFraction,0), ...
        1);


    gain(row) = ...
        offIntensity ...
        + modulationDepth*onFraction;

end

end


%% ============================================================
% LOCAL FUNCTION 3
% CUMULATIVE ON-TIME IN PWM-CYCLE COORDINATES
%
% Returns exact integral of:
%
% 1{ mod(u,1) < dutyCycle }
%
% from cycle-coordinate 0 to x.
%% ============================================================

function value = cumulativeOnCycles( ...
    x, ...
    dutyCycle)


wholeCycles = ...
    floor(x);


fractionalCycle = ...
    x - wholeCycles;


value = ...
    wholeCycles*dutyCycle ...
    + min( ...
        fractionalCycle, ...
        dutyCycle);

end