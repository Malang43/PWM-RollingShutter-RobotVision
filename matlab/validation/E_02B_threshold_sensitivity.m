%% EXPERIMENT 18M — GEOMETRIC THRESHOLD SENSITIVITY (OPTIMIZED)
% Retains the original independent F/E robust-estimation backend.
% PERFORMANCE: pre-group raw matches once, estimate F/E once per distance
% threshold, then apply all three validFraction thresholds without rerunning.
% Checkpoints are saved after each distance threshold and all conditions.
% NOTE: MATLAB Computer Vision Toolbox required.

clc; clearvars; close all;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');


%% PATHS — edit only if your data have moved
baseRoot = repoPaths.resultsRoot;
surfRoot = fullfile(repoPaths.resultsRoot,'raw_correspondences','xyz');
lgRoot = fullfile(repoPaths.resultsRoot,'raw_correspondences','xyz');
outRoot = repository_output(repoPaths,'threshold_sensitivity');
if ~exist(outRoot,'dir'), mkdir(outRoot); end

surfCleanMatchFile = repository_input(repoPaths,'raw_correspondences/xyz/SURF_clean_matches.csv');
surfPWMMatchFile   = repository_input(repoPaths,'raw_correspondences/xyz/SURF_PWM_matches.csv');
lgCleanMatchFile   = repository_input(repoPaths,'raw_correspondences/xyz/experiment18I_LightGlue_clean_matches.csv');
lgPWMMatchFile     = repository_input(repoPaths,'raw_correspondences/xyz/experiment18I_LightGlue_PWM_matches.csv');
required = {surfCleanMatchFile,surfPWMMatchFile,lgCleanMatchFile,lgPWMMatchFile};
for k = 1:numel(required)
    assert(isfile(required{k}),'Missing file: %s',required{k});
end
fprintf('All four raw-match files found.\n');

%% SETTINGS — unchanged from original experiment
N_PAIRS = 50;
phases = [0 0.125 0.25 0.5 0.875];
readouts = [5 10 15 20 25 30];
numTrials = 2000;
confidence = 99.9;
distanceThresholds = [1.0 1.5 2.0];
validFractionThresholds = [0.4 0.5 0.6];
methods = ["SURF","LightGlue"];
intrinsics = cameraIntrinsics([517.3 516.5],[318.6 255.3],[480 640]);

% Set true only to suppress warning text (not failures). Warnings from ALL
% sources will be hidden while script runs. The original estimator status
% codes and failure stage still determine outcomes.
SUPPRESS_WARNINGS = false;
PROGRESS_EVERY = 25;

%% LOAD DATA
SCM = readtable(surfCleanMatchFile);
SPM = readtable(surfPWMMatchFile);
LCM = readtable(lgCleanMatchFile);
LPM = readtable(lgPWMMatchFile);
fprintf('SURF clean raw rows      : %d\n',height(SCM));
fprintf('SURF PWM raw rows        : %d\n',height(SPM));
fprintf('LightGlue clean raw rows : %d\n',height(LCM));
fprintf('LightGlue PWM raw rows   : %d\n',height(LPM));

%% PRE-GROUP MATCHES ONCE (do not scan a million-row table per trial)
fprintf('\nGrouping raw correspondences once...\n');
cleanGroups = cell(2,N_PAIRS);
pwmGroups = cell(2,N_PAIRS,numel(readouts),numel(phases));
cleanGroups(1,:) = makeCleanGroups(SCM,N_PAIRS);
cleanGroups(2,:) = makeCleanGroups(LCM,N_PAIRS);
pwmGroups(1,:,:,:) = makePWMGroups(SPM,N_PAIRS,readouts,phases);
pwmGroups(2,:,:,:) = makePWMGroups(LPM,N_PAIRS,readouts,phases);
clear SCM SPM LCM LPM;
fprintf('Grouping completed.\n\n');

%% CREATE/RESTORE WARNING CONFIGURATION
if SUPPRESS_WARNINGS
    previousWarningState = warning;
    warning('off','all');
    warningCleanup = onCleanup(@() warning(previousWarningState)); %#ok<NASGU>
end

%% MAIN COMPUTATION
% Each baseline F/E estimate is independent of validFractionThreshold.
% For a given distance threshold, all 3 valid-fraction tests therefore
% reuse the SAME fixed-seed geometric result.
allGlobal = table();
allCondition = table();
allComparison = table();
totalPWM = N_PAIRS*numel(readouts)*numel(phases);
runClock = tic;

for dt = 1:numel(distanceThresholds)
    distanceThreshold = distanceThresholds(dt);
    fprintf('\n====================================================\n');
    fprintf('DISTANCE THRESHOLD %d/%d : %.1f px\n',dt,numel(distanceThresholds),distanceThreshold);
    fprintf('====================================================\n');

    % Geometry is estimated once, before testing the 3 validFractions.
    nClean = 2*N_PAIRS;
    nPWM = 2*totalPWM;
    cleanMethod = strings(nClean,1);
    cleanPair = zeros(nClean,1);
    cleanRaw = zeros(nClean,1);
    cleanF = zeros(nClean,1);
    cleanVF = zeros(nClean,1);
    cleanBaseSuccess = false(nClean,1);
    cleanStage = strings(nClean,1);

    pwmMethod = strings(nPWM,1);
    pwmPair = zeros(nPWM,1);
    pwmPhase = zeros(nPWM,1);
    pwmReadout = zeros(nPWM,1);
    pwmRaw = zeros(nPWM,1);
    pwmF = zeros(nPWM,1);
    pwmVF = zeros(nPWM,1);
    pwmBaseSuccess = false(nPWM,1);
    pwmStage = strings(nPWM,1);

    for m = 1:2
        method = methods(m);
        fprintf('\n%s: clean pairs...\n',char(method));
        for pairID = 1:N_PAIRS
            coords = cleanGroups{m,pairID};
            rng(100000+pairID,'twister');
            R = backendNoVF(coords(:,1:2),coords(:,3:4),intrinsics, ...
                numTrials,distanceThreshold,confidence);
            ii = (m-1)*N_PAIRS+pairID;
            cleanMethod(ii)=method; cleanPair(ii)=pairID;
            cleanRaw(ii)=size(coords,1); cleanF(ii)=R.FundamentalInliers;
            cleanVF(ii)=R.ValidFraction;
            cleanBaseSuccess(ii)=R.BaseSuccess;
            cleanStage(ii)=R.FailureStage;
        end

        fprintf('%s: PWM pairs...\n',char(method));
        counter = 0; stageClock = tic;
        for pairID = 1:N_PAIRS
            for r = 1:numel(readouts)
                for p = 1:numel(phases)
                    coords = pwmGroups{m,pairID,r,p};
                    rng(200000+pairID*1000+r*100+p,'twister');
                    R = backendNoVF(coords(:,1:2),coords(:,3:4),intrinsics, ...
                        numTrials,distanceThreshold,confidence);
                    counter = counter+1;
                    ii = (m-1)*totalPWM+counter;
                    pwmMethod(ii)=method;
                    pwmPair(ii)=pairID; pwmPhase(ii)=phases(p);
                    pwmReadout(ii)=readouts(r);
                    pwmRaw(ii)=size(coords,1);
                    pwmF(ii)=R.FundamentalInliers;
                    pwmVF(ii)=R.ValidFraction;
                    pwmBaseSuccess(ii)=R.BaseSuccess;
                    pwmStage(ii)=R.FailureStage;
                    if mod(counter,PROGRESS_EVERY)==0 || counter==totalPWM
                        fprintf('%s | distance %d/3 | %4d/%d | %.1f min\n', ...
                            char(method),dt,counter,totalPWM,toc(stageClock)/60);
                        drawnow('limitrate');
                    end
                end
            end
        end
    end

    % Apply each validFraction threshold to the SAME geometry results.
    for vf = 1:numel(validFractionThresholds)
        validFractionThreshold = validFractionThresholds(vf);
        [cleanRecovered,cleanFailure] = applyVF( ...
            cleanBaseSuccess,cleanVF,cleanStage,validFractionThreshold);
        [pwmRecovered,pwmFailure] = applyVF( ...
            pwmBaseSuccess,pwmVF,pwmStage,validFractionThreshold);

        cleanRows = table(cleanMethod,cleanPair,cleanRaw,cleanF,cleanVF, ...
            cleanRecovered,cleanFailure,'VariableNames', ...
            {'Method','PairID','RawMatches','FundamentalInliers', ...
             'ValidFraction','PoseRecovered','FailureStage'});
        pwmRows = table(pwmMethod,pwmPair,pwmPhase,pwmReadout,pwmRaw, ...
            pwmF,pwmVF,pwmRecovered,pwmFailure,'VariableNames', ...
            {'Method','PairID','Phase','ReadoutMs','RawMatches', ...
             'FundamentalInliers','ValidFraction','PoseRecovered','FailureStage'});

        % Exact same normalization as original (by same method, pairID).
        pwmRows.InlierRetentionPercent = nan(height(pwmRows),1);
        for m = 1:2
            for pairID = 1:N_PAIRS
                ci = (m-1)*N_PAIRS+pairID;
                cleanCount = cleanF(ci);
                if cleanCount > 0
                    idx = (pwmMethod==methods(m) & pwmPair==pairID);
                    pwmRows.InlierRetentionPercent(idx) = 100*pwmF(idx)/cleanCount;
                end
            end
        end

        conditionRows = table();
        globalRows = table();
        for m = 1:2
            method = methods(m);
            for r = 1:numel(readouts)
                for p = 1:numel(phases)
                    idx = pwmRows.Method==method & ...
                        pwmRows.ReadoutMs==readouts(r) & ...
                        abs(pwmRows.Phase-phases(p))<1e-12;
                    X = pwmRows(idx,:);
                    assert(height(X)==N_PAIRS,'Expected %d pairs per condition.',N_PAIRS);
                    conditionRow = table(distanceThreshold,validFractionThreshold, ...
                        method,phases(p),readouts(r),100*mean(~X.PoseRecovered), ...
                        sum(X.PoseRecovered),median(X.InlierRetentionPercent,'omitnan'), ...
                        mean(X.FundamentalInliers,'omitnan'), ...
                        'VariableNames',{'RANSACThresholdPx','ValidFractionThreshold', ...
                        'Method','Phase','ReadoutMs','PoseFailurePercent','NposeRecovered', ...
                        'MedianInlierRetentionPercent','MeanFundamentalInliers'});
                    conditionRows=[conditionRows;conditionRow]; %#ok<AGROW>
                end
            end
            X = pwmRows(pwmRows.Method==method,:);
            C = conditionRows(conditionRows.Method==method,:);
            CX = cleanRows(cleanRows.Method==method,:);
            globalRow = table(distanceThreshold,validFractionThreshold,method, ...
                100*mean(CX.PoseRecovered),100*mean(~X.PoseRecovered), ...
                sum(X.PoseRecovered),mean(C.MedianInlierRetentionPercent,'omitnan'), ...
                mean(X.FundamentalInliers,'omitnan'), ...
                'VariableNames',{'RANSACThresholdPx','ValidFractionThreshold', ...
                'Method','CleanRecoveryPercent','PWMFailurePercent', ...
                'PWMRecoveredCount','MeanConditionMedianInlierRetentionPercent', ...
                'MeanPWMFundamentalInliers'});
            globalRows=[globalRows;globalRow]; %#ok<AGROW>
        end

        S = globalRows(globalRows.Method=="SURF",:);
        L = globalRows(globalRows.Method=="LightGlue",:);
        comparisonRow = table(distanceThreshold,validFractionThreshold, ...
            S.PWMFailurePercent,L.PWMFailurePercent, ...
            S.PWMFailurePercent-L.PWMFailurePercent, ...
            S.MeanConditionMedianInlierRetentionPercent, ...
            L.MeanConditionMedianInlierRetentionPercent, ...
            L.MeanConditionMedianInlierRetentionPercent- ...
                S.MeanConditionMedianInlierRetentionPercent, ...
            'VariableNames',{'RANSACThresholdPx','ValidFractionThreshold', ...
            'SURF_PoseFailurePercent','LightGlue_PoseFailurePercent', ...
            'FailureDifference_SURFminusLightGlue', ...
            'SURF_MeanConditionMedianRetentionPercent', ...
            'LightGlue_MeanConditionMedianRetentionPercent', ...
            'RetentionDifference_LightGlueminusSURF'});

        allGlobal=[allGlobal;globalRows]; %#ok<AGROW>
        allCondition=[allCondition;conditionRows]; %#ok<AGROW>
        allComparison=[allComparison;comparisonRow]; %#ok<AGROW>

        % Save each setting immediately, not only after all nine settings.
        writetable(cleanRows,fullfile(outRoot,sprintf('clean_dt%.1f_vf%.1f.csv', ...
            distanceThreshold,validFractionThreshold)));
        writetable(pwmRows,fullfile(outRoot,sprintf('pwm_dt%.1f_vf%.1f.csv', ...
            distanceThreshold,validFractionThreshold)));
        writetable(allGlobal,fullfile(outRoot,'threshold_sensitivity_global_summary.csv'));
        writetable(allCondition,fullfile(outRoot,'threshold_sensitivity_condition_summary.csv'));
        writetable(allComparison,fullfile(outRoot,'threshold_sensitivity_SURF_vs_LightGlue.csv'));
        fprintf('\nSAVED setting %d/9 : distance=%.1f px, vf=%.1f\n', ...
            (dt-1)*numel(validFractionThresholds)+vf, ...
            distanceThreshold,validFractionThreshold);
        disp(globalRows);
    end
end

fprintf('\n====================================================\n');
fprintf('ALL NINE THRESHOLD SETTINGS COMPLETE (%.1f minutes)\n',toc(runClock)/60);
fprintf('====================================================\n');
disp(allComparison);
fprintf('SURF failure range: %.3f%% to %.3f%%\n', ...
    min(allComparison.SURF_PoseFailurePercent),max(allComparison.SURF_PoseFailurePercent));
fprintf('LightGlue failure range: %.3f%% to %.3f%%\n', ...
    min(allComparison.LightGlue_PoseFailurePercent),max(allComparison.LightGlue_PoseFailurePercent));
fprintf('Results: %s\n',outRoot);

%% LOCAL FUNCTIONS
function groups = makeCleanGroups(M,N_PAIRS)
    needed = {'PairID','X1','Y1','X2','Y2'};
    assert(all(ismember(needed,M.Properties.VariableNames)), ...
        'Clean match CSV is missing required columns.');
    groups = cell(1,N_PAIRS);
    for k=1:N_PAIRS
        idx = M.PairID==k;
        groups{k} = [M.X1(idx) M.Y1(idx) M.X2(idx) M.Y2(idx)];
    end
end

function groups = makePWMGroups(M,N_PAIRS,readouts,phases)
    needed = {'PairID','Phase','ReadoutMs','X1','Y1','X2','Y2'};
    assert(all(ismember(needed,M.Properties.VariableNames)), ...
        'PWM match CSV is missing required columns.');
    nr=numel(readouts); np=numel(phases);
    groups = cell(1,N_PAIRS,nr,np);
    % Form a unique group ID once, then sort it once. This avoids a
    % million-row scan for every one of the 1,500 experiments.
    [isR,rIndex] = ismember(M.ReadoutMs,readouts);
    % Floating-point phases may differ slightly after CSV round-tripping.
    phaseIndex = zeros(height(M),1);
    for p=1:np
        phaseIndex(abs(M.Phase-phases(p))<1e-9)=p;
    end
    ok = isR & phaseIndex>0 & M.PairID>=1 & M.PairID<=N_PAIRS & ...
        M.PairID==floor(M.PairID);
    assert(all(ok),'Unexpected PairID, ReadoutMs or Phase in PWM CSV.');
    keys = ((double(M.PairID)-1)*nr + double(rIndex)-1)*np + phaseIndex;
    [sortedKeys,order] = sort(keys);
    coords = [M.X1 M.Y1 M.X2 M.Y2];
    starts = [1;find(diff(sortedKeys)~=0)+1];
    stops = [starts(2:end)-1;numel(sortedKeys)];
    for g=1:numel(starts)
        key=sortedKeys(starts(g));
        p=mod(key-1,np)+1;
        q=floor((key-1)/np);
        r=mod(q,nr)+1;
        pairID=floor(q/nr)+1;
        groups{1,pairID,r,p}=coords(order(starts(g):stops(g)),:);
    end
    for pairID=1:N_PAIRS
        for r=1:nr
            for p=1:np
                if isempty(groups{1,pairID,r,p})
                    groups{1,pairID,r,p}=zeros(0,4);
                end
            end
        end
    end
end

function R = backendNoVF(p1,p2,intrinsics,numTrials,distanceThreshold,confidence)
    % Original behavior: F and E are separately estimated from RAW matches.
    % No fundamental-inlier filtering is introduced here.
    R.FundamentalInliers=0;
    R.ValidFraction=0;
    R.BaseSuccess=false;
    R.FailureStage="TooFewMatches";
    n=size(p1,1);
    if n<8, return; end
    try
        [~,inlierF,statusF] = estimateFundamentalMatrix( ...
            p1,p2,'Method','RANSAC','NumTrials',numTrials, ...
            'DistanceThreshold',distanceThreshold,'Confidence',confidence);
    catch
        R.FailureStage="FundamentalFailure"; return;
    end
    if statusF~=0 || isempty(inlierF)
        R.FailureStage="FundamentalFailure"; return;
    end
    R.FundamentalInliers=sum(inlierF);
    try
        [E,inlierE,statusE] = estimateEssentialMatrix( ...
            p1,p2,intrinsics,'Confidence',confidence,'MaxNumTrials',numTrials);
    catch
        R.FailureStage="EssentialFailure"; return;
    end
    if statusE~=0 || isempty(E) || isempty(inlierE)
        R.FailureStage="EssentialFailure"; return;
    end
    if sum(inlierE)<8
        R.FailureStage="TooFewEssentialInliers"; return;
    end
    p1E=p1(inlierE,:); p2E=p2(inlierE,:);
    bestVF=-inf; bestR=[]; bestT=[];
    if ndims(E)==3, nCandidates=size(E,3); else, nCandidates=1; end
    for candidate=1:nCandidates
        if nCandidates==1, Ec=E; else, Ec=E(:,:,candidate); end
        try
            [Rc,tc,vfc] = relativeCameraPose(Ec,intrinsics,p1E,p2E);
        catch
            continue;
        end
        if ndims(Rc)==3
            for kk=1:size(Rc,3)
                if size(tc,1)<kk, continue; end
                if numel(vfc)>=kk, v=vfc(kk);
                elseif ~isempty(vfc), v=vfc(1);
                else, continue;
                end
                if isfinite(v) && v>bestVF
                    bestVF=v; bestR=Rc(:,:,kk); bestT=tc(kk,:);
                end
            end
        else
            if isempty(vfc), continue; end
            v=vfc(1);
            if isfinite(v) && v>bestVF
                bestVF=v; bestR=Rc;
                if size(tc,1)>1, bestT=tc(1,:); else, bestT=tc; end
            end
        end
    end
    if isempty(bestR) || isempty(bestT)
        R.FailureStage="PoseRecoveryFailure"; return;
    end
    R.ValidFraction=bestVF;
    % Translation validity is checked AFTER the VF test in the original.
    % We record it separately so applyVF keeps this ordering exactly.
    t=reshape(bestT,1,[]);
    if numel(t)~=3 || any(~isfinite(t)) || norm(t)<1e-12
        R.FailureStage="InvalidTranslation";
    else
        R.BaseSuccess=true;
        R.FailureStage="Recovered";
    end
end

function [recovered,stage] = applyVF(baseSuccess,vf,baseStage,threshold)
    recovered=baseSuccess & vf>=threshold;
    stage=baseStage;
    % Only entries that made it through pose recovery have a tested VF.
    canTest=(baseStage=="Recovered" | baseStage=="InvalidTranslation");
    stage(canTest & vf<threshold)="LowValidFraction";
end
