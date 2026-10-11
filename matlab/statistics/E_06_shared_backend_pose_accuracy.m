clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');

close all;

%% ============================================================
% EXPERIMENT 18L
% SHARED-BACKEND PWM POSE ACCURACY
%
% Dataset:
% Existing experiment18J shared-backend PWM pairwise CSV.
%
% Purpose:
% 1. Quantify pose accuracy conditional on successful recovery.
% 2. Compare SURF and LightGlue on the same recovered conditions.
% 3. Account for repeated PairIDs using pair-cluster bootstrap.
%
% NO new feature extraction.
% NO RANSAC rerun.
% NO new dataset.
%% ============================================================

rootDir = repository_output(repoPaths,'main_shared_backend');

inputFile = repository_input(repoPaths,'main_shared_backend/experiment18J_shared_backend_PWM_pairwise.csv');

assert(isfile(inputFile), ...
    'Missing input file:\n%s', inputFile);

%% ============================================================
% SETTINGS
%% ============================================================

N_BOOT = 5000;
BOOT_SEED = 1806001;

rng(BOOT_SEED,'twister');

%% ============================================================
% LOAD DATA
%% ============================================================

T = readtable(inputFile);

T.Method = string(T.Method);

%% ------------------------------------------------------------
% Convert PoseRecovered robustly
%% ------------------------------------------------------------

if islogical(T.PoseRecovered)

    T.PoseRecoveredLogical = T.PoseRecovered;

elseif isnumeric(T.PoseRecovered)

    T.PoseRecoveredLogical = T.PoseRecovered ~= 0;

else

    x = lower(strtrim(string(T.PoseRecovered)));

    T.PoseRecoveredLogical = ...
        x == "true" | ...
        x == "1" | ...
        x == "yes";

end

%% ============================================================
% REQUIRED VARIABLES
%% ============================================================

requiredVariables = { ...
    'Method', ...
    'PairID', ...
    'Phase', ...
    'ReadoutMs', ...
    'PoseRecoveredLogical', ...
    'RotationErrorDeg', ...
    'TranslationRawErrorDeg'};

for k = 1:numel(requiredVariables)

    assert( ...
        ismember(requiredVariables{k}, ...
        T.Properties.VariableNames), ...
        'Missing required variable: %s', ...
        requiredVariables{k});

end

%% ============================================================
% OPTIONAL CLEAN-TO-PWM DELTA VARIABLES
%% ============================================================

hasDeltaRot = ...
    ismember('DeltaRotationErrorDeg', ...
    T.Properties.VariableNames);

hasDeltaTrans = ...
    ismember('DeltaTranslationRawErrorDeg', ...
    T.Properties.VariableNames);

fprintf('\n============================================\n');
fprintf('EXPERIMENT 18L - PWM POSE ACCURACY\n');
fprintf('============================================\n\n');

fprintf('Rows loaded: %d\n',height(T));
fprintf('Delta rotation available: %d\n',hasDeltaRot);
fprintf('Delta translation available: %d\n\n',hasDeltaTrans);

%% ============================================================
% SPLIT METHODS
%% ============================================================

surf = T(T.Method == "SURF",:);
lg   = T(T.Method == "LightGlue",:);

assert(height(surf) == 1500, ...
    'Expected 1500 SURF rows.');

assert(height(lg) == 1500, ...
    'Expected 1500 LightGlue rows.');

%% ============================================================
% RECOVERED-CASE COUNTS
%% ============================================================

surfRecovered = ...
    surf(surf.PoseRecoveredLogical,:);

lgRecovered = ...
    lg(lg.PoseRecoveredLogical,:);

fprintf('RECOVERY COUNTS\n');
fprintf('SURF: %d / %d recovered\n', ...
    height(surfRecovered),height(surf));

fprintf('LightGlue: %d / %d recovered\n\n', ...
    height(lgRecovered),height(lg));

%% ============================================================
% METHOD-SPECIFIC CONDITIONAL ACCURACY
%% ============================================================

surfRotMedian = ...
    median(surfRecovered.RotationErrorDeg,'omitnan');

lgRotMedian = ...
    median(lgRecovered.RotationErrorDeg,'omitnan');

surfTransMedian = ...
    median(surfRecovered.TranslationRawErrorDeg,'omitnan');

lgTransMedian = ...
    median(lgRecovered.TranslationRawErrorDeg,'omitnan');

fprintf('ALL SUCCESSFULLY RECOVERED CASES\n\n');

fprintf('SURF median PWM rotation error = %.4f deg\n', ...
    surfRotMedian);

fprintf('LightGlue median PWM rotation error = %.4f deg\n', ...
    lgRotMedian);

fprintf('SURF median PWM raw translation error = %.4f deg\n', ...
    surfTransMedian);

fprintf('LightGlue median PWM raw translation error = %.4f deg\n\n', ...
    lgTransMedian);

%% ============================================================
% CLEAN-TO-PWM DELTAS
%% ============================================================

if hasDeltaRot

    surfDeltaRotMedian = ...
        median( ...
        surfRecovered.DeltaRotationErrorDeg, ...
        'omitnan');

    lgDeltaRotMedian = ...
        median( ...
        lgRecovered.DeltaRotationErrorDeg, ...
        'omitnan');

    fprintf('SURF median clean-to-PWM rotation delta = %.4f deg\n', ...
        surfDeltaRotMedian);

    fprintf('LightGlue median clean-to-PWM rotation delta = %.4f deg\n', ...
        lgDeltaRotMedian);

else

    surfDeltaRotMedian = NaN;
    lgDeltaRotMedian = NaN;

end

if hasDeltaTrans

    surfDeltaTransMedian = ...
        median( ...
        surfRecovered.DeltaTranslationRawErrorDeg, ...
        'omitnan');

    lgDeltaTransMedian = ...
        median( ...
        lgRecovered.DeltaTranslationRawErrorDeg, ...
        'omitnan');

    fprintf('SURF median clean-to-PWM translation delta = %.4f deg\n', ...
        surfDeltaTransMedian);

    fprintf('LightGlue median clean-to-PWM translation delta = %.4f deg\n\n', ...
        lgDeltaTransMedian);

else

    surfDeltaTransMedian = NaN;
    lgDeltaTransMedian = NaN;

end

%% ============================================================
% CREATE MATCHED SURF / LIGHTGLUE TABLE
%
% Same PairID + Phase + ReadoutMs
%% ============================================================

surfKey = surf(:,{ ...
    'PairID', ...
    'Phase', ...
    'ReadoutMs', ...
    'PoseRecoveredLogical', ...
    'RotationErrorDeg', ...
    'TranslationRawErrorDeg'});

surfKey.Properties.VariableNames = { ...
    'PairID', ...
    'Phase', ...
    'ReadoutMs', ...
    'SURF_Recovered', ...
    'SURF_RotationErrorDeg', ...
    'SURF_TranslationRawErrorDeg'};

lgKey = lg(:,{ ...
    'PairID', ...
    'Phase', ...
    'ReadoutMs', ...
    'PoseRecoveredLogical', ...
    'RotationErrorDeg', ...
    'TranslationRawErrorDeg'});

lgKey.Properties.VariableNames = { ...
    'PairID', ...
    'Phase', ...
    'ReadoutMs', ...
    'LG_Recovered', ...
    'LG_RotationErrorDeg', ...
    'LG_TranslationRawErrorDeg'};

M = innerjoin( ...
    surfKey, ...
    lgKey, ...
    'Keys',{'PairID','Phase','ReadoutMs'});

assert(height(M) == 1500, ...
    'Expected 1500 matched condition rows.');

%% ============================================================
% ADD DELTA VARIABLES TO MATCHED TABLE
%% ============================================================

if hasDeltaRot

    s = surf(:,{ ...
        'PairID','Phase','ReadoutMs', ...
        'DeltaRotationErrorDeg'});

    s.Properties.VariableNames{4} = ...
        'SURF_DeltaRotationErrorDeg';

    M = innerjoin(M,s, ...
        'Keys',{'PairID','Phase','ReadoutMs'});

    l = lg(:,{ ...
        'PairID','Phase','ReadoutMs', ...
        'DeltaRotationErrorDeg'});

    l.Properties.VariableNames{4} = ...
        'LG_DeltaRotationErrorDeg';

    M = innerjoin(M,l, ...
        'Keys',{'PairID','Phase','ReadoutMs'});

end

if hasDeltaTrans

    s = surf(:,{ ...
        'PairID','Phase','ReadoutMs', ...
        'DeltaTranslationRawErrorDeg'});

    s.Properties.VariableNames{4} = ...
        'SURF_DeltaTranslationRawErrorDeg';

    M = innerjoin(M,s, ...
        'Keys',{'PairID','Phase','ReadoutMs'});

    l = lg(:,{ ...
        'PairID','Phase','ReadoutMs', ...
        'DeltaTranslationRawErrorDeg'});

    l.Properties.VariableNames{4} = ...
        'LG_DeltaTranslationRawErrorDeg';

    M = innerjoin(M,l, ...
        'Keys',{'PairID','Phase','ReadoutMs'});

end

%% ============================================================
% MATCHED RECOVERED SUBSET
%% ============================================================

MR = M( ...
    M.SURF_Recovered & ...
    M.LG_Recovered,:);

fprintf('\nMATCHED RECOVERED COMPARISON\n');
fprintf('Both methods recovered: %d / %d evaluations\n\n', ...
    height(MR),height(M));

%% ------------------------------------------------------------
% Matched rotation
%% ------------------------------------------------------------

matchedSurfRot = ...
    median(MR.SURF_RotationErrorDeg,'omitnan');

matchedLGRot = ...
    median(MR.LG_RotationErrorDeg,'omitnan');

%% ------------------------------------------------------------
% Matched translation
%% ------------------------------------------------------------

matchedSurfTrans = ...
    median(MR.SURF_TranslationRawErrorDeg,'omitnan');

matchedLGTrans = ...
    median(MR.LG_TranslationRawErrorDeg,'omitnan');

fprintf('Matched SURF median rotation error = %.4f deg\n', ...
    matchedSurfRot);

fprintf('Matched LightGlue median rotation error = %.4f deg\n', ...
    matchedLGRot);

fprintf('Matched SURF median raw translation error = %.4f deg\n', ...
    matchedSurfTrans);

fprintf('Matched LightGlue median raw translation error = %.4f deg\n\n', ...
    matchedLGTrans);

%% ============================================================
% CLUSTER BOOTSTRAP ON MATCHED RECOVERED CASES
%
% Resample PairID, preserving all available recovered
% condition rows for that image pair.
%% ============================================================

pairIDs = unique(MR.PairID);
nPairs = numel(pairIDs);

fprintf('Matched subset contains %d unique PairIDs\n',nPairs);
fprintf('Running %d pair-cluster bootstrap replicates...\n\n',N_BOOT);

bootSurfRot = nan(N_BOOT,1);
bootLGRot = nan(N_BOOT,1);
bootRotDifference = nan(N_BOOT,1);

bootSurfTrans = nan(N_BOOT,1);
bootLGTrans = nan(N_BOOT,1);
bootTransDifference = nan(N_BOOT,1);

if hasDeltaRot

    bootSurfDeltaRot = nan(N_BOOT,1);
    bootLGDeltaRot = nan(N_BOOT,1);

else

    bootSurfDeltaRot = [];
    bootLGDeltaRot = [];

end

if hasDeltaTrans

    bootSurfDeltaTrans = nan(N_BOOT,1);
    bootLGDeltaTrans = nan(N_BOOT,1);

else

    bootSurfDeltaTrans = [];
    bootLGDeltaTrans = [];

end

for b = 1:N_BOOT

    samplePos = ...
        randi(nPairs,nPairs,1);

    sampleIDs = ...
        pairIDs(samplePos);

    MB = MR([],:);

    for j = 1:nPairs

        rows = ...
            MR(MR.PairID == sampleIDs(j),:);

        MB = [MB; rows];

    end

    %% Rotation

    bootSurfRot(b) = ...
        median( ...
        MB.SURF_RotationErrorDeg, ...
        'omitnan');

    bootLGRot(b) = ...
        median( ...
        MB.LG_RotationErrorDeg, ...
        'omitnan');

    bootRotDifference(b) = ...
        bootLGRot(b) - ...
        bootSurfRot(b);

    %% Translation

    bootSurfTrans(b) = ...
        median( ...
        MB.SURF_TranslationRawErrorDeg, ...
        'omitnan');

    bootLGTrans(b) = ...
        median( ...
        MB.LG_TranslationRawErrorDeg, ...
        'omitnan');

    bootTransDifference(b) = ...
        bootLGTrans(b) - ...
        bootSurfTrans(b);

    %% Clean-to-PWM deltas

    if hasDeltaRot

        bootSurfDeltaRot(b) = ...
            median( ...
            MB.SURF_DeltaRotationErrorDeg, ...
            'omitnan');

        bootLGDeltaRot(b) = ...
            median( ...
            MB.LG_DeltaRotationErrorDeg, ...
            'omitnan');

    end

    if hasDeltaTrans

        bootSurfDeltaTrans(b) = ...
            median( ...
            MB.SURF_DeltaTranslationRawErrorDeg, ...
            'omitnan');

        bootLGDeltaTrans(b) = ...
            median( ...
            MB.LG_DeltaTranslationRawErrorDeg, ...
            'omitnan');

    end

    if mod(b,500) == 0

        fprintf('Bootstrap %d / %d\n',b,N_BOOT);

    end

end

%% ============================================================
% CONFIDENCE INTERVALS
%% ============================================================

surfRotCI = ...
    prctile(bootSurfRot,[2.5 97.5]);

lgRotCI = ...
    prctile(bootLGRot,[2.5 97.5]);

rotDiffCI = ...
    prctile(bootRotDifference,[2.5 97.5]);

surfTransCI = ...
    prctile(bootSurfTrans,[2.5 97.5]);

lgTransCI = ...
    prctile(bootLGTrans,[2.5 97.5]);

transDiffCI = ...
    prctile(bootTransDifference,[2.5 97.5]);

%% ============================================================
% SUMMARY TABLE
%% ============================================================

Metric = [ ...
    "Matched SURF median rotation error (deg)"; ...
    "Matched LightGlue median rotation error (deg)"; ...
    "Matched rotation median difference, LG-SURF (deg)"; ...
    "Matched SURF median translation error (deg)"; ...
    "Matched LightGlue median translation error (deg)"; ...
    "Matched translation median difference, LG-SURF (deg)"];

Observed = [ ...
    matchedSurfRot; ...
    matchedLGRot; ...
    matchedLGRot - matchedSurfRot; ...
    matchedSurfTrans; ...
    matchedLGTrans; ...
    matchedLGTrans - matchedSurfTrans];

CI95_Lower = [ ...
    surfRotCI(1); ...
    lgRotCI(1); ...
    rotDiffCI(1); ...
    surfTransCI(1); ...
    lgTransCI(1); ...
    transDiffCI(1)];

CI95_Upper = [ ...
    surfRotCI(2); ...
    lgRotCI(2); ...
    rotDiffCI(2); ...
    surfTransCI(2); ...
    lgTransCI(2); ...
    transDiffCI(2)];

summaryTable = table( ...
    Metric, ...
    Observed, ...
    CI95_Lower, ...
    CI95_Upper);

%% ============================================================
% OPTIONAL DELTA SUMMARY
%% ============================================================

if hasDeltaRot && hasDeltaTrans

    deltaMetric = [ ...
        "SURF median clean-to-PWM rotation delta (deg)"; ...
        "LightGlue median clean-to-PWM rotation delta (deg)"; ...
        "SURF median clean-to-PWM translation delta (deg)"; ...
        "LightGlue median clean-to-PWM translation delta (deg)"];

    deltaObserved = [ ...
        median(MR.SURF_DeltaRotationErrorDeg,'omitnan'); ...
        median(MR.LG_DeltaRotationErrorDeg,'omitnan'); ...
        median(MR.SURF_DeltaTranslationRawErrorDeg,'omitnan'); ...
        median(MR.LG_DeltaTranslationRawErrorDeg,'omitnan')];

    deltaLower = [ ...
        prctile(bootSurfDeltaRot,2.5); ...
        prctile(bootLGDeltaRot,2.5); ...
        prctile(bootSurfDeltaTrans,2.5); ...
        prctile(bootLGDeltaTrans,2.5)];

    deltaUpper = [ ...
        prctile(bootSurfDeltaRot,97.5); ...
        prctile(bootLGDeltaRot,97.5); ...
        prctile(bootSurfDeltaTrans,97.5); ...
        prctile(bootLGDeltaTrans,97.5)];

    deltaSummary = table( ...
        deltaMetric, ...
        deltaObserved, ...
        deltaLower, ...
        deltaUpper, ...
        'VariableNames',{ ...
        'Metric', ...
        'Observed', ...
        'CI95_Lower', ...
        'CI95_Upper'});

else

    deltaSummary = table();

end

%% ============================================================
% SAVE RESULTS
%% ============================================================

summaryFile = fullfile( ...
    rootDir, ...
    'experiment18L_pose_accuracy_summary.csv');

writetable(summaryTable,summaryFile);

if ~isempty(deltaSummary)

    deltaFile = fullfile( ...
        rootDir, ...
        'experiment18L_pose_degradation_summary.csv');

    writetable(deltaSummary,deltaFile);

end

matchedFile = fullfile( ...
    rootDir, ...
    'experiment18L_matched_recovered_cases.csv');

writetable(MR,matchedFile);

%% ============================================================
% FINAL OUTPUT
%% ============================================================

fprintf('\n============================================\n');
fprintf('EXPERIMENT 18L COMPLETE\n');
fprintf('============================================\n\n');

fprintf('Matched recovered evaluations: %d / 1500\n\n', ...
    height(MR));

disp(summaryTable);

if ~isempty(deltaSummary)

    fprintf('\nCLEAN-TO-PWM DEGRADATION\n\n');

    disp(deltaSummary);

end

fprintf('\nIMPORTANT INTERPRETATION\n');
fprintf(['These pose-error statistics are conditional on successful ', ...
    'pose recovery.\n']);

fprintf(['They must be interpreted together with the failure rates ', ...
    '(SURF 66.733%%; LightGlue 0.000%% observed).\n']);

fprintf(['The matched subset compares both methods on exactly the ', ...
    'same successfully recovered pair-condition evaluations.\n\n']);

fprintf('Saved:\n');
fprintf('%s\n',summaryFile);
fprintf('%s\n',matchedFile);

if exist('deltaFile','var')
    fprintf('%s\n',deltaFile);
end

fprintf('\nDONE.\n');