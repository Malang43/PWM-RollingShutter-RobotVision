clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;
rng(1);

%% EXPERIMENT 18B — GT pose-accuracy validation
% Dataset: TUM RGB-D fr1/xyz
% Same PWM/SURF/RANSAC settings as Experiment 18.
% Adds raw GT pose errors, GT baseline, validFraction, accuracy rates,
% pair-level CSV, and phase offset in milliseconds.

%% 1. DATASET
datasetFolder = repoPaths.tumXYZ;
rgbFolder = fullfile(datasetFolder,'rgb');
gtFile = fullfile(datasetFolder,'groundtruth.txt');

files = dir(fullfile(rgbFolder,'*.png'));

rgbTimesAll = zeros(numel(files),1);
for i = 1:numel(files)
    rgbTimesAll(i) = str2double(erase(files(i).name,'.png'));
end
[~,ord] = sort(rgbTimesAll);
files = files(ord);
rgbTimesAll = rgbTimesAll(ord);

fprintf('RGB images found: %d\n',numel(files));

outputFolder = repository_output(repoPaths,'legacy_statistics');
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% 2. CAMERA INTRINSICS
fx = 517.3; fy = 516.5; cx = 318.6; cy = 255.3;
imageSize = [480 640];
intrinsics = cameraIntrinsics([fx fy],[cx cy],imageSize);

%% 3. GROUND TRUTH
gtData = readmatrix(gtFile,'FileType','text','CommentStyle','#');
gtData = gtData(~any(isnan(gtData),2),:);
gtTime = gtData(:,1);
fprintf('Ground-truth poses loaded: %d\n',size(gtData,1));

%% 4. FRAME SETTINGS
startIdx = 100;
numPairs = 50;
frameGap = 3;

if startIdx + numPairs - 1 + frameGap > numel(files)
    error('Not enough RGB images for selected frame gap.');
end

%% 5. FIXED PWM SETTINGS
pwmFreq = 100;
exposureTime = 0.001;
dutyCycle = 0.25;
modulationDepth = 0.90;
numSamples = 100;

%% 6. PHASE AND READOUT SWEEP
phaseOffsets = [0 0.125 0.25 0.50 0.875];
readoutTimesMs = [5 10 15 20 25 30];
readoutTimes = readoutTimesMs/1000;
numPhases = numel(phaseOffsets);
numReadouts = numel(readoutTimes);

% Physical phase equivalent: delta_t = delta_phi / f_PWM
phaseShiftMs = 1000*phaseOffsets/pwmFreq;

%% 7. OPERATIONAL ACCURACY THRESHOLDS
% Analysis thresholds only; not universal VO/SLAM thresholds.
primaryRotThreshDeg = 5;
primaryTransThreshDeg = 20;

strictRotThreshDeg = 5;
strictTransThreshDeg = 10;

lenientRotThreshDeg = 10;
lenientTransThreshDeg = 30;

%% 8. STORAGE
cleanInliers = zeros(numPairs,1);
pwmInliers = zeros(numPairs,numPhases,numReadouts);
retention = nan(numPairs,numPhases,numReadouts);

poseSuccess = false(numPairs,numPhases,numReadouts);
validFractionAll = nan(numPairs,numPhases,numReadouts);

rotationError = nan(numPairs,numPhases,numReadouts);
translationErrorRaw = nan(numPairs,numPhases,numReadouts);
translationErrorSignInvariant = nan(numPairs,numPhases,numReadouts);

accuratePrimary = false(numPairs,numPhases,numReadouts);
accurateStrict = false(numPairs,numPhases,numReadouts);
accurateLenient = false(numPairs,numPhases,numReadouts);

rowGainStd = nan(numPairs,numPhases,numReadouts);

gtTranslationMagnitude = nan(numPairs,1);
gtAssocError1 = nan(numPairs,1);
gtAssocError2 = nan(numPairs,1);
rgbTime1All = nan(numPairs,1);
rgbTime2All = nan(numPairs,1);

%% 9. MAIN LOOP
for k = 1:numPairs
    fprintf('\nPair %d/%d\n',k,numPairs);

    idx1 = startIdx + k - 1;
    idx2 = idx1 + frameGap;

    img1 = imread(fullfile(rgbFolder,files(idx1).name));
    img2 = imread(fullfile(rgbFolder,files(idx2).name));

    rgbTime1 = rgbTimesAll(idx1);
    rgbTime2 = rgbTimesAll(idx2);
    rgbTime1All(k) = rgbTime1;
    rgbTime2All(k) = rgbTime2;

    [gtAssocError1(k),gtIdx1] = min(abs(gtTime-rgbTime1));
    [gtAssocError2(k),gtIdx2] = min(abs(gtTime-rgbTime2));

    C1w = gtData(gtIdx1,2:4)';
    C2w = gtData(gtIdx2,2:4)';

    q1 = gtData(gtIdx1,5:8);
    q2 = gtData(gtIdx2,5:8);

    R1cw = quatToRotationMatrix(q1);
    R2cw = quatToRotationMatrix(q2);

    % Camera 2 relative to camera 1
    Rgt = R1cw' * R2cw;

    tgtMetric = R1cw' * (C2w-C1w);
    gtTranslationMagnitude(k) = norm(tgtMetric);

    if gtTranslationMagnitude(k) > 1e-9
        tgt = tgtMetric/gtTranslationMagnitude(k);
    else
        tgt = [NaN;NaN;NaN];
    end

    cleanInliers(k) = countGeometricInliers(img1,img2);

    for p = 1:numPhases
        for r = 1:numReadouts

            [pwm1,pwm2,gain1,gain2] = simulatePWM( ...
                img1,img2,pwmFreq,exposureTime,dutyCycle, ...
                modulationDepth,readoutTimes(r),numSamples, ...
                phaseOffsets(p));

            rowGainStd(k,p,r) = (std(gain1)+std(gain2))/2;

            pwmInliers(k,p,r) = countGeometricInliers(pwm1,pwm2);

            if cleanInliers(k) > 0
                retention(k,p,r) = ...
                    100*pwmInliers(k,p,r)/cleanInliers(k);
            end

            [success,Rest,test,validFraction] = ...
                estimateRelativeMotion(pwm1,pwm2,intrinsics);

            validFractionAll(k,p,r) = validFraction;

            if success
                poseSuccess(k,p,r) = true;

                rotationError(k,p,r) = ...
                    rotationDifferenceDegrees(Rest,Rgt);

                if ~any(isnan(tgt))
                    rawAngle = vectorAngleRawDegrees(test,tgt);
                    translationErrorRaw(k,p,r) = rawAngle;

                    % Keep the old sign-invariant quantity only as
                    % a secondary diagnostic.
                    translationErrorSignInvariant(k,p,r) = ...
                        min(rawAngle,180-rawAngle);
                end

                % Primary accuracy uses RAW cheirality-resolved direction.
                accuratePrimary(k,p,r) = ...
                    rotationError(k,p,r) <= primaryRotThreshDeg && ...
                    translationErrorRaw(k,p,r) <= primaryTransThreshDeg;

                accurateStrict(k,p,r) = ...
                    rotationError(k,p,r) <= strictRotThreshDeg && ...
                    translationErrorRaw(k,p,r) <= strictTransThreshDeg;

                accurateLenient(k,p,r) = ...
                    rotationError(k,p,r) <= lenientRotThreshDeg && ...
                    translationErrorRaw(k,p,r) <= lenientTransThreshDeg;
            end
        end
    end
end

%% 10. GT ASSOCIATION / BASELINE CHECK
fprintf('\n========================================\n');
fprintf('GROUND-TRUTH CHECK\n');
fprintf('========================================\n');
fprintf('Max RGB->GT time error frame 1: %.6f s\n',max(gtAssocError1));
fprintf('Max RGB->GT time error frame 2: %.6f s\n',max(gtAssocError2));
fprintf('Mean GT translation: %.4f m\n',mean(gtTranslationMagnitude,'omitnan'));
fprintf('Median GT translation: %.4f m\n',median(gtTranslationMagnitude,'omitnan'));
fprintf('Minimum GT translation: %.4f m\n',min(gtTranslationMagnitude));

%% 11. CONDITION-LEVEL SUMMARY
meanRetention = nan(numPhases,numReadouts);
failureRate = nan(numPhases,numReadouts);
accurateRatePrimary = nan(numPhases,numReadouts);
accurateRateStrict = nan(numPhases,numReadouts);
accurateRateLenient = nan(numPhases,numReadouts);

medianRotation = nan(numPhases,numReadouts);
medianTranslationRaw = nan(numPhases,numReadouts);
medianTranslationSignInvariant = nan(numPhases,numReadouts);
meanRowGainStd = nan(numPhases,numReadouts);
medianPWMInliers = nan(numPhases,numReadouts);

for p = 1:numPhases
    for r = 1:numReadouts
        meanRetention(p,r) = mean(retention(:,p,r),'omitnan');

        failureRate(p,r) = ...
            100*(1-sum(poseSuccess(:,p,r))/numPairs);

        accurateRatePrimary(p,r) = ...
            100*sum(accuratePrimary(:,p,r))/numPairs;

        accurateRateStrict(p,r) = ...
            100*sum(accurateStrict(:,p,r))/numPairs;

        accurateRateLenient(p,r) = ...
            100*sum(accurateLenient(:,p,r))/numPairs;

        medianRotation(p,r) = ...
            median(rotationError(:,p,r),'omitnan');

        medianTranslationRaw(p,r) = ...
            median(translationErrorRaw(:,p,r),'omitnan');

        medianTranslationSignInvariant(p,r) = ...
            median(translationErrorSignInvariant(:,p,r),'omitnan');

        meanRowGainStd(p,r) = ...
            mean(rowGainStd(:,p,r),'omitnan');

        medianPWMInliers(p,r) = ...
            median(pwmInliers(:,p,r),'omitnan');
    end
end

%% 12. PRINT RESULTS
fprintf('\n========================================\n');
fprintf('EXPERIMENT 18B GT POSE-ACCURACY RESULTS\n');
fprintf('Primary: Rot <= %.1f deg AND raw T <= %.1f deg\n', ...
    primaryRotThreshDeg,primaryTransThreshDeg);
fprintf('========================================\n');

for p = 1:numPhases
    fprintf('\nPHASE %.3f cycles = %.3f ms at %d Hz\n', ...
        phaseOffsets(p),phaseShiftMs(p),pwmFreq);

    for r = 1:numReadouts
        fprintf(['Readout %2d ms | Ret %.2f%% | Fail %.1f%% | ' ...
            'Acc %.1f%% | MedRot %.2f deg | MedTraw %.2f deg | ' ...
            'MedTsigninv %.2f deg\n'], ...
            readoutTimesMs(r), ...
            meanRetention(p,r), ...
            failureRate(p,r), ...
            accurateRatePrimary(p,r), ...
            medianRotation(p,r), ...
            medianTranslationRaw(p,r), ...
            medianTranslationSignInvariant(p,r));
    end
end

%% 13. CONDITION-LEVEL CSV
nCond = numPhases*numReadouts;

PhaseOffset = zeros(nCond,1);
PhaseShiftMs = zeros(nCond,1);
ReadoutTimeMs = zeros(nCond,1);
MeanRowGainStd = zeros(nCond,1);
MeanInlierRetentionPercent = zeros(nCond,1);
MedianPWMInliers = zeros(nCond,1);
PoseFailurePercent = zeros(nCond,1);
AccuratePosePercent_Primary_5deg20deg = zeros(nCond,1);
AccuratePosePercent_Strict_5deg10deg = zeros(nCond,1);
AccuratePosePercent_Lenient_10deg30deg = zeros(nCond,1);
MedianRotationErrorDeg = zeros(nCond,1);
MedianTranslationRawErrorDeg = zeros(nCond,1);
MedianTranslationSignInvariantErrorDeg = zeros(nCond,1);

c = 0;
for p = 1:numPhases
    for r = 1:numReadouts
        c = c+1;
        PhaseOffset(c) = phaseOffsets(p);
        PhaseShiftMs(c) = phaseShiftMs(p);
        ReadoutTimeMs(c) = readoutTimesMs(r);
        MeanRowGainStd(c) = meanRowGainStd(p,r);
        MeanInlierRetentionPercent(c) = meanRetention(p,r);
        MedianPWMInliers(c) = medianPWMInliers(p,r);
        PoseFailurePercent(c) = failureRate(p,r);
        AccuratePosePercent_Primary_5deg20deg(c) = ...
            accurateRatePrimary(p,r);
        AccuratePosePercent_Strict_5deg10deg(c) = ...
            accurateRateStrict(p,r);
        AccuratePosePercent_Lenient_10deg30deg(c) = ...
            accurateRateLenient(p,r);
        MedianRotationErrorDeg(c) = medianRotation(p,r);
        MedianTranslationRawErrorDeg(c) = medianTranslationRaw(p,r);
        MedianTranslationSignInvariantErrorDeg(c) = ...
            medianTranslationSignInvariant(p,r);
    end
end

conditionResults = table( ...
    PhaseOffset,PhaseShiftMs,ReadoutTimeMs,MeanRowGainStd, ...
    MeanInlierRetentionPercent,MedianPWMInliers,PoseFailurePercent, ...
    AccuratePosePercent_Primary_5deg20deg, ...
    AccuratePosePercent_Strict_5deg10deg, ...
    AccuratePosePercent_Lenient_10deg30deg, ...
    MedianRotationErrorDeg,MedianTranslationRawErrorDeg, ...
    MedianTranslationSignInvariantErrorDeg);

writetable(conditionResults,fullfile(outputFolder, ...
    'experiment18B_condition_summary.csv'));

%% 14. FULL PAIR-LEVEL CSV
nRows = numPairs*numPhases*numReadouts;

PairIndex = zeros(nRows,1);
Frame1Timestamp = zeros(nRows,1);
Frame2Timestamp = zeros(nRows,1);
GTAssocErrorFrame1_s = zeros(nRows,1);
GTAssocErrorFrame2_s = zeros(nRows,1);
GTTranslationMagnitude_m = zeros(nRows,1);
PhaseOffset_pair = zeros(nRows,1);
PhaseShiftMs_pair = zeros(nRows,1);
ReadoutTimeMs_pair = zeros(nRows,1);
CleanInliers = zeros(nRows,1);
PWMInliers = zeros(nRows,1);
InlierRetentionPercent = nan(nRows,1);
PoseRecovered = false(nRows,1);
ValidCheiralityFraction = nan(nRows,1);
RotationErrorDeg = nan(nRows,1);
TranslationRawErrorDeg = nan(nRows,1);
TranslationSignInvariantErrorDeg = nan(nRows,1);
AccuratePrimary_5deg20deg = false(nRows,1);
AccurateStrict_5deg10deg = false(nRows,1);
AccurateLenient_10deg30deg = false(nRows,1);
RowGainStd = nan(nRows,1);

c = 0;
for k = 1:numPairs
    for p = 1:numPhases
        for r = 1:numReadouts
            c = c+1;
            PairIndex(c) = k;
            Frame1Timestamp(c) = rgbTime1All(k);
            Frame2Timestamp(c) = rgbTime2All(k);
            GTAssocErrorFrame1_s(c) = gtAssocError1(k);
            GTAssocErrorFrame2_s(c) = gtAssocError2(k);
            GTTranslationMagnitude_m(c) = gtTranslationMagnitude(k);
            PhaseOffset_pair(c) = phaseOffsets(p);
            PhaseShiftMs_pair(c) = phaseShiftMs(p);
            ReadoutTimeMs_pair(c) = readoutTimesMs(r);
            CleanInliers(c) = cleanInliers(k);
            PWMInliers(c) = pwmInliers(k,p,r);
            InlierRetentionPercent(c) = retention(k,p,r);
            PoseRecovered(c) = poseSuccess(k,p,r);
            ValidCheiralityFraction(c) = validFractionAll(k,p,r);
            RotationErrorDeg(c) = rotationError(k,p,r);
            TranslationRawErrorDeg(c) = translationErrorRaw(k,p,r);
            TranslationSignInvariantErrorDeg(c) = ...
                translationErrorSignInvariant(k,p,r);
            AccuratePrimary_5deg20deg(c) = accuratePrimary(k,p,r);
            AccurateStrict_5deg10deg(c) = accurateStrict(k,p,r);
            AccurateLenient_10deg30deg(c) = accurateLenient(k,p,r);
            RowGainStd(c) = rowGainStd(k,p,r);
        end
    end
end

pairResults = table( ...
    PairIndex,Frame1Timestamp,Frame2Timestamp, ...
    GTAssocErrorFrame1_s,GTAssocErrorFrame2_s, ...
    GTTranslationMagnitude_m, ...
    PhaseOffset_pair,PhaseShiftMs_pair,ReadoutTimeMs_pair, ...
    CleanInliers,PWMInliers,InlierRetentionPercent, ...
    PoseRecovered,ValidCheiralityFraction, ...
    RotationErrorDeg,TranslationRawErrorDeg, ...
    TranslationSignInvariantErrorDeg, ...
    AccuratePrimary_5deg20deg,AccurateStrict_5deg10deg, ...
    AccurateLenient_10deg30deg,RowGainStd);

pairResults.Properties.VariableNames(7:9) = ...
    {'PhaseOffset','PhaseShiftMs','ReadoutTimeMs'};

writetable(pairResults,fullfile(outputFolder, ...
    'experiment18B_pairwise_results.csv'));

%% 15. SAVE MAT FILE
save(fullfile(outputFolder,'experiment18B_pairwise_data.mat'), ...
    'phaseOffsets','phaseShiftMs','readoutTimesMs', ...
    'cleanInliers','pwmInliers','retention', ...
    'poseSuccess','validFractionAll', ...
    'rotationError','translationErrorRaw', ...
    'translationErrorSignInvariant', ...
    'accuratePrimary','accurateStrict','accurateLenient', ...
    'gtTranslationMagnitude','gtAssocError1','gtAssocError2', ...
    'rowGainStd');

%% 16. DIAGNOSTIC FIGURES ONLY
% Do NOT use these as final paper figures yet.

figure;
imagesc(readoutTimesMs,phaseOffsets,accurateRatePrimary);
set(gca,'YDir','normal');
colorbar;
xlabel('Rolling-Shutter Readout Time (ms)');
ylabel('Relative PWM Phase Offset (cycles)');
title('Accurate Pose Rate (%) - Primary 5 deg / 20 deg');
xticks(readoutTimesMs);
yticks(phaseOffsets);

figure;
imagesc(readoutTimesMs,phaseOffsets,medianRotation);
set(gca,'YDir','normal');
colorbar;
xlabel('Rolling-Shutter Readout Time (ms)');
ylabel('Relative PWM Phase Offset (cycles)');
title('Median Rotation Error (deg)');
xticks(readoutTimesMs);
yticks(phaseOffsets);

figure;
imagesc(readoutTimesMs,phaseOffsets,medianTranslationRaw);
set(gca,'YDir','normal');
colorbar;
xlabel('Rolling-Shutter Readout Time (ms)');
ylabel('Relative PWM Phase Offset (cycles)');
title('Median Raw Translation-Direction Error (deg)');
xticks(readoutTimesMs);
yticks(phaseOffsets);

fprintf('\nSaved outputs to:\n%s\n',outputFolder);

%% LOCAL FUNCTION 1: PWM + ROLLING-SHUTTER SIMULATOR
function [flicker1,flicker2,gain1,gain2] = simulatePWM( ...
    img1,img2,pwmFreq,exposureTime,dutyCycle, ...
    modulationDepth,readoutTime,numSamples,phaseOffset)

flicker1 = im2double(img1);
flicker2 = im2double(img2);
[h,~,~] = size(flicker1);
rowTime = readoutTime/h;

gain1 = zeros(h,1);
gain2 = zeros(h,1);

for row = 1:h
    rowStart = (row-1)*rowTime;

    times1 = linspace(rowStart,rowStart+exposureTime,numSamples);
    phase1 = mod(times1*pwmFreq,1);
    led1 = phase1 < dutyCycle;
    intensity1 = ones(size(times1));
    intensity1(~led1) = 1-modulationDepth;
    gain1(row) = mean(intensity1);

    times2 = linspace(rowStart,rowStart+exposureTime,numSamples);
    phase2 = mod(times2*pwmFreq+phaseOffset,1);
    led2 = phase2 < dutyCycle;
    intensity2 = ones(size(times2));
    intensity2(~led2) = 1-modulationDepth;
    gain2(row) = mean(intensity2);
end

for row = 1:h
    flicker1(row,:,:) = flicker1(row,:,:)*gain1(row);
    flicker2(row,:,:) = flicker2(row,:,:)*gain2(row);
end

flicker1 = min(max(flicker1,0),1);
flicker2 = min(max(flicker2,0),1);
end

%% LOCAL FUNCTION 2: GEOMETRIC INLIERS
function nInliers = countGeometricInliers(img1,img2)

nInliers = 0;
gray1 = rgb2gray(im2uint8(img1));
gray2 = rgb2gray(im2uint8(img2));

p1 = detectSURFFeatures(gray1);
p2 = detectSURFFeatures(gray2);

if p1.Count < 8 || p2.Count < 8
    return;
end

[f1,v1] = extractFeatures(gray1,p1);
[f2,v2] = extractFeatures(gray2,p2);

pairs = matchFeatures(f1,f2,'Unique',true,'MaxRatio',0.7);

if size(pairs,1) < 8
    return;
end

m1 = v1(pairs(:,1));
m2 = v2(pairs(:,2));

try
    [~,mask] = estimateFundamentalMatrix( ...
        m1.Location,m2.Location, ...
        'Method','RANSAC', ...
        'NumTrials',2000, ...
        'DistanceThreshold',1.5, ...
        'Confidence',99.9);
    nInliers = sum(mask);
catch
    nInliers = 0;
end
end

%% LOCAL FUNCTION 3: RELATIVE CAMERA MOTION
function [success,R,t,validFraction] = ...
    estimateRelativeMotion(img1,img2,intrinsics)

success = false;
R = eye(3);
t = [NaN;NaN;NaN];
validFraction = NaN;

gray1 = rgb2gray(im2uint8(img1));
gray2 = rgb2gray(im2uint8(img2));

points1 = detectSURFFeatures(gray1);
points2 = detectSURFFeatures(gray2);

if points1.Count < 20 || points2.Count < 20
    return;
end

[features1,valid1] = extractFeatures(gray1,points1);
[features2,valid2] = extractFeatures(gray2,points2);

indexPairs = matchFeatures( ...
    features1,features2,'Unique',true,'MaxRatio',0.7);

if size(indexPairs,1) < 8
    return;
end

matched1 = valid1(indexPairs(:,1));
matched2 = valid2(indexPairs(:,2));

try
    [E,inlierMask] = estimateEssentialMatrix( ...
        matched1.Location,matched2.Location,intrinsics, ...
        'Confidence',99.9,'MaxNumTrials',2000);
catch
    return;
end

if isempty(E)
    return;
end

matched1 = matched1(inlierMask);
matched2 = matched2(inlierMask);

if matched1.Count < 8
    return;
end

try
    [orientation,location,validFraction] = ...
        relativeCameraPose(E,intrinsics, ...
        matched1.Location,matched2.Location);
catch
    validFraction = NaN;
    return;
end

if isempty(validFraction) || ~isfinite(validFraction)
    validFraction = NaN;
    return;
end

if validFraction < 0.5
    return;
end

orientation = squeeze(orientation);
if ndims(orientation) > 2
    orientation = orientation(:,:,1);
end
if ~isequal(size(orientation),[3 3])
    return;
end
R = orientation;

location = squeeze(location);

if numel(location) == 3
    t = location(:);
elseif ismatrix(location) && size(location,2) == 3
    t = location(1,:)';
elseif ismatrix(location) && size(location,1) == 3
    t = location(:,1);
else
    return;
end

t = t(:);

if numel(t) ~= 3 || any(~isfinite(t)) || norm(t) < 1e-10
    return;
end

t = t/norm(t);
success = true;
end

%% LOCAL FUNCTION 4: TUM QUATERNION -> ROTATION MATRIX
function R = quatToRotationMatrix(q)

qx = q(1); qy = q(2); qz = q(3); qw = q(4);

n = sqrt(qx^2+qy^2+qz^2+qw^2);
if n < 1e-12
    R = eye(3);
    return;
end

qx = qx/n; qy = qy/n; qz = qz/n; qw = qw/n;

R = [ ...
    1-2*(qy^2+qz^2), 2*(qx*qy-qz*qw), 2*(qx*qz+qy*qw); ...
    2*(qx*qy+qz*qw), 1-2*(qx^2+qz^2), 2*(qy*qz-qx*qw); ...
    2*(qx*qz-qy*qw), 2*(qy*qz+qx*qw), 1-2*(qx^2+qy^2)];
end

%% LOCAL FUNCTION 5: ROTATION ERROR
function angleDeg = rotationDifferenceDegrees(Rest,Rgt)

Rest = squeeze(Rest);
Rgt = squeeze(Rgt);

if ndims(Rest)>2
    Rest = Rest(:,:,1);
end
if ndims(Rgt)>2
    Rgt = Rgt(:,:,1);
end

if ~isequal(size(Rest),[3 3]) || ~isequal(size(Rgt),[3 3])
    angleDeg = NaN;
    return;
end

if any(~isfinite(Rest(:))) || any(~isfinite(Rgt(:)))
    angleDeg = NaN;
    return;
end

Rerror = Rest*Rgt';
value = (trace(Rerror)-1)/2;
value = max(-1,min(1,value));
angleDeg = acosd(value);
end

%% LOCAL FUNCTION 6: RAW TRANSLATION-DIRECTION ERROR
function angleDeg = vectorAngleRawDegrees(a,b)

a = squeeze(a);
b = squeeze(b);
a = a(:);
b = b(:);

if numel(a) ~= 3 || numel(b) ~= 3
    angleDeg = NaN;
    return;
end

if any(~isfinite(a)) || any(~isfinite(b))
    angleDeg = NaN;
    return;
end

if norm(a) < 1e-10 || norm(b) < 1e-10
    angleDeg = NaN;
    return;
end

a = a/norm(a);
b = b/norm(b);

dotValue = dot(a,b);
dotValue = max(-1,min(1,dotValue));
angleDeg = acosd(dotValue);
end
