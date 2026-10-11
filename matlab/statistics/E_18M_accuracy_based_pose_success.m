clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;

%% ============================================================
% EXPERIMENT 18M
% ACCURACY-BASED POSE SUCCESS OVER ALL ATTEMPTS
%
% PURPOSE
% ------------------------------------------------------------
% Evaluate pose quality over ALL 1500 attempts per method.
%
% Success definitions:
%
% 1) Recovery success
%
% 2) Rotation success:
%       recovered AND rotation error < 5 deg
%
% 3) Translation success:
%       recovered AND translation-direction error < 15 deg
%
% 4) Combined accuracy success:
%       recovered
%       AND rotation error < 5 deg
%       AND translation-direction error < 15 deg
%
% Unrecovered cases count as unsuccessful.
%
% Dataset:
% TUM fr1/xyz
%
% No SURF or LightGlue feature extraction is repeated.
% Existing raw correspondence CSV files are reused.
%% ============================================================


%% ============================================================
% 1. PATHS
%% ============================================================

baseRoot = repoPaths.resultsRoot;

sharedRoot = repoPaths.resultsRoot;

surfRoot = fullfile(repoPaths.resultsRoot,'raw_correspondences','xyz');

lgRoot = fullfile(repoPaths.resultsRoot,'raw_correspondences','xyz');

datasetRoot = ...
    repoPaths.tumXYZ;

gtFile = fullfile( ...
    datasetRoot, ...
    'groundtruth.txt');

outRoot = repository_output(repoPaths,'accuracy_success');


if ~exist(outRoot,'dir')
    mkdir(outRoot);
end


assert(isfolder(surfRoot), ...
    'SURF folder not found:\n%s', ...
    surfRoot);

assert(isfolder(lgRoot), ...
    'LightGlue folder not found:\n%s', ...
    lgRoot);

assert(isfile(gtFile), ...
    'Ground-truth file not found:\n%s', ...
    gtFile);


%% ============================================================
% 2. SETTINGS
%% ============================================================

N_PAIRS = 50;
START_INDEX = 100;
GAP = 3;


%% ============================================================
% LOAD RGB TIMESTAMPS DIRECTLY FROM DATASET
%% ============================================================

rgbFolder = fullfile( ...
    datasetRoot, ...
    'rgb');


rgbFiles = dir( ...
    fullfile( ...
    rgbFolder, ...
    '*.png'));


rgbTimes = zeros( ...
    numel(rgbFiles), ...
    1);


for k = 1:numel(rgbFiles)

    [~,nm,~] = fileparts( ...
        rgbFiles(k).name);

    rgbTimes(k) = ...
        str2double(nm);

end


[rgbTimes,order] = sort(rgbTimes);

rgbFiles = rgbFiles(order);


assert( ...
    numel(rgbTimes) >= START_INDEX + N_PAIRS - 1 + GAP, ...
    'Not enough RGB images for selected pairs.');


fprintf( ...
    'RGB timestamps loaded: %d\n', ...
    numel(rgbTimes));

phases = [ ...
    0 ...
    0.125 ...
    0.25 ...
    0.5 ...
    0.875];

readoutsMs = [ ...
    5 10 15 20 25 30];


expectedEvaluations = ...
    N_PAIRS * ...
    numel(phases) * ...
    numel(readoutsMs);


ROT_THRESHOLD_DEG = 5;

TRANS_THRESHOLD_DEG = 15;


NUM_TRIALS = 2000;

DISTANCE_THRESHOLD = 1.5;

CONFIDENCE = 99.9;

VALID_FRACTION_THRESHOLD = 0.5;


%% ============================================================
% 3. CAMERA INTRINSICS
%% ============================================================

intrinsics = cameraIntrinsics( ...
    [517.3 516.5], ...
    [318.6 255.3], ...
    [480 640]);


%% ============================================================
% 4. LOAD TUM GROUND TRUTH
%% ============================================================

gtData = readmatrix( ...
    gtFile, ...
    'FileType','text', ...
    'CommentStyle','#');


gtData = ...
    gtData(~any(isnan(gtData),2),:);


gtTime = ...
    gtData(:,1);


fprintf('\n');
fprintf('==============================================\n');
fprintf('EXPERIMENT 18M\n');
fprintf('ACCURACY-BASED POSE SUCCESS\n');
fprintf('==============================================\n');

fprintf( ...
    'Ground-truth poses loaded: %d\n', ...
    size(gtData,1));

fprintf( ...
    'Rotation threshold: %.1f deg\n', ...
    ROT_THRESHOLD_DEG);

fprintf( ...
    'Translation threshold: %.1f deg\n', ...
    TRANS_THRESHOLD_DEG);

fprintf( ...
    'Expected PWM evaluations/method: %d\n', ...
    expectedEvaluations);


%% ============================================================
% 5. USE KNOWN SURF FILES DIRECTLY
%% ============================================================

surfCleanFile = repository_input(repoPaths,'raw_correspondences/xyz/SURF_clean_matches.csv');

surfPWMFile = repository_input(repoPaths,'raw_correspondences/xyz/SURF_PWM_matches.csv');


assert(isfile(surfCleanFile), ...
    'Missing file:\n%s', ...
    surfCleanFile);

assert(isfile(surfPWMFile), ...
    'Missing file:\n%s', ...
    surfPWMFile);


fprintf('\nSURF clean file:\n%s\n',surfCleanFile);

fprintf('\nSURF PWM file:\n%s\n',surfPWMFile);


%% ============================================================
% 6. FIND LIGHTGLUE FILES
%% ============================================================

lgFiles = [dir(repository_input(repoPaths,'raw_correspondences/xyz/experiment18I_LightGlue_clean_matches.csv')); ...
    dir(repository_input(repoPaths,'raw_correspondences/xyz/experiment18I_LightGlue_PWM_matches.csv'))];


if isempty(lgFiles)

    error( ...
        'No LightGlue CSV files found under:\n%s', ...
        lgRoot);

end


fprintf('\nAvailable LightGlue CSV files:\n');

for k = 1:numel(lgFiles)

    fprintf('%s\n',lgFiles(k).name);

end


lgCleanFile = '';
lgPWMFile = '';


for k = 1:numel(lgFiles)

    nameLower = ...
        lower(lgFiles(k).name);


    fullPath = ...
        fullfile( ...
        lgFiles(k).folder, ...
        lgFiles(k).name);


    if contains(nameLower,'clean') && ...
            contains(nameLower,'match')

        lgCleanFile = fullPath;

    end


    if contains(nameLower,'pwm') && ...
            contains(nameLower,'match')

        lgPWMFile = fullPath;

    end

end


if isempty(lgCleanFile)

    error( ...
        ['Could not find LightGlue CLEAN match CSV.\n' ...
         'Check filenames shown above.']);

end


if isempty(lgPWMFile)

    error( ...
        ['Could not find LightGlue PWM match CSV.\n' ...
         'Check filenames shown above.']);

end


fprintf('\nLightGlue clean file:\n%s\n',lgCleanFile);

fprintf('\nLightGlue PWM file:\n%s\n',lgPWMFile);


%% ============================================================
% 7. LOAD TABLES
%% ============================================================

fprintf('\nLoading SURF clean...\n');
surfClean = readtable(surfCleanFile);

fprintf('Rows = %d\n',height(surfClean));


fprintf('\nLoading SURF PWM...\n');
surfPWM = readtable(surfPWMFile);

fprintf('Rows = %d\n',height(surfPWM));


fprintf('\nLoading LightGlue clean...\n');
lgClean = readtable(lgCleanFile);

fprintf('Rows = %d\n',height(lgClean));


fprintf('\nLoading LightGlue PWM...\n');
lgPWM = readtable(lgPWMFile);

fprintf('Rows = %d\n',height(lgPWM));


%% ============================================================
% 8. DISPLAY COLUMN NAMES
%% ============================================================

fprintf('\n==============================================\n');
fprintf('SURF CLEAN COLUMNS\n');
fprintf('==============================================\n');

disp(surfClean.Properties.VariableNames');


fprintf('\n==============================================\n');
fprintf('SURF PWM COLUMNS\n');
fprintf('==============================================\n');

disp(surfPWM.Properties.VariableNames');


fprintf('\n==============================================\n');
fprintf('LIGHTGLUE CLEAN COLUMNS\n');
fprintf('==============================================\n');

disp(lgClean.Properties.VariableNames');


fprintf('\n==============================================\n');
fprintf('LIGHTGLUE PWM COLUMNS\n');
fprintf('==============================================\n');

disp(lgPWM.Properties.VariableNames');


%% ============================================================
% 9. STANDARDIZE COLUMN NAMES
%% ============================================================

surfClean = standardizeTable(surfClean,false);
surfPWM   = standardizeTable(surfPWM,true);

lgClean = standardizeTable(lgClean,false);
lgPWM   = standardizeTable(lgPWM,true);


%% ============================================================
% 10. VERIFY BASIC STRUCTURE
%% ============================================================

assert( ...
    numel(unique(surfClean.PairID)) == 50, ...
    'SURF clean should contain 50 PairIDs.');

assert( ...
    numel(unique(lgClean.PairID)) == 50, ...
    'LightGlue clean should contain 50 PairIDs.');


fprintf('\nPASS: clean files contain 50 PairIDs.\n');


%% ============================================================
% 11. CLEAN BASELINE ANALYSIS
%% ============================================================

cleanResults = table();

methods = ["SURF","LightGlue"];


for m = 1:2

    method = methods(m);


    if method == "SURF"

        T = surfClean;

    else

        T = lgClean;

    end


    fprintf('\n');
    fprintf('==============================================\n');
    fprintf('%s CLEAN BASELINE\n',method);
    fprintf('==============================================\n');


    for pairID = 1:N_PAIRS

        idx = ...
            T.PairID == pairID;


        assert(any(idx), ...
            '%s clean PairID %d missing.', ...
            method,pairID);


        p1 = [ ...
            T.X1(idx) ...
            T.Y1(idx)];


        p2 = [ ...
            T.X2(idx) ...
            T.Y2(idx)];

datasetIdx1 = ...
    START_INDEX + pairID - 1;

datasetIdx2 = ...
    datasetIdx1 + GAP;


timestamp1 = ...
    rgbTimes(datasetIdx1);

timestamp2 = ...
    rgbTimes(datasetIdx2);


        [Rgt,tgt,baseline] = ...
            getGroundTruthRelativePose( ...
            timestamp1, ...
            timestamp2, ...
            gtTime, ...
            gtData);


        rng( ...
            100000 + pairID, ...
            'twister');


        B = sharedBackendPose( ...
            p1, ...
            p2, ...
            intrinsics, ...
            NUM_TRIALS, ...
            DISTANCE_THRESHOLD, ...
            CONFIDENCE, ...
            VALID_FRACTION_THRESHOLD);


        rotErr = NaN;
        transErr = NaN;


        if B.PoseRecovered

            rotErr = ...
                rotationDifferenceDegrees( ...
                B.R, ...
                Rgt);


            transErr = ...
                rawTranslationAngleDegrees( ...
                B.t, ...
                tgt);

        end


        newRow = table( ...
            method, ...
            pairID, ...
            timestamp1, ...
            timestamp2, ...
            baseline, ...
            size(p1,1), ...
            B.PoseRecovered, ...
            rotErr, ...
            transErr, ...
            string(B.FailureStage), ...
            'VariableNames',{ ...
            'Method', ...
            'PairID', ...
            'Timestamp1', ...
            'Timestamp2', ...
            'GTTranslationMagnitudeM', ...
            'RawMatches', ...
            'PoseRecovered', ...
            'RotationErrorDeg', ...
            'TranslationErrorDeg', ...
            'FailureStage'});


        cleanResults = [ ...
            cleanResults;
            newRow];

    end

end


%% ============================================================
% 12. CLEAN SANITY CHECK
%% ============================================================

fprintf('\n');
fprintf('==============================================\n');
fprintf('CLEAN SANITY CHECK\n');
fprintf('==============================================\n');


for m = 1:2

    method = methods(m);


    X = cleanResults( ...
        cleanResults.Method == method, ...
        :);


    recovered = ...
        X.PoseRecovered;


    fprintf('\n%s\n',method);


    fprintf( ...
        'Recovery = %.1f%% (%d/%d)\n', ...
        100*mean(recovered), ...
        sum(recovered), ...
        height(X));


    fprintf( ...
        'Median rotation error = %.3f deg\n', ...
        median( ...
        X.RotationErrorDeg(recovered), ...
        'omitnan'));


    fprintf( ...
        'Median raw translation error = %.3f deg\n', ...
        median( ...
        X.TranslationErrorDeg(recovered), ...
        'omitnan'));

end


fprintf('\nExpected approximately:\n');
fprintf('SURF rotation       ~ 2.870 deg\n');
fprintf('SURF translation    ~ 12.798 deg\n');
fprintf('LightGlue rotation  ~ 2.880 deg\n');
fprintf('LightGlue translation ~ 11.249 deg\n');


writetable( ...
    cleanResults, ...
    fullfile( ...
    outRoot, ...
    'experiment18M_clean_pose_sanity_check.csv'));


%% ============================================================
% 13. PWM ALL-ATTEMPT ANALYSIS
%% ============================================================

allResults = table();


for m = 1:2

    method = methods(m);


    if method == "SURF"

        T = surfPWM;
        Tc = surfClean;

    else

        T = lgPWM;
        Tc = lgClean;

    end


    fprintf('\n');
    fprintf('==============================================\n');
    fprintf('%s PWM ANALYSIS\n',method);
    fprintf('==============================================\n');


    counter = 0;


    for pairID = 1:N_PAIRS

        for r = 1:numel(readoutsMs)

            readoutMs = ...
                readoutsMs(r);


            for p = 1:numel(phases)

                phase = ...
                    phases(p);


                counter = ...
                    counter + 1;


                idx = ...
                    T.PairID == pairID & ...
                    abs(T.Phase-phase) < 1e-9 & ...
                    abs(T.ReadoutMs-readoutMs) < 1e-9;


                if any(idx)

                    p1 = [ ...
                        T.X1(idx) ...
                        T.Y1(idx)];


                    p2 = [ ...
                        T.X2(idx) ...
                        T.Y2(idx)];


                  datasetIdx1 = ...
    START_INDEX + pairID - 1;

datasetIdx2 = ...
    datasetIdx1 + GAP;


timestamp1 = ...
    rgbTimes(datasetIdx1);

timestamp2 = ...
    rgbTimes(datasetIdx2);

              else

    p1 = zeros(0,2);

    p2 = zeros(0,2);

                end
                datasetIdx1 = ...
    START_INDEX + pairID - 1;

datasetIdx2 = ...
    datasetIdx1 + GAP;


timestamp1 = ...
    rgbTimes(datasetIdx1);

timestamp2 = ...
    rgbTimes(datasetIdx2);

                [Rgt,tgt,baseline] = ...
                    getGroundTruthRelativePose( ...
                    timestamp1, ...
                    timestamp2, ...
                    gtTime, ...
                    gtData);


                rng( ...
                    200000 + ...
                    pairID*1000 + ...
                    r*100 + ...
                    p, ...
                    'twister');


                B = sharedBackendPose( ...
                    p1, ...
                    p2, ...
                    intrinsics, ...
                    NUM_TRIALS, ...
                    DISTANCE_THRESHOLD, ...
                    CONFIDENCE, ...
                    VALID_FRACTION_THRESHOLD);


                rotErr = NaN;
                transErr = NaN;


                if B.PoseRecovered

                    rotErr = ...
                        rotationDifferenceDegrees( ...
                        B.R, ...
                        Rgt);


                    transErr = ...
                        rawTranslationAngleDegrees( ...
                        B.t, ...
                        tgt);

                end


                recoverySuccess = ...
                    B.PoseRecovered;


                rotationSuccess = ...
                    recoverySuccess && ...
                    isfinite(rotErr) && ...
                    rotErr < ROT_THRESHOLD_DEG;


                translationSuccess = ...
                    recoverySuccess && ...
                    isfinite(transErr) && ...
                    transErr < TRANS_THRESHOLD_DEG;


                combinedSuccess = ...
                    recoverySuccess && ...
                    rotationSuccess && ...
                    translationSuccess;


                newRow = table( ...
                    method, ...
                    pairID, ...
                    phase, ...
                    readoutMs, ...
                    timestamp1, ...
                    timestamp2, ...
                    baseline, ...
                    size(p1,1), ...
                    recoverySuccess, ...
                    rotErr, ...
                    transErr, ...
                    rotationSuccess, ...
                    translationSuccess, ...
                    combinedSuccess, ...
                    string(B.FailureStage), ...
                    'VariableNames',{ ...
                    'Method', ...
                    'PairID', ...
                    'Phase', ...
                    'ReadoutMs', ...
                    'Timestamp1', ...
                    'Timestamp2', ...
                    'GTTranslationMagnitudeM', ...
                    'RawMatches', ...
                    'RecoverySuccess', ...
                    'RotationErrorDeg', ...
                    'TranslationErrorDeg', ...
                    'RotationSuccessLT5deg', ...
                    'TranslationSuccessLT15deg', ...
                    'CombinedSuccess', ...
                    'FailureStage'});


                allResults = [ ...
                    allResults;
                    newRow];


                if mod(counter,100) == 0

                    fprintf( ...
                        '%s: %d/%d complete\n', ...
                        method, ...
                        counter, ...
                        expectedEvaluations);

                end

            end

        end

    end

end


%% ============================================================
% 14. VERIFY EXACTLY 1500 ATTEMPTS PER METHOD
%% ============================================================

for m = 1:2

    method = methods(m);


    X = allResults( ...
        allResults.Method == method, ...
        :);


    assert( ...
        height(X) == expectedEvaluations, ...
        '%s should contain exactly 1500 attempts.', ...
        method);

end


fprintf('\nPASS: both methods contain exactly 1500 attempts.\n');


%% ============================================================
% 15. SAVE ALL ATTEMPTS
%% ============================================================

allFile = fullfile( ...
    outRoot, ...
    'experiment18M_all_attempts_pose_accuracy.csv');


writetable( ...
    allResults, ...
    allFile);


%% ============================================================
% 16. GLOBAL SUMMARY
%% ============================================================

globalSummary = table();


for m = 1:2

    method = methods(m);


    X = allResults( ...
        allResults.Method == method, ...
        :);


    n = height(X);


    recoveryCount = ...
        sum(X.RecoverySuccess);


    rotCount = ...
        sum(X.RotationSuccessLT5deg);


    transCount = ...
        sum(X.TranslationSuccessLT15deg);


    combinedCount = ...
        sum(X.CombinedSuccess);


    recoveryPercent = ...
        100 * recoveryCount / n;


    rotPercent = ...
        100 * rotCount / n;


    transPercent = ...
        100 * transCount / n;


    combinedPercent = ...
        100 * combinedCount / n;


    recoveredIdx = ...
        X.RecoverySuccess;


    medRot = median( ...
        X.RotationErrorDeg(recoveredIdx), ...
        'omitnan');


    medTrans = median( ...
        X.TranslationErrorDeg(recoveredIdx), ...
        'omitnan');


    row = table( ...
        method, ...
        n, ...
        recoveryCount, ...
        recoveryPercent, ...
        rotCount, ...
        rotPercent, ...
        transCount, ...
        transPercent, ...
        combinedCount, ...
        combinedPercent, ...
        medRot, ...
        medTrans, ...
        'VariableNames',{ ...
        'Method', ...
        'TotalAttempts', ...
        'RecoverySuccessCount', ...
        'RecoverySuccessPercent', ...
        'RotationLT5degCount', ...
        'RotationLT5degPercent', ...
        'TranslationLT15degCount', ...
        'TranslationLT15degPercent', ...
        'CombinedSuccessCount', ...
        'CombinedSuccessPercent', ...
        'MedianRotationErrorRecoveredDeg', ...
        'MedianTranslationErrorRecoveredDeg'});


    globalSummary = [ ...
        globalSummary;
        row];

end


globalFile = fullfile( ...
    outRoot, ...
    'experiment18M_global_accuracy_success.csv');


writetable( ...
    globalSummary, ...
    globalFile);


%% ============================================================
% 17. PHASE SUMMARY
%% ============================================================

phaseSummary = table();


for m = 1:2

    method = methods(m);


    for p = 1:numel(phases)

        phase = phases(p);


        idx = ...
            allResults.Method == method & ...
            abs(allResults.Phase-phase) < 1e-9;


        X = ...
            allResults(idx,:);


        row = table( ...
            method, ...
            phase, ...
            height(X), ...
            100*mean(X.RecoverySuccess), ...
            100*mean(X.RotationSuccessLT5deg), ...
            100*mean(X.TranslationSuccessLT15deg), ...
            100*mean(X.CombinedSuccess), ...
            'VariableNames',{ ...
            'Method', ...
            'Phase', ...
            'TotalAttempts', ...
            'RecoverySuccessPercent', ...
            'RotationLT5degPercent', ...
            'TranslationLT15degPercent', ...
            'CombinedSuccessPercent'});


        phaseSummary = [ ...
            phaseSummary;
            row];

    end

end


writetable( ...
    phaseSummary, ...
    fullfile( ...
    outRoot, ...
    'experiment18M_phase_accuracy_success.csv'));


%% ============================================================
% 18. READOUT SUMMARY
%% ============================================================

readoutSummary = table();


for m = 1:2

    method = methods(m);


    for r = 1:numel(readoutsMs)

        readoutMs = readoutsMs(r);


        idx = ...
            allResults.Method == method & ...
            allResults.ReadoutMs == readoutMs;


        X = ...
            allResults(idx,:);


        row = table( ...
            method, ...
            readoutMs, ...
            height(X), ...
            100*mean(X.RecoverySuccess), ...
            100*mean(X.RotationSuccessLT5deg), ...
            100*mean(X.TranslationSuccessLT15deg), ...
            100*mean(X.CombinedSuccess), ...
            'VariableNames',{ ...
            'Method', ...
            'ReadoutMs', ...
            'TotalAttempts', ...
            'RecoverySuccessPercent', ...
            'RotationLT5degPercent', ...
            'TranslationLT15degPercent', ...
            'CombinedSuccessPercent'});


        readoutSummary = [ ...
            readoutSummary;
            row];

    end

end


writetable( ...
    readoutSummary, ...
    fullfile( ...
    outRoot, ...
    'experiment18M_readout_accuracy_success.csv'));


%% ============================================================
% 19. CONDITION SUMMARY
%% ============================================================

conditionSummary = table();


for m = 1:2

    method = methods(m);


    for r = 1:numel(readoutsMs)

        readoutMs = readoutsMs(r);


        for p = 1:numel(phases)

            phase = phases(p);


            idx = ...
                allResults.Method == method & ...
                allResults.ReadoutMs == readoutMs & ...
                abs(allResults.Phase-phase) < 1e-9;


            X = ...
                allResults(idx,:);


            assert( ...
                height(X) == 50, ...
                'Expected 50 attempts per condition.');


            row = table( ...
                method, ...
                phase, ...
                readoutMs, ...
                100*mean(X.RecoverySuccess), ...
                100*mean(X.RotationSuccessLT5deg), ...
                100*mean(X.TranslationSuccessLT15deg), ...
                100*mean(X.CombinedSuccess), ...
                'VariableNames',{ ...
                'Method', ...
                'Phase', ...
                'ReadoutMs', ...
                'RecoverySuccessPercent', ...
                'RotationLT5degPercent', ...
                'TranslationLT15degPercent', ...
                'CombinedSuccessPercent'});


            conditionSummary = [ ...
                conditionSummary;
                row];

        end

    end

end


writetable( ...
    conditionSummary, ...
    fullfile( ...
    outRoot, ...
    'experiment18M_condition_accuracy_success.csv'));


%% ============================================================
% 20. FINAL PRINT
%% ============================================================

fprintf('\n\n');
fprintf('============================================================\n');
fprintf('FINAL ACCURACY-BASED POSE SUCCESS RESULTS\n');
fprintf('ALL 1500 ATTEMPTS PER METHOD\n');
fprintf('============================================================\n\n');


disp(globalSummary);


for m = 1:2

    method = methods(m);


    X = globalSummary( ...
        globalSummary.Method == method, ...
        :);


    fprintf('\n%s\n',method);


    fprintf( ...
        'Recovery success = %.3f%% (%d/%d)\n', ...
        X.RecoverySuccessPercent, ...
        X.RecoverySuccessCount, ...
        X.TotalAttempts);


    fprintf( ...
        'Rotation error < %.1f deg = %.3f%% (%d/%d)\n', ...
        ROT_THRESHOLD_DEG, ...
        X.RotationLT5degPercent, ...
        X.RotationLT5degCount, ...
        X.TotalAttempts);


    fprintf( ...
        'Translation error < %.1f deg = %.3f%% (%d/%d)\n', ...
        TRANS_THRESHOLD_DEG, ...
        X.TranslationLT15degPercent, ...
        X.TranslationLT15degCount, ...
        X.TotalAttempts);


    fprintf( ...
        'Combined accuracy success = %.3f%% (%d/%d)\n', ...
        X.CombinedSuccessPercent, ...
        X.CombinedSuccessCount, ...
        X.TotalAttempts);


    fprintf( ...
        'Median rotation error | recovered = %.3f deg\n', ...
        X.MedianRotationErrorRecoveredDeg);


    fprintf( ...
        'Median translation error | recovered = %.3f deg\n', ...
        X.MedianTranslationErrorRecoveredDeg);

end


%% ============================================================
% 21. FIGURE
%% ============================================================

figure;


metrics = [ ...
    globalSummary.RecoverySuccessPercent, ...
    globalSummary.RotationLT5degPercent, ...
    globalSummary.TranslationLT15degPercent, ...
    globalSummary.CombinedSuccessPercent];


bar(metrics);


set(gca, ...
    'XTick',1:height(globalSummary), ...
    'XTickLabel',cellstr(globalSummary.Method));


ylabel( ...
    'Success rate over all attempts (%)');


legend( ...
    { ...
    'Pose recovered', ...
    'Rotation < 5 deg', ...
    'Translation < 15 deg', ...
    'Combined accuracy success'}, ...
    'Location','best');


title( ...
    'Accuracy-Based Relative-Pose Success');


ylim([0 100]);

grid on;


figureFile = fullfile( ...
    outRoot, ...
    'experiment18M_accuracy_success.png');


exportgraphics( ...
    gcf, ...
    figureFile, ...
    'Resolution',300);


fprintf('\n');
fprintf('==============================================\n');
fprintf('EXPERIMENT 18M COMPLETE\n');
fprintf('==============================================\n');

fprintf('\nResults saved in:\n%s\n',outRoot);


%% ============================================================
% LOCAL FUNCTION 1
% STANDARDIZE TABLE COLUMN NAMES
%% ============================================================
% LOCAL FUNCTION
% STANDARDIZE TABLE COLUMN NAMES
%
% IMPORTANT:
% Timestamps are NOT required from raw-match CSV files.
% They are reconstructed directly from the TUM RGB filenames.
%% ============================================================

function T = standardizeTable(T,isPWM)


vars = string( ...
    T.Properties.VariableNames);


%% Pair ID

T = renameCandidate( ...
    T,vars, ...
    ["PairID","PairId","pairID","pair_id"], ...
    "PairID");


vars = string(T.Properties.VariableNames);


%% Coordinates

T = renameCandidate( ...
    T,vars, ...
    ["X1","x1","Point1X","x_1"], ...
    "X1");


vars = string(T.Properties.VariableNames);


T = renameCandidate( ...
    T,vars, ...
    ["Y1","y1","Point1Y","y_1"], ...
    "Y1");


vars = string(T.Properties.VariableNames);


T = renameCandidate( ...
    T,vars, ...
    ["X2","x2","Point2X","x_2"], ...
    "X2");


vars = string(T.Properties.VariableNames);


T = renameCandidate( ...
    T,vars, ...
    ["Y2","y2","Point2Y","y_2"], ...
    "Y2");


%% PWM-only columns

if isPWM

    vars = string(T.Properties.VariableNames);


    T = renameCandidate( ...
        T,vars, ...
        ["Phase","phase","PhaseOffset","RelativePhase"], ...
        "Phase");


    vars = string(T.Properties.VariableNames);


    T = renameCandidate( ...
        T,vars, ...
        ["ReadoutMs","ReadoutTimeMs","Readout", ...
         "Readout_ms"], ...
        "ReadoutMs");

end


%% Required columns

required = [ ...
    "PairID" ...
    "X1" ...
    "Y1" ...
    "X2" ...
    "Y2"];


if isPWM

    required = [ ...
        required ...
        "Phase" ...
        "ReadoutMs"];

end


vars = string( ...
    T.Properties.VariableNames);


missing = ...
    required(~ismember(required,vars));


if ~isempty(missing)

    fprintf('\nAVAILABLE COLUMNS:\n');

    disp(T.Properties.VariableNames');


    error( ...
        'Missing required columns after mapping: %s', ...
        strjoin(missing,", "));

end

end
%% ============================================================
% LOCAL FUNCTION 2
% RENAME COLUMN
%% ============================================================

function T = renameCandidate( ...
    T,vars,candidates,target)


if any(vars == target)
    return;
end


idx = find( ...
    ismember(lower(vars),lower(candidates)), ...
    1);


if isempty(idx)
    return;
end


T.Properties.VariableNames{idx} = ...
    char(target);

end


%% ============================================================
% LOCAL FUNCTION 3
% GROUND TRUTH RELATIVE POSE
%% ============================================================

function [Rgt,tgt,baseline] = ...
    getGroundTruthRelativePose( ...
    timestamp1, ...
    timestamp2, ...
    gtTime, ...
    gtData)


[~,i1] = ...
    min(abs(gtTime-timestamp1));


[~,i2] = ...
    min(abs(gtTime-timestamp2));


p1w = ...
    gtData(i1,2:4)';


p2w = ...
    gtData(i2,2:4)';


q1 = ...
    gtData(i1,5:8);


q2 = ...
    gtData(i2,5:8);


R1 = ...
    tumQuaternionToRotation(q1);


R2 = ...
    tumQuaternionToRotation(q2);


Rgt = ...
    R1' * R2;


deltaWorld = ...
    p2w - p1w;


baseline = ...
    norm(deltaWorld);


tgt = ...
    R1' * deltaWorld;


if norm(tgt) > 1e-12

    tgt = ...
        tgt / norm(tgt);

else

    tgt = ...
        [NaN;NaN;NaN];

end

end


%% ============================================================
% LOCAL FUNCTION 4
% TUM QUATERNION -> ROTATION MATRIX
%% ============================================================

function R = tumQuaternionToRotation(q)


qx = q(1);
qy = q(2);
qz = q(3);
qw = q(4);


n = sqrt( ...
    qx^2 + ...
    qy^2 + ...
    qz^2 + ...
    qw^2);


qx = qx/n;
qy = qy/n;
qz = qz/n;
qw = qw/n;


R = [ ...
    1-2*(qy^2+qz^2), ...
    2*(qx*qy-qz*qw), ...
    2*(qx*qz+qy*qw); ...

    2*(qx*qy+qz*qw), ...
    1-2*(qx^2+qz^2), ...
    2*(qy*qz-qx*qw); ...

    2*(qx*qz-qy*qw), ...
    2*(qy*qz+qx*qw), ...
    1-2*(qx^2+qy^2)];

end


%% ============================================================
% LOCAL FUNCTION 5
% SHARED BACKEND + POSE
%% ============================================================

function R = sharedBackendPose( ...
    p1, ...
    p2, ...
    intrinsics, ...
    numTrials, ...
    distanceThreshold, ...
    confidence, ...
    validFractionThreshold)


R.FundamentalInliers = 0;

R.EssentialInliers = 0;

R.ValidFraction = NaN;

R.PoseRecovered = false;

R.FailureStage = ...
    "TooFewMatches";

R.R = nan(3);

R.t = [NaN;NaN;NaN];


if size(p1,1) < 8

    return;

end


try

    [~,maskF,statusF] = ...
        estimateFundamentalMatrix( ...
        p1, ...
        p2, ...
        'Method','RANSAC', ...
        'NumTrials',numTrials, ...
        'DistanceThreshold',distanceThreshold, ...
        'Confidence',confidence);

catch

    R.FailureStage = ...
        "FundamentalFailure";

    return;

end


if statusF ~= 0 || ...
        isempty(maskF)

    R.FailureStage = ...
        "FundamentalFailure";

    return;

end


R.FundamentalInliers = ...
    sum(maskF);


try

    [E,maskE,statusE] = ...
        estimateEssentialMatrix( ...
        p1, ...
        p2, ...
        intrinsics, ...
        'Confidence',confidence, ...
        'MaxNumTrials',numTrials);

catch

    R.FailureStage = ...
        "EssentialFailure";

    return;

end


if statusE ~= 0 || ...
        isempty(E) || ...
        isempty(maskE)

    R.FailureStage = ...
        "EssentialFailure";

    return;

end


R.EssentialInliers = ...
    sum(maskE);


if R.EssentialInliers < 8

    R.FailureStage = ...
        "TooFewEssentialInliers";

    return;

end


p1E = ...
    p1(maskE,:);


p2E = ...
    p2(maskE,:);


bestVF = -inf;

bestR = [];

bestT = [];


if ndims(E) == 3

    nE = size(E,3);

else

    nE = 1;

end


for ee = 1:nE

    if nE == 1

        Ei = E;

    else

        Ei = E(:,:,ee);

    end


    try

        [Rcand,tcand,vfCand] = ...
            relativeCameraPose( ...
            Ei, ...
            intrinsics, ...
            p1E, ...
            p2E);

    catch

        continue;

    end


    if isempty(vfCand)
        continue;
    end


    if ndims(Rcand) == 3

        nCand = size(Rcand,3);

    else

        nCand = 1;

    end


    for cc = 1:nCand

        if nCand == 1

            Rc = squeeze(Rcand);

        else

            Rc = Rcand(:,:,cc);

        end


        if size(tcand,1) >= cc

            tc = tcand(cc,:);

        elseif size(tcand,2) >= cc && ...
                size(tcand,1) == 3

            tc = tcand(:,cc)';

        else

            tc = tcand(1,:);

        end


        if numel(vfCand) >= cc

            vf = vfCand(cc);

        else

            vf = vfCand(1);

        end


        if isfinite(vf) && ...
                vf > bestVF

            bestVF = vf;

            bestR = Rc;

            bestT = tc;

        end

    end

end


if isempty(bestR) || ...
        isempty(bestT)

    R.FailureStage = ...
        "PoseRecoveryFailure";

    return;

end


R.ValidFraction = bestVF;


if bestVF < validFractionThreshold

    R.FailureStage = ...
        "LowValidFraction";

    return;

end


bestT = bestT(:);


if numel(bestT) ~= 3 || ...
        any(~isfinite(bestT)) || ...
        norm(bestT) < 1e-12

    R.FailureStage = ...
        "InvalidTranslation";

    return;

end


bestT = ...
    bestT / norm(bestT);


R.R = bestR;

R.t = bestT;

R.PoseRecovered = true;

R.FailureStage = "Recovered";

end


%% ============================================================
% LOCAL FUNCTION 6
% ROTATION ERROR
%% ============================================================

function angleDeg = ...
    rotationDifferenceDegrees(Rest,Rgt)


if any(~isfinite(Rest(:))) || ...
        any(~isfinite(Rgt(:)))

    angleDeg = NaN;

    return;

end


Rerr = ...
    Rest * Rgt';


x = ...
    (trace(Rerr)-1)/2;


x = ...
    max(-1,min(1,x));


angleDeg = ...
    acosd(x);

end


%% ============================================================
% LOCAL FUNCTION 7
% RAW TRANSLATION-DIRECTION ERROR
%% ============================================================

function angleDeg = ...
    rawTranslationAngleDegrees(test,tgt)


test = test(:);

tgt = tgt(:);


if any(~isfinite(test)) || ...
        any(~isfinite(tgt)) || ...
        norm(test) < 1e-12 || ...
        norm(tgt) < 1e-12

    angleDeg = NaN;

    return;

end


test = test / norm(test);

tgt = tgt / norm(tgt);


x = dot(test,tgt);


x = max(-1,min(1,x));


angleDeg = acosd(x);

end