clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;

rng(1);

%% =========================================================
% EXPERIMENT 16
% Brightness-Matched Global Dimming Control
%
% Dataset:
% TUM RGB-D fr1/xyz
%
% Question:
% Does failure come from PWM rolling-shutter banding,
% or simply from reduced image brightness?
%% =========================================================


%% =========================================================
% 1. DATASET
% ==========================================================

datasetFolder = repoPaths.tumXYZ;

rgbFolder = fullfile(datasetFolder,'rgb');
gtFile = fullfile(datasetFolder,'groundtruth.txt');

files = dir(fullfile(rgbFolder,'*.png'));

fprintf('RGB images found: %d\n',length(files));


%% =========================================================
% 2. CAMERA INTRINSICS
% ==========================================================

fx = 517.3;
fy = 516.5;

cx = 318.6;
cy = 255.3;

imageSize = [480 640];

intrinsics = cameraIntrinsics( ...
    [fx fy], ...
    [cx cy], ...
    imageSize);


%% =========================================================
% 3. LOAD GROUND TRUTH
% ==========================================================

gtData = readmatrix( ...
    gtFile, ...
    'FileType','text', ...
    'CommentStyle','#');

gtData = gtData(~any(isnan(gtData),2),:);

gtTime = gtData(:,1);

fprintf('Ground-truth poses loaded: %d\n',size(gtData,1));


%% =========================================================
% 4. FRAME SETTINGS
% ==========================================================

startIdx = 100;

numPairs = 50;

frameGap = 3;


%% =========================================================
% 5. FIXED PWM SETTINGS
% ==========================================================

pwmFreq = 100;

exposureTime = 0.001;     % 1 ms

dutyCycle = 0.25;         % 25%

modulationDepth = 0.90;

readoutTime = 0.020;

numSamples = 100;


%% =========================================================
% 6. SELECTED PHASE OFFSETS
% ==========================================================

phaseOffsets = [ ...
    0 ...
    0.125 ...
    0.25 ...
    0.50 ...
    0.875];

numPhases = length(phaseOffsets);


%% =========================================================
% 7. STORAGE
% ==========================================================

cleanInliers = zeros(numPairs,1);

pwmInliers = zeros(numPairs,numPhases);

uniformInliers = zeros(numPairs,numPhases);

pwmRetention = nan(numPairs,numPhases);

uniformRetention = nan(numPairs,numPhases);


pwmPoseSuccess = false(numPairs,numPhases);

uniformPoseSuccess = false(numPairs,numPhases);


pwmRotationError = nan(numPairs,numPhases);

uniformRotationError = nan(numPairs,numPhases);


pwmTranslationError = nan(numPairs,numPhases);

uniformTranslationError = nan(numPairs,numPhases);


meanGainFrame1 = nan(numPairs,numPhases);

meanGainFrame2 = nan(numPairs,numPhases);


%% =========================================================
% 8. MAIN LOOP
% ==========================================================

for k = 1:numPairs

    fprintf('\nPair %d/%d\n',k,numPairs);

    idx1 = startIdx + k - 1;
    idx2 = idx1 + frameGap;


    %% -----------------------------------------------------
    % Images
    % ------------------------------------------------------

    img1 = imread( ...
        fullfile(rgbFolder,files(idx1).name));

    img2 = imread( ...
        fullfile(rgbFolder,files(idx2).name));


    %% -----------------------------------------------------
    % Timestamps
    % ------------------------------------------------------

    rgbTime1 = ...
        str2double(erase(files(idx1).name,'.png'));

    rgbTime2 = ...
        str2double(erase(files(idx2).name,'.png'));


    %% -----------------------------------------------------
    % Ground truth
    % ------------------------------------------------------

    [~,gtIdx1] = min(abs(gtTime-rgbTime1));
    [~,gtIdx2] = min(abs(gtTime-rgbTime2));

    t1World = gtData(gtIdx1,2:4)';
    t2World = gtData(gtIdx2,2:4)';

    q1 = gtData(gtIdx1,5:8);
    q2 = gtData(gtIdx2,5:8);

    R1 = quatToRotationMatrix(q1);
    R2 = quatToRotationMatrix(q2);

    Rgt = R1' * R2;

    tgt = R1' * (t2World-t1World);

    if norm(tgt) > 1e-9

        tgt = tgt/norm(tgt);

    else

        tgt = [NaN;NaN;NaN];

    end


    %% =====================================================
    % CLEAN BASELINE
    % ======================================================

    cleanInliers(k) = ...
        countGeometricInliers(img1,img2);


    %% =====================================================
    % PHASE LOOP
    % ======================================================

    for p = 1:numPhases

        phaseOffset = phaseOffsets(p);


        %% -------------------------------------------------
        % Generate PWM image + obtain average gains
        % --------------------------------------------------

        [pwm1,pwm2,gain1,gain2] = ...
            simulatePWMwithPhaseOffset( ...
            img1,img2, ...
            pwmFreq, ...
            exposureTime, ...
            dutyCycle, ...
            modulationDepth, ...
            readoutTime, ...
            numSamples, ...
            phaseOffset);


        meanGainFrame1(k,p) = gain1;
        meanGainFrame2(k,p) = gain2;


        %% -------------------------------------------------
        % BRIGHTNESS-MATCHED UNIFORM IMAGES
        %
        % Same average brightness as PWM image,
        % but NO horizontal row pattern.
        % --------------------------------------------------

        uniform1 = im2double(img1) * gain1;
        uniform2 = im2double(img2) * gain2;

        uniform1 = min(max(uniform1,0),1);
        uniform2 = min(max(uniform2,0),1);


        %% =================================================
        % GEOMETRIC INLIERS
        % ==================================================

        pwmInliers(k,p) = ...
            countGeometricInliers(pwm1,pwm2);

        uniformInliers(k,p) = ...
            countGeometricInliers( ...
            uniform1,uniform2);


        if cleanInliers(k) > 0

            pwmRetention(k,p) = ...
                100*pwmInliers(k,p) ...
                /cleanInliers(k);

            uniformRetention(k,p) = ...
                100*uniformInliers(k,p) ...
                /cleanInliers(k);

        end


        %% =================================================
        % PWM POSE
        % ==================================================

        [successPWM,Rpwm,tpwm] = ...
            estimateRelativeMotion( ...
            pwm1,pwm2,intrinsics);

        if successPWM

            pwmPoseSuccess(k,p) = true;

            pwmRotationError(k,p) = ...
                rotationDifferenceDegrees( ...
                Rpwm,Rgt);

            if ~any(isnan(tgt))

                pwmTranslationError(k,p) = ...
                    vectorAngleDegrees( ...
                    tpwm,tgt);

            end

        end


        %% =================================================
        % UNIFORM DIMMING POSE
        % ==================================================

        [successUniform,Runiform,tuniform] = ...
            estimateRelativeMotion( ...
            uniform1, ...
            uniform2, ...
            intrinsics);

        if successUniform

            uniformPoseSuccess(k,p) = true;

            uniformRotationError(k,p) = ...
                rotationDifferenceDegrees( ...
                Runiform,Rgt);

            if ~any(isnan(tgt))

                uniformTranslationError(k,p) = ...
                    vectorAngleDegrees( ...
                    tuniform,tgt);

            end

        end

    end

end


%% =========================================================
% 9. SUMMARY
% ==========================================================

meanPWMRetention = ...
    mean(pwmRetention,1,'omitnan');

meanUniformRetention = ...
    mean(uniformRetention,1,'omitnan');


pwmFailure = ...
    100 - 100*sum(pwmPoseSuccess,1)/numPairs;

uniformFailure = ...
    100 - 100*sum(uniformPoseSuccess,1)/numPairs;


meanPWMRot = ...
    mean(pwmRotationError,1,'omitnan');

meanUniformRot = ...
    mean(uniformRotationError,1,'omitnan');


meanPWMTrans = ...
    mean(pwmTranslationError,1,'omitnan');

meanUniformTrans = ...
    mean(uniformTranslationError,1,'omitnan');


avgGain1 = ...
    mean(meanGainFrame1,1,'omitnan');

avgGain2 = ...
    mean(meanGainFrame2,1,'omitnan');


%% =========================================================
% 10. PRINT RESULTS
% ==========================================================

fprintf('\n\n========================================\n');
fprintf('EXPERIMENT 16 FINAL RESULTS\n');
fprintf('========================================\n');

for p = 1:numPhases

    fprintf('\n----------------------------------------\n');

    fprintf('Phase offset = %.3f cycles\n', ...
        phaseOffsets(p));

    fprintf('Average gain frame 1 = %.3f\n', ...
        avgGain1(p));

    fprintf('Average gain frame 2 = %.3f\n', ...
        avgGain2(p));


    fprintf('\nPWM rolling shutter:\n');

    fprintf('Inlier retention = %.2f%%\n', ...
        meanPWMRetention(p));

    fprintf('Pose failure = %.2f%%\n', ...
        pwmFailure(p));

    fprintf('Rotation error = %.3f deg\n', ...
        meanPWMRot(p));

    fprintf('Translation error = %.3f deg\n', ...
        meanPWMTrans(p));


    fprintf('\nBrightness-matched uniform:\n');

    fprintf('Inlier retention = %.2f%%\n', ...
        meanUniformRetention(p));

    fprintf('Pose failure = %.2f%%\n', ...
        uniformFailure(p));

    fprintf('Rotation error = %.3f deg\n', ...
        meanUniformRot(p));

    fprintf('Translation error = %.3f deg\n', ...
        meanUniformTrans(p));

end


%% =========================================================
% 11. SAVE TABLE
% ==========================================================

PhaseOffset = phaseOffsets';

MeanPWMinlierRetention = meanPWMRetention';

MeanUniformInlierRetention = meanUniformRetention';

PWMPoseFailurePercent = pwmFailure';

UniformPoseFailurePercent = uniformFailure';

PWMRotationErrorDeg = meanPWMRot';

UniformRotationErrorDeg = meanUniformRot';

PWMTranslationErrorDeg = meanPWMTrans';

UniformTranslationErrorDeg = meanUniformTrans';

AverageGainFrame1 = avgGain1';

AverageGainFrame2 = avgGain2';


results = table( ...
    PhaseOffset, ...
    AverageGainFrame1, ...
    AverageGainFrame2, ...
    MeanPWMinlierRetention, ...
    MeanUniformInlierRetention, ...
    PWMPoseFailurePercent, ...
    UniformPoseFailurePercent, ...
    PWMRotationErrorDeg, ...
    UniformRotationErrorDeg, ...
    PWMTranslationErrorDeg, ...
    UniformTranslationErrorDeg);

disp(results);


writetable( ...
    results, ...
    repository_output(repoPaths,'brightness_control/experiment16_brightness_control.csv'));


%% =========================================================
% 12. INLIER RETENTION COMPARISON
% ==========================================================

figure;

plot( ...
    phaseOffsets, ...
    meanPWMRetention, ...
    '-o', ...
    'LineWidth',1.5);

hold on;

plot( ...
    phaseOffsets, ...
    meanUniformRetention, ...
    '-s', ...
    'LineWidth',1.5);

xlabel('PWM Phase Offset (cycles)');

ylabel('Geometric-Inlier Retention (%)');

title('PWM Banding vs Brightness-Matched Uniform Dimming');

legend( ...
    'PWM Rolling Shutter', ...
    'Uniform Dimming', ...
    'Location','best');

grid on;


%% =========================================================
% 13. POSE FAILURE COMPARISON
% ==========================================================

figure;

plot( ...
    phaseOffsets, ...
    pwmFailure, ...
    '-o', ...
    'LineWidth',1.5);

hold on;

plot( ...
    phaseOffsets, ...
    uniformFailure, ...
    '-s', ...
    'LineWidth',1.5);

xlabel('PWM Phase Offset (cycles)');

ylabel('Pose Failure Rate (%)');

title('Pose Failure: PWM vs Brightness-Matched Control');

legend( ...
    'PWM Rolling Shutter', ...
    'Uniform Dimming', ...
    'Location','best');

ylim([0 100]);

grid on;


%% =========================================================
% 14. ROTATION ERROR
% ==========================================================

figure;

plot( ...
    phaseOffsets, ...
    meanPWMRot, ...
    '-o', ...
    'LineWidth',1.5);

hold on;

plot( ...
    phaseOffsets, ...
    meanUniformRot, ...
    '-s', ...
    'LineWidth',1.5);

xlabel('PWM Phase Offset (cycles)');

ylabel('Rotation Error (degrees)');

title('Rotation Error: PWM vs Uniform Dimming');

legend( ...
    'PWM Rolling Shutter', ...
    'Uniform Dimming', ...
    'Location','best');

grid on;


%% =========================================================
% 15. TRANSLATION ERROR
% ==========================================================

figure;

plot( ...
    phaseOffsets, ...
    meanPWMTrans, ...
    '-o', ...
    'LineWidth',1.5);

hold on;

plot( ...
    phaseOffsets, ...
    meanUniformTrans, ...
    '-s', ...
    'LineWidth',1.5);

xlabel('PWM Phase Offset (cycles)');

ylabel('Translation Direction Error (degrees)');

title('Translation Error: PWM vs Uniform Dimming');

legend( ...
    'PWM Rolling Shutter', ...
    'Uniform Dimming', ...
    'Location','best');

grid on;


%% =========================================================
% PWM SIMULATOR
% Returns mean gain for brightness-matched control
% ==========================================================

function [flicker1,flicker2,meanGain1,meanGain2] = ...
    simulatePWMwithPhaseOffset( ...
    img1,img2, ...
    pwmFreq, ...
    exposureTime, ...
    dutyCycle, ...
    modulationDepth, ...
    readoutTime, ...
    numSamples, ...
    phaseOffset)

flicker1 = im2double(img1);
flicker2 = im2double(img2);

[h,~,~] = size(flicker1);

rowTime = readoutTime/h;

gain1 = zeros(h,1);
gain2 = zeros(h,1);

for r = 1:h

    rowStart = (r-1)*rowTime;


    %% Frame 1

    times1 = linspace( ...
        rowStart, ...
        rowStart+exposureTime, ...
        numSamples);

    phase1 = mod(times1*pwmFreq,1);

    led1 = phase1 < dutyCycle;

    intensity1 = ones(size(times1));

    intensity1(~led1) = ...
        1-modulationDepth;

    gain1(r) = mean(intensity1);


    %% Frame 2

    times2 = linspace( ...
        rowStart, ...
        rowStart+exposureTime, ...
        numSamples);

    phase2 = mod( ...
        times2*pwmFreq + phaseOffset,1);

    led2 = phase2 < dutyCycle;

    intensity2 = ones(size(times2));

    intensity2(~led2) = ...
        1-modulationDepth;

    gain2(r) = mean(intensity2);

end


for r = 1:h

    flicker1(r,:,:) = ...
        flicker1(r,:,:) * gain1(r);

    flicker2(r,:,:) = ...
        flicker2(r,:,:) * gain2(r);

end


% Average brightness multipliers

meanGain1 = mean(gain1);

meanGain2 = mean(gain2);

end


%% =========================================================
% GEOMETRIC INLIERS
% ==========================================================

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

pairs = matchFeatures( ...
    f1,f2, ...
    'Unique',true, ...
    'MaxRatio',0.7);

if size(pairs,1) < 8
    return;
end

m1 = v1(pairs(:,1));
m2 = v2(pairs(:,2));

try

    [~,mask] = estimateFundamentalMatrix( ...
        m1.Location, ...
        m2.Location, ...
        'Method','RANSAC', ...
        'NumTrials',2000, ...
        'DistanceThreshold',1.5, ...
        'Confidence',99.9);

    nInliers = sum(mask);

catch

    nInliers = 0;

end

end


%% =========================================================
% RELATIVE MOTION
% ==========================================================

function [success,R,t] = ...
    estimateRelativeMotion(img1,img2,intrinsics)

success = false;

R = eye(3);

t = [NaN;NaN;NaN];

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
    features1,features2, ...
    'Unique',true, ...
    'MaxRatio',0.7);

if size(indexPairs,1) < 8
    return;
end

matched1 = valid1(indexPairs(:,1));
matched2 = valid2(indexPairs(:,2));

try

    [E,inlierMask] = estimateEssentialMatrix( ...
        matched1.Location, ...
        matched2.Location, ...
        intrinsics, ...
        'Confidence',99.9, ...
        'MaxNumTrials',2000);

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
        relativeCameraPose( ...
        E, ...
        intrinsics, ...
        matched1.Location, ...
        matched2.Location);

catch

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

t = squeeze(location);
t = t(:);

if norm(t) < 1e-10
    return;
end

t = t/norm(t);

success = true;

end


%% =========================================================
% QUATERNION -> ROTATION
% ==========================================================

function R = quatToRotationMatrix(q)

qx = q(1);
qy = q(2);
qz = q(3);
qw = q(4);

n = sqrt(qx^2+qy^2+qz^2+qw^2);

qx = qx/n;
qy = qy/n;
qz = qz/n;
qw = qw/n;

R = [

1-2*(qy^2+qz^2), ...
2*(qx*qy-qz*qw), ...
2*(qx*qz+qy*qw);

2*(qx*qy+qz*qw), ...
1-2*(qx^2+qz^2), ...
2*(qy*qz-qx*qw);

2*(qx*qz-qy*qw), ...
2*(qy*qz+qx*qw), ...
1-2*(qx^2+qy^2)

];

end


%% =========================================================
% ROTATION ERROR
% ==========================================================

function angleDeg = ...
    rotationDifferenceDegrees(Rest,Rgt)

Rest = squeeze(Rest);
Rgt = squeeze(Rgt);

if ndims(Rest) > 2
    Rest = Rest(:,:,1);
end

if ndims(Rgt) > 2
    Rgt = Rgt(:,:,1);
end

if ~isequal(size(Rest),[3 3]) || ...
        ~isequal(size(Rgt),[3 3])

    angleDeg = NaN;
    return;

end

Rerror = Rest*Rgt';

value = (trace(Rerror)-1)/2;

value = max(-1,min(1,value));

angleDeg = acosd(value);

end


%% =========================================================
% TRANSLATION-DIRECTION ERROR
% ==========================================================

function angleDeg = vectorAngleDegrees(a,b)

a = a(:);
b = b(:);

if norm(a)==0 || norm(b)==0

    angleDeg = NaN;
    return;

end

a = a/norm(a);
b = b/norm(b);

dotValue = dot(a,b);

dotValue = max(-1,min(1,dotValue));

angle1 = acosd(dotValue);

angle2 = 180-angle1;

angleDeg = min(angle1,angle2);

end