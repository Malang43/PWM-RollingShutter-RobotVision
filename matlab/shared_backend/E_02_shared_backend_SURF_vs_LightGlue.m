clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;

%% EXPERIMENT 18J: SHARED MATLAB BACKEND FOR SURF AND LIGHTGLUE
% Save as: E_02_shared_backend_SURF_vs_LightGlue.m
% Run from:
% <original-source path: see MANIFEST.md>

datasetRoot = repoPaths.tumXYZ;
baseRoot = repoPaths.resultsRoot;

surfRoot = fullfile(repoPaths.resultsRoot,'raw_correspondences','xyz');
lgRoot = fullfile(repoPaths.resultsRoot,'raw_correspondences','xyz');
outRoot = repository_output(repoPaths,'main_shared_backend');

if ~exist(outRoot,'dir')
    mkdir(outRoot);
end

surfCleanMatchFile = repository_input(repoPaths,'raw_correspondences/xyz/SURF_clean_matches.csv');
surfPWMMatchFile   = repository_input(repoPaths,'raw_correspondences/xyz/SURF_PWM_matches.csv');

lgCleanMatchFile = repository_input(repoPaths,'raw_correspondences/xyz/experiment18I_LightGlue_clean_matches.csv');
lgPWMMatchFile   = repository_input(repoPaths,'raw_correspondences/xyz/experiment18I_LightGlue_PWM_matches.csv');

required = {surfCleanMatchFile,surfPWMMatchFile,lgCleanMatchFile,lgPWMMatchFile};

for k = 1:numel(required)
    assert(isfile(required{k}),'Missing file:\n%s',required{k});
end

fprintf('All four raw-match files found.\n');

%% SETTINGS
START_INDEX = 100;
GAP = 3;
N_PAIRS = 50;

phases = [0 0.125 0.25 0.5 0.875];
readouts = [5 10 15 20 25 30];

numTrials = 2000;
distanceThreshold = 1.5;
confidence = 99.9;
validFractionThreshold = 0.5;

intrinsics = cameraIntrinsics( ...
    [517.3 516.5], ...
    [318.6 255.3], ...
    [480 640]);

%% LOAD RAW MATCH TABLES
SCM = readtable(surfCleanMatchFile);
SPM = readtable(surfPWMMatchFile);

LCM = readtable(lgCleanMatchFile);
LPM = readtable(lgPWMMatchFile);

fprintf('SURF clean raw rows     : %d\n',height(SCM));
fprintf('SURF PWM raw rows       : %d\n',height(SPM));
fprintf('LightGlue clean raw rows: %d\n',height(LCM));
fprintf('LightGlue PWM raw rows  : %d\n',height(LPM));

%% LOAD RGB TIMESTAMPS
rgbFolder = fullfile(datasetRoot,'rgb');
rgbFiles = dir(fullfile(rgbFolder,'*.png'));

rgbTimes = zeros(numel(rgbFiles),1);

for k = 1:numel(rgbFiles)
    [~,nm,~] = fileparts(rgbFiles(k).name);
    rgbTimes(k) = str2double(nm);
end

[~,ord] = sort(rgbTimes);
rgbFiles = rgbFiles(ord);
rgbTimes = rgbTimes(ord);

assert(numel(rgbFiles)==798,'Expected 798 RGB images.');

%% LOAD GROUND TRUTH
GT = readmatrix( ...
    fullfile(datasetRoot,'groundtruth.txt'), ...
    'FileType','text', ...
    'CommentStyle','#');

GT = GT(all(isfinite(GT(:,1:8)),2),:);
gtTimes = GT(:,1);

fprintf('GT poses loaded: %d\n',size(GT,1));

%% PRECOMPUTE GT FOR 50 PAIRS
gtPair = repmat(struct( ...
    'R',eye(3), ...
    'tDir',[1 0 0], ...
    'baseline',nan, ...
    'assocDiff1',nan, ...
    'assocDiff2',nan),N_PAIRS,1);

for pairID = 1:N_PAIRS

    i = START_INDEX + pairID - 1;
    j = i + GAP;

    gtPair(pairID) = pairGroundTruth( ...
        rgbTimes(i),rgbTimes(j),GT,gtTimes);

end

allAssoc = [[gtPair.assocDiff1] [gtPair.assocDiff2]];

fprintf('Max RGB-GT association difference: %.6f s\n',max(allAssoc(:)));
fprintf('Mean GT baseline: %.6f m\n',mean([gtPair.baseline]));
fprintf('Median GT baseline: %.6f m\n',median([gtPair.baseline]));
fprintf('Minimum GT baseline: %.6f m\n\n',min([gtPair.baseline]));

%% ============================================================
% CLEAN EVALUATION
%% ============================================================

methods = ["SURF","LightGlue"];
cleanRows = table();

fprintf('CLEAN SHARED-BACKEND EVALUATION\n');

for m = 1:numel(methods)

    method = methods(m);

    if method=="SURF"
        M = SCM;
    else
        M = LCM;
    end

    for pairID = 1:N_PAIRS

        idx = M.PairID==pairID;

        p1 = [M.X1(idx) M.Y1(idx)];
        p2 = [M.X2(idx) M.Y2(idx)];

        rng(100000+pairID,'twister');

        R = sharedBackend( ...
            p1,p2,intrinsics,gtPair(pairID), ...
            numTrials,distanceThreshold,confidence, ...
            validFractionThreshold);

        row = makeRow( ...
            method,"CLEAN",pairID,nan,nan,size(p1,1),R, ...
            gtPair(pairID).baseline);

        cleanRows = [cleanRows; row];

    end

    X = cleanRows(cleanRows.Method==method,:);

    fprintf('%s clean recovery = %.1f%% (%d/%d)\n', ...
        method,100*mean(X.PoseRecovered), ...
        sum(X.PoseRecovered),height(X));

    fprintf('%s clean median rotation error = %.3f deg\n', ...
        method,median(X.RotationErrorDeg(X.PoseRecovered),'omitnan'));

    fprintf('%s clean median raw translation error = %.3f deg\n\n', ...
        method,median(X.TranslationRawErrorDeg(X.PoseRecovered),'omitnan'));

end

writetable(cleanRows, ...
    fullfile(outRoot,'experiment18J_shared_backend_clean_pairwise.csv'));

%% ============================================================
% PWM EVALUATION
%% ============================================================

pwmRows = table();

fprintf('PWM SHARED-BACKEND EVALUATION\n');

for m = 1:numel(methods)

    method = methods(m);

    if method=="SURF"
        M = SPM;
    else
        M = LPM;
    end

    counter = 0;

    for pairID = 1:N_PAIRS

        for r = 1:numel(readouts)

            ro = readouts(r);

            for p = 1:numel(phases)

                ph = phases(p);

                idx = M.PairID==pairID & ...
                    abs(M.Phase-ph)<1e-9 & ...
                    abs(M.ReadoutMs-ro)<1e-9;

                p1 = [M.X1(idx) M.Y1(idx)];
                p2 = [M.X2(idx) M.Y2(idx)];

                rng(200000 + pairID*1000 + r*100 + p,'twister');

                R = sharedBackend( ...
                    p1,p2,intrinsics,gtPair(pairID), ...
                    numTrials,distanceThreshold,confidence, ...
                    validFractionThreshold);

                row = makeRow( ...
                    method,"PWM",pairID,ph,ro,size(p1,1),R, ...
                    gtPair(pairID).baseline);

                pwmRows = [pwmRows; row];

                counter = counter + 1;

                if mod(counter,100)==0
                    fprintf('%s: %d / 1500\n',method,counter);
                end

            end

        end

    end

end

%% CLEAN-NORMALIZED METRICS
pwmRows.InlierRetentionPercent = nan(height(pwmRows),1);
pwmRows.DeltaRotationErrorDeg = nan(height(pwmRows),1);
pwmRows.DeltaTranslationRawErrorDeg = nan(height(pwmRows),1);

for n = 1:height(pwmRows)

    cidx = cleanRows.Method==pwmRows.Method(n) & ...
           cleanRows.PairID==pwmRows.PairID(n);

    cleanF = cleanRows.FundamentalInliers(cidx);

    if cleanF > 0
        pwmRows.InlierRetentionPercent(n) = ...
            100*pwmRows.FundamentalInliers(n)/cleanF;
    end

    if pwmRows.PoseRecovered(n) && cleanRows.PoseRecovered(cidx)

        pwmRows.DeltaRotationErrorDeg(n) = ...
            pwmRows.RotationErrorDeg(n) - cleanRows.RotationErrorDeg(cidx);

        pwmRows.DeltaTranslationRawErrorDeg(n) = ...
            pwmRows.TranslationRawErrorDeg(n) - ...
            cleanRows.TranslationRawErrorDeg(cidx);

    end

end

writetable(pwmRows, ...
    fullfile(outRoot,'experiment18J_shared_backend_PWM_pairwise.csv'));

%% CONDITION SUMMARY
conditionSummary = table();

for m = 1:numel(methods)

    method = methods(m);

    for r = 1:numel(readouts)

        ro = readouts(r);

        for p = 1:numel(phases)

            ph = phases(p);

            idx = pwmRows.Method==method & ...
                  abs(pwmRows.Phase-ph)<1e-12 & ...
                  pwmRows.ReadoutMs==ro;

            X = pwmRows(idx,:);

            assert(height(X)==50,'Expected 50 pairs per condition.');

            recovered = X.PoseRecovered;

            row = table( ...
                method,ph,ro, ...
                100*mean(~X.PoseRecovered), ...
                sum(recovered), ...
                median(X.InlierRetentionPercent,'omitnan'), ...
                mean(X.RawMatches,'omitnan'), ...
                median(X.RawMatches,'omitnan'), ...
                mean(X.FundamentalInliers,'omitnan'), ...
                median(X.FundamentalInliers,'omitnan'), ...
                median(X.DeltaRotationErrorDeg(recovered),'omitnan'), ...
                median(X.DeltaTranslationRawErrorDeg(recovered),'omitnan'), ...
                'VariableNames',{ ...
                'Method','Phase','ReadoutMs', ...
                'PoseFailurePercent','NposeRecovered', ...
                'MedianInlierRetentionPercent', ...
                'MeanRawMatches','MedianRawMatches', ...
                'MeanFundamentalInliers','MedianFundamentalInliers', ...
                'MedianDeltaRotationErrorDeg', ...
                'MedianDeltaTranslationRawErrorDeg'});

            conditionSummary = [conditionSummary; row];

        end

    end

end

writetable(conditionSummary, ...
    fullfile(outRoot,'experiment18J_shared_backend_condition_summary.csv'));

%% ============================================================
% FAILURE BREAKDOWN
%% ============================================================

failureBreakdown = table();

for m = 1:numel(methods)

    method = methods(m);

    X = pwmRows(
        pwmRows.Method == method, :
    );

    stages = unique(
        X.FailureStage
    );

    for s = 1:numel(stages)

        stage = stages(s);

        count = sum(
            X.FailureStage == stage
        );

        percent = ...
            100 * count / height(X);

        row = table( ...
            method, ...
            stage, ...
            count, ...
            percent, ...
            'VariableNames',{ ...
            'Method', ...
            'FailureStage', ...
            'Count', ...
            'Percent'});

        failureBreakdown = [ ...
            failureBreakdown;
            row
        ];

    end

end

writetable( ...
    failureBreakdown, ...
    fullfile( ...
        outRoot, ...
        'experiment18J_shared_backend_failure_breakdown.csv' ...
    ) ...
);

%% GLOBAL SUMMARY
globalSummary = table();

for m = 1:numel(methods)

    method = methods(m);

    X = pwmRows(pwmRows.Method==method,:);
    C = conditionSummary(conditionSummary.Method==method,:);

    row = table( ...
        method, ...
        100*mean(~X.PoseRecovered), ...
        mean(C.PoseFailurePercent,'omitnan'), ...
        mean(C.MedianInlierRetentionPercent,'omitnan'), ...
        mean(X.RawMatches,'omitnan'), ...
        mean(X.FundamentalInliers,'omitnan'), ...
        'VariableNames',{ ...
        'Method', ...
        'OverallPairwisePoseFailurePercent', ...
        'MeanConditionPoseFailurePercent', ...
        'MeanConditionMedianInlierRetentionPercent', ...
        'MeanRawMatches', ...
        'MeanFundamentalInliers'});

    globalSummary = [globalSummary; row];

end

writetable(globalSummary, ...
    fullfile(outRoot,'experiment18J_shared_backend_global_summary.csv'));

%% DIRECT 30-CONDITION COMPARISON
surfC = sortrows( ...
    conditionSummary(conditionSummary.Method=="SURF",:), ...
    {'Phase','ReadoutMs'});

lgC = sortrows( ...
    conditionSummary(conditionSummary.Method=="LightGlue",:), ...
    {'Phase','ReadoutMs'});

comparison = table();

comparison.Phase = surfC.Phase;
comparison.ReadoutMs = surfC.ReadoutMs;

comparison.SURF_PoseFailurePercent = surfC.PoseFailurePercent;
comparison.LightGlue_PoseFailurePercent = lgC.PoseFailurePercent;

comparison.FailureDifference_SURFminusLightGlue = ...
    surfC.PoseFailurePercent-lgC.PoseFailurePercent;

comparison.SURF_MedianInlierRetentionPercent = ...
    surfC.MedianInlierRetentionPercent;

comparison.LightGlue_MedianInlierRetentionPercent = ...
    lgC.MedianInlierRetentionPercent;

comparison.RetentionDifference_LightGlueminusSURF = ...
    lgC.MedianInlierRetentionPercent-surfC.MedianInlierRetentionPercent;

comparison.SURF_NposeRecovered = surfC.NposeRecovered;
comparison.LightGlue_NposeRecovered = lgC.NposeRecovered;

comparison.SURF_MedianDeltaRotationErrorDeg = ...
    surfC.MedianDeltaRotationErrorDeg;

comparison.LightGlue_MedianDeltaRotationErrorDeg = ...
    lgC.MedianDeltaRotationErrorDeg;

comparison.SURF_MedianDeltaTranslationRawErrorDeg = ...
    surfC.MedianDeltaTranslationRawErrorDeg;

comparison.LightGlue_MedianDeltaTranslationRawErrorDeg = ...
    lgC.MedianDeltaTranslationRawErrorDeg;

writetable(comparison, ...
    fullfile(outRoot,'experiment18J_SHARED_BACKEND_SURF_vs_LightGlue.csv'));

%% FINAL REPORT
fprintf('\n============================================\n');
fprintf('EXPERIMENT 18J SHARED BACKEND COMPLETE\n');
fprintf('============================================\n\n');

disp(globalSummary);

fprintf('Mean SURF-LightGlue failure difference = %.3f percentage points\n', ...
    mean(comparison.FailureDifference_SURFminusLightGlue,'omitnan'));

fprintf('Mean LightGlue-SURF retention difference = %.3f percentage points\n', ...
    mean(comparison.RetentionDifference_LightGlueminusSURF,'omitnan'));

fprintf('\nResults saved in:\n%s\n',outRoot);

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function row = makeRow(method,cond,pairID,phase,readout,rawMatches,R,baseline)

row = table( ...
    method,cond,pairID,phase,readout,rawMatches, ...
    R.FundamentalInliers, ...
    R.FundamentalInlierRatioPercent, ...
    R.EssentialInliers, ...
    R.ValidFraction, ...
    R.PoseRecovered, ...
    string(R.FailureStage), ...
    R.RotationErrorDeg, ...
    R.TranslationRawErrorDeg, ...
    R.TranslationSignInvariantErrorDeg, ...
    baseline, ...
    'VariableNames',{ ...
    'Method','ConditionType','PairID','Phase','ReadoutMs', ...
    'RawMatches','FundamentalInliers', ...
    'FundamentalInlierRatioPercent','EssentialInliers', ...
    'ValidFraction','PoseRecovered','FailureStage', ...
    'RotationErrorDeg','TranslationRawErrorDeg', ...
    'TranslationSignInvariantErrorDeg','GTBaselineM'});

end


function R = sharedBackend( ...
    p1,p2,intrinsics,gt, ...
    numTrials,distanceThreshold,confidence,validFractionThreshold)

R.FundamentalInliers = 0;
R.FundamentalInlierRatioPercent = 0;
R.EssentialInliers = 0;
R.ValidFraction = 0;
R.PoseRecovered = false;
R.FailureStage = "TooFewMatches";
R.RotationErrorDeg = nan;
R.TranslationRawErrorDeg = nan;
R.TranslationSignInvariantErrorDeg = nan;

n = size(p1,1);

if n < 8
    return;
end

%% Fundamental matrix: same for both methods
try
    [~,inlierF,statusF] = estimateFundamentalMatrix( ...
        p1,p2, ...
        'Method','RANSAC', ...
        'NumTrials',numTrials, ...
        'DistanceThreshold',distanceThreshold, ...
        'Confidence',confidence);
catch
    R.FailureStage = "FundamentalFailure";
    return;
end

if statusF~=0 || isempty(inlierF)
    R.FailureStage = "FundamentalFailure";
    return;
end

nF = sum(inlierF);

R.FundamentalInliers = nF;
R.FundamentalInlierRatioPercent = 100*nF/n;

%% Essential matrix: same for both methods
try
    [E,inlierE,statusE] = estimateEssentialMatrix( ...
        p1,p2,intrinsics, ...
        'Confidence',confidence, ...
        'MaxNumTrials',numTrials);
catch
    R.FailureStage = "EssentialFailure";
    return;
end

if statusE~=0 || isempty(E) || isempty(inlierE)
    R.FailureStage = "EssentialFailure";
    return;
end

nE = sum(inlierE);
R.EssentialInliers = nE;

if nE < 8
    R.FailureStage = "TooFewEssentialInliers";
    return;
end

p1E = p1(inlierE,:);
p2E = p2(inlierE,:);

%% Pose recovery: SAME handling for both methods
%
% Some severely degraded conditions can return multiple
% candidate essential matrices / relative poses.
% Evaluate every candidate identically and retain the one
% with the largest valid cheirality fraction.

bestValidFraction = -inf;
bestRest = [];
bestTest = [];

% ------------------------------------------------------------
% Determine number of essential-matrix candidates
% ------------------------------------------------------------

if ndims(E) == 3
    nCandidates = size(E,3);
else
    nCandidates = 1;
end

for candidate = 1:nCandidates

    if nCandidates == 1
        Ecandidate = E;
    else
        Ecandidate = E(:,:,candidate);
    end

    try

        [Rcand,tcand,vfCand] = relativeCameraPose( ...
            Ecandidate, ...
            intrinsics, ...
            p1E, ...
            p2E);

    catch
        continue;
    end

    % --------------------------------------------------------
    % relativeCameraPose can itself occasionally return
    % multiple pose pages in degenerate cases.
    % --------------------------------------------------------

    if ndims(Rcand) == 3

        nPoseCandidates = size(Rcand,3);

        for kk = 1:nPoseCandidates

            Rtmp = Rcand(:,:,kk);

            if size(tcand,1) >= kk
                ttmp = tcand(kk,:);
            else
                continue;
            end

            if numel(vfCand) >= kk
                vtmp = vfCand(kk);
            else
                vtmp = vfCand(1);
            end

            if isfinite(vtmp) && vtmp > bestValidFraction

                bestValidFraction = vtmp;
                bestRest = Rtmp;
                bestTest = ttmp;

            end

        end

    else

        if isempty(vfCand)
            continue;
        end

        vtmp = vfCand(1);

        if isfinite(vtmp) && vtmp > bestValidFraction

            bestValidFraction = vtmp;
            bestRest = Rcand;

            if size(tcand,1) > 1
                bestTest = tcand(1,:);
            else
                bestTest = tcand;
            end

        end

    end

end

% ------------------------------------------------------------
% No valid pose candidate
% ------------------------------------------------------------

if isempty(bestRest) || isempty(bestTest)

    R.FailureStage = "PoseRecoveryFailure";
    return;

end

Rest = bestRest;
test = bestTest;
validFraction = bestValidFraction;

R.ValidFraction = validFraction;

% ------------------------------------------------------------
% Identical recovery criterion for both methods
% ------------------------------------------------------------

if validFraction < validFractionThreshold

    R.FailureStage = "LowValidFraction";
    return;

end

test = reshape(test,1,[]);

if numel(test) ~= 3 || ...
        any(~isfinite(test)) || ...
        norm(test) < 1e-12

    R.FailureStage = "InvalidTranslation";
    return;

end

test = test / norm(test);

%% Rotation error
v = (trace(Rest'*gt.R)-1)/2;
v = max(-1,min(1,v));
rotErr = acosd(v);

%% Translation-direction error
tgt = reshape(gt.tDir,1,[]);
tgt = tgt/norm(tgt);

v = dot(test,tgt);
v = max(-1,min(1,v));

transRaw = acosd(v);
transSI = min(transRaw,180-transRaw);

R.PoseRecovered = true;
R.FailureStage = "Recovered";
R.RotationErrorDeg = rotErr;
R.TranslationRawErrorDeg = transRaw;
R.TranslationSignInvariantErrorDeg = transSI;

end


function P = pairGroundTruth(t1,t2,GT,gtTimes)

[~,i1] = min(abs(gtTimes-t1));
[~,i2] = min(abs(gtTimes-t2));

g1 = GT(i1,:);
g2 = GT(i2,:);

p1 = g1(2:4);
p2 = g2(2:4);

R1 = quatXYZWToRotm(g1(5:8));
R2 = quatXYZWToRotm(g2(5:8));

Rrel = R1'*R2;
trel = R1'*(p2-p1)';

baseline = norm(trel);

if baseline < 1e-12
    tDir = [nan nan nan];
else
    tDir = (trel/baseline)';
end

P.R = Rrel;
P.tDir = tDir;
P.baseline = baseline;
P.assocDiff1 = abs(t1-gtTimes(i1));
P.assocDiff2 = abs(t2-gtTimes(i2));

end


function R = quatXYZWToRotm(q)

q = double(q(:)');
q = q/norm(q);

x=q(1); y=q(2); z=q(3); w=q(4);

R = [ ...
    1-2*(y*y+z*z), 2*(x*y-z*w),   2*(x*z+y*w); ...
    2*(x*y+z*w),   1-2*(x*x+z*z), 2*(y*z-x*w); ...
    2*(x*z-y*w),   2*(y*z+x*w),   1-2*(x*x+y*y)];

end
