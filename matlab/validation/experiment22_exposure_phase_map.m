clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;

rng(1);

%% =========================================================
% EXPERIMENT 22
% Exposure Time x PWM Phase Offset
%
% Dataset:
% TUM RGB-D fr1/xyz
%
% Feature method:
% SURF
%
% Fixed:
% PWM frequency = 100 Hz
% Duty cycle = 25%
% Readout time = 20 ms
% Frame gap = 3
%
% Sweep:
% Exposure time
% Relative PWM phase offset
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
% 3. GROUND TRUTH
% ==========================================================

gtData = readmatrix( ...
    gtFile, ...
    'FileType','text', ...
    'CommentStyle','#');

gtData = gtData(~any(isnan(gtData),2),:);

gtTime = gtData(:,1);

fprintf('Ground-truth poses loaded: %d\n', ...
    size(gtData,1));


%% =========================================================
% 4. FRAME SETTINGS
% ==========================================================

startIdx = 100;

numPairs = 50;

frameGap = 3;

if startIdx + numPairs - 1 + frameGap > length(files)

    error('Not enough RGB images.');

end


%% =========================================================
% 5. FIXED PWM / CAMERA SETTINGS
% ==========================================================

pwmFreq = 100;

dutyCycle = 0.25;

modulationDepth = 0.90;

readoutTime = 0.020;

numSamples = 100;


%% =========================================================
% 6. EXPOSURE AND PHASE SWEEP
% ==========================================================

exposureTimesMs = [1 2 5 8 10];

exposureTimes = exposureTimesMs/1000;

phaseOffsets = [ ...
    0 ...
    0.125 ...
    0.25 ...
    0.50 ...
    0.875];

numExposures = length(exposureTimes);

numPhases = length(phaseOffsets);


%% =========================================================
% 7. STORAGE
%
% pair x exposure x phase
% ==========================================================

cleanInliers = zeros(numPairs,1);

pwmInliers = ...
    zeros(numPairs,numExposures,numPhases);

retention = ...
    nan(numPairs,numExposures,numPhases);

poseSuccess = ...
    false(numPairs,numExposures,numPhases);

rotationError = ...
    nan(numPairs,numExposures,numPhases);

translationError = ...
    nan(numPairs,numExposures,numPhases);

rowGainStd = ...
    nan(numPairs,numExposures,numPhases);


%% =========================================================
% 8. MAIN LOOP
% ==========================================================

for k = 1:numPairs

    fprintf('\n========================================\n');
    fprintf('Pair %d/%d\n',k,numPairs);
    fprintf('========================================\n');

    idx1 = startIdx + k - 1;
    idx2 = idx1 + frameGap;


    %% Images

    img1 = imread( ...
        fullfile(rgbFolder,files(idx1).name));

    img2 = imread( ...
        fullfile(rgbFolder,files(idx2).name));


    %% Timestamps

    rgbTime1 = ...
        str2double(erase(files(idx1).name,'.png'));

    rgbTime2 = ...
        str2double(erase(files(idx2).name,'.png'));


    %% Ground truth

    [~,gtIdx1] = min(abs(gtTime-rgbTime1));
    [~,gtIdx2] = min(abs(gtTime-rgbTime2));

    t1World = gtData(gtIdx1,2:4)';
    t2World = gtData(gtIdx2,2:4)';

    q1 = gtData(gtIdx1,5:8);
    q2 = gtData(gtIdx2,5:8);

    R1 = quatToRotationMatrix(q1);
    R2 = quatToRotationMatrix(q2);

    Rgt = R1' * R2;

    tgt = R1'*(t2World-t1World);

    if norm(tgt) > 1e-9

        tgt = tgt/norm(tgt);

    else

        tgt = [NaN;NaN;NaN];

    end


    %% =====================================================
    % CLEAN BASELINE
    % ======================================================

    cleanInliers(k) = ...
        countSURFGeometricInliers( ...
        img1,img2);


    %% =====================================================
    % EXPOSURE LOOP
    % ======================================================

    for e = 1:numExposures

        exposureTime = ...
            exposureTimes(e);


        %% =================================================
        % PHASE LOOP
        % ==================================================

        for p = 1:numPhases

            phaseOffset = ...
                phaseOffsets(p);


            %% PWM simulation

            [pwm1,pwm2,gain1,gain2] = ...
                simulatePWM( ...
                img1, ...
                img2, ...
                pwmFreq, ...
                exposureTime, ...
                dutyCycle, ...
                modulationDepth, ...
                readoutTime, ...
                numSamples, ...
                phaseOffset);


            %% Row-gain variation

            rowGainStd(k,e,p) = ...
                (std(gain1)+std(gain2))/2;


            %% Geometric inliers

            pwmInliers(k,e,p) = ...
                countSURFGeometricInliers( ...
                pwm1,pwm2);


            if cleanInliers(k) > 0

                retention(k,e,p) = ...
                    100 * ...
                    pwmInliers(k,e,p) ...
                    /cleanInliers(k);

            end


            %% Pose

            [success,Rest,test] = ...
                estimateSURFRelativeMotion( ...
                pwm1, ...
                pwm2, ...
                intrinsics);


            if success

                poseSuccess(k,e,p) = true;


                rotationError(k,e,p) = ...
                    rotationDifferenceDegrees( ...
                    Rest,Rgt);


                if ~any(isnan(tgt))

                    translationError(k,e,p) = ...
                        vectorAngleDegrees( ...
                        test,tgt);

                end

            end

        end

    end

end


%% =========================================================
% 9. SUMMARY MATRICES
%
% Rows = phase
% Columns = exposure
% ==========================================================

meanRetention = ...
    nan(numPhases,numExposures);

failureRate = ...
    nan(numPhases,numExposures);

meanRotation = ...
    nan(numPhases,numExposures);

medianRotation = ...
    nan(numPhases,numExposures);

meanTranslation = ...
    nan(numPhases,numExposures);

medianTranslation = ...
    nan(numPhases,numExposures);

meanRowGainStd = ...
    nan(numPhases,numExposures);


for p = 1:numPhases

    for e = 1:numExposures


        meanRetention(p,e) = ...
            mean( ...
            retention(:,e,p), ...
            'omitnan');


        failureRate(p,e) = ...
            100 - ...
            100*sum( ...
            poseSuccess(:,e,p)) ...
            /numPairs;


        meanRotation(p,e) = ...
            mean( ...
            rotationError(:,e,p), ...
            'omitnan');


        medianRotation(p,e) = ...
            median( ...
            rotationError(:,e,p), ...
            'omitnan');


        meanTranslation(p,e) = ...
            mean( ...
            translationError(:,e,p), ...
            'omitnan');


        medianTranslation(p,e) = ...
            median( ...
            translationError(:,e,p), ...
            'omitnan');


        meanRowGainStd(p,e) = ...
            mean( ...
            rowGainStd(:,e,p), ...
            'omitnan');

    end

end


%% =========================================================
% 10. PRINT RESULTS
% ==========================================================

fprintf('\n\n========================================\n');
fprintf('EXPERIMENT 22 FINAL RESULTS\n');
fprintf('========================================\n');


for e = 1:numExposures

    fprintf('\n========================================\n');

    fprintf( ...
        'EXPOSURE TIME = %.0f ms\n', ...
        exposureTimesMs(e));

    fprintf('========================================\n');


    for p = 1:numPhases

        fprintf('\nPhase offset = %.3f cycles\n', ...
            phaseOffsets(p));


        fprintf( ...
            'Mean row-gain STD = %.4f\n', ...
            meanRowGainStd(p,e));


        fprintf( ...
            'SURF inlier retention = %.2f%%\n', ...
            meanRetention(p,e));


        fprintf( ...
            'SURF pose failure = %.2f%%\n', ...
            failureRate(p,e));


        fprintf( ...
            'Mean rotation error = %.3f deg\n', ...
            meanRotation(p,e));


        fprintf( ...
            'Median rotation error = %.3f deg\n', ...
            medianRotation(p,e));


        fprintf( ...
            'Mean translation error = %.3f deg\n', ...
            meanTranslation(p,e));


        fprintf( ...
            'Median translation error = %.3f deg\n', ...
            medianTranslation(p,e));

    end

end


%% =========================================================
% 11. SAVE RESULTS TABLE
% ==========================================================

totalConditions = ...
    numExposures*numPhases;


ExposureTimeMs = ...
    zeros(totalConditions,1);

PhaseOffset = ...
    zeros(totalConditions,1);

MeanRowGainStd = ...
    zeros(totalConditions,1);

MeanSURFInlierRetentionPercent = ...
    zeros(totalConditions,1);

SURFPoseFailurePercent = ...
    zeros(totalConditions,1);

MeanRotationErrorDeg = ...
    zeros(totalConditions,1);

MedianRotationErrorDeg = ...
    zeros(totalConditions,1);

MeanTranslationErrorDeg = ...
    zeros(totalConditions,1);

MedianTranslationErrorDeg = ...
    zeros(totalConditions,1);


counter = 0;


for e = 1:numExposures

    for p = 1:numPhases

        counter = counter+1;


        ExposureTimeMs(counter) = ...
            exposureTimesMs(e);


        PhaseOffset(counter) = ...
            phaseOffsets(p);


        MeanRowGainStd(counter) = ...
            meanRowGainStd(p,e);


        MeanSURFInlierRetentionPercent(counter) = ...
            meanRetention(p,e);


        SURFPoseFailurePercent(counter) = ...
            failureRate(p,e);


        MeanRotationErrorDeg(counter) = ...
            meanRotation(p,e);


        MedianRotationErrorDeg(counter) = ...
            medianRotation(p,e);


        MeanTranslationErrorDeg(counter) = ...
            meanTranslation(p,e);


        MedianTranslationErrorDeg(counter) = ...
            medianTranslation(p,e);

    end

end


results = table( ...
    ExposureTimeMs, ...
    PhaseOffset, ...
    MeanRowGainStd, ...
    MeanSURFInlierRetentionPercent, ...
    SURFPoseFailurePercent, ...
    MeanRotationErrorDeg, ...
    MedianRotationErrorDeg, ...
    MeanTranslationErrorDeg, ...
    MedianTranslationErrorDeg);


disp(results);


writetable( ...
    results, ...
    repository_output(repoPaths,'parameter_sweeps/experiment22_exposure_phase_results.csv'));


save( ...
    repository_output(repoPaths,'parameter_sweeps/experiment22_exposure_phase_pairwise.mat'), ...
    'exposureTimesMs', ...
    'phaseOffsets', ...
    'retention', ...
    'poseSuccess', ...
    'rotationError', ...
    'translationError', ...
    'rowGainStd');


%% =========================================================
% 12. HEATMAP - INLIER RETENTION
% ==========================================================

figure;

imagesc( ...
    exposureTimesMs, ...
    phaseOffsets, ...
    meanRetention);

set(gca,'YDir','normal');

colorbar;

xlabel('Exposure Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('SURF Geometric-Inlier Retention (%)');

xticks(exposureTimesMs);

yticks(phaseOffsets);


for p = 1:numPhases

    for e = 1:numExposures

        text( ...
            exposureTimesMs(e), ...
            phaseOffsets(p), ...
            sprintf('%.1f', ...
            meanRetention(p,e)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end


%% =========================================================
% 13. HEATMAP - POSE FAILURE
% ==========================================================

figure;

imagesc( ...
    exposureTimesMs, ...
    phaseOffsets, ...
    failureRate);

set(gca,'YDir','normal');

colorbar;

xlabel('Exposure Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('SURF Pose Failure Rate (%)');

xticks(exposureTimesMs);

yticks(phaseOffsets);


for p = 1:numPhases

    for e = 1:numExposures

        text( ...
            exposureTimesMs(e), ...
            phaseOffsets(p), ...
            sprintf('%.0f', ...
            failureRate(p,e)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end


%% =========================================================
% 14. HEATMAP - ROW-GAIN VARIATION
% ==========================================================

figure;

imagesc( ...
    exposureTimesMs, ...
    phaseOffsets, ...
    meanRowGainStd);

set(gca,'YDir','normal');

colorbar;

xlabel('Exposure Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Row-Gain Standard Deviation');

xticks(exposureTimesMs);

yticks(phaseOffsets);


%% =========================================================
% 15. ROTATION ERROR HEATMAP
% ==========================================================

figure;

imagesc( ...
    exposureTimesMs, ...
    phaseOffsets, ...
    meanRotation);

set(gca,'YDir','normal');

colorbar;

xlabel('Exposure Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Rotation Error (degrees)');

xticks(exposureTimesMs);

yticks(phaseOffsets);


%% =========================================================
% 16. TRANSLATION ERROR HEATMAP
% ==========================================================

figure;

imagesc( ...
    exposureTimesMs, ...
    phaseOffsets, ...
    meanTranslation);

set(gca,'YDir','normal');

colorbar;

xlabel('Exposure Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Translation Direction Error (degrees)');

xticks(exposureTimesMs);

yticks(phaseOffsets);


%% =========================================================
% 17. FAILURE CURVES
% ==========================================================

figure;

for e = 1:numExposures

    plot( ...
        phaseOffsets, ...
        failureRate(:,e), ...
        '-o', ...
        'LineWidth',1.5);

    hold on;

end


xlabel('Relative PWM Phase Offset (cycles)');

ylabel('Pose Failure Rate (%)');

title('Phase Sensitivity at Different Exposure Times');

legend( ...
    string(exposureTimesMs)+" ms", ...
    'Location','best');

ylim([0 100]);

grid on;


%% =========================================================
% 18. RETENTION CURVES
% ==========================================================

figure;

for e = 1:numExposures

    plot( ...
        phaseOffsets, ...
        meanRetention(:,e), ...
        '-o', ...
        'LineWidth',1.5);

    hold on;

end


xlabel('Relative PWM Phase Offset (cycles)');

ylabel('Geometric-Inlier Retention (%)');

title('Feature Robustness at Different Exposure Times');

legend( ...
    string(exposureTimesMs)+" ms", ...
    'Location','best');

grid on;


%% =========================================================
% LOCAL FUNCTION 1
% PWM SIMULATOR
% ==========================================================

function [flicker1,flicker2,gain1,gain2] = ...
    simulatePWM( ...
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


rowTime = ...
    readoutTime/h;


gain1 = zeros(h,1);

gain2 = zeros(h,1);


for row = 1:h

    rowStart = ...
        (row-1)*rowTime;


    %% Frame 1

    times1 = linspace( ...
        rowStart, ...
        rowStart+exposureTime, ...
        numSamples);


    phase1 = mod( ...
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


    %% Frame 2

    times2 = linspace( ...
        rowStart, ...
        rowStart+exposureTime, ...
        numSamples);


    phase2 = mod( ...
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


for row = 1:h

    flicker1(row,:,:) = ...
        flicker1(row,:,:) * gain1(row);


    flicker2(row,:,:) = ...
        flicker2(row,:,:) * gain2(row);

end


flicker1 = ...
    min(max(flicker1,0),1);

flicker2 = ...
    min(max(flicker2,0),1);

end


%% =========================================================
% LOCAL FUNCTION 2
% SURF GEOMETRIC INLIERS
% ==========================================================

function nInliers = ...
    countSURFGeometricInliers( ...
    img1,img2)


nInliers = 0;


gray1 = ...
    rgb2gray(im2uint8(img1));

gray2 = ...
    rgb2gray(im2uint8(img2));


points1 = ...
    detectSURFFeatures(gray1);

points2 = ...
    detectSURFFeatures(gray2);


if points1.Count < 8 || ...
        points2.Count < 8

    return;

end


[features1,valid1] = ...
    extractFeatures( ...
    gray1,points1);


[features2,valid2] = ...
    extractFeatures( ...
    gray2,points2);


pairs = ...
    matchFeatures( ...
    features1, ...
    features2, ...
    'Unique',true, ...
    'MaxRatio',0.7);


if size(pairs,1) < 8

    return;

end


matched1 = ...
    valid1(pairs(:,1));

matched2 = ...
    valid2(pairs(:,2));


try

    [~,mask] = ...
        estimateFundamentalMatrix( ...
        matched1.Location, ...
        matched2.Location, ...
        'Method','RANSAC', ...
        'NumTrials',2000, ...
        'DistanceThreshold',1.5, ...
        'Confidence',99.9);


    nInliers = ...
        sum(mask);

catch

    nInliers = 0;

end

end


%% =========================================================
% LOCAL FUNCTION 3
% SURF RELATIVE MOTION
% ==========================================================

function [success,R,t] = ...
    estimateSURFRelativeMotion( ...
    img1,img2,intrinsics)


success = false;

R = eye(3);

t = [NaN;NaN;NaN];


gray1 = ...
    rgb2gray(im2uint8(img1));

gray2 = ...
    rgb2gray(im2uint8(img2));


points1 = ...
    detectSURFFeatures(gray1);

points2 = ...
    detectSURFFeatures(gray2);


if points1.Count < 20 || ...
        points2.Count < 20

    return;

end


[features1,valid1] = ...
    extractFeatures( ...
    gray1,points1);


[features2,valid2] = ...
    extractFeatures( ...
    gray2,points2);


indexPairs = ...
    matchFeatures( ...
    features1, ...
    features2, ...
    'Unique',true, ...
    'MaxRatio',0.7);


if size(indexPairs,1) < 8

    return;

end


matched1 = ...
    valid1(indexPairs(:,1));

matched2 = ...
    valid2(indexPairs(:,2));


try

    [E,inlierMask] = ...
        estimateEssentialMatrix( ...
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


if isempty(validFraction) || ...
        ~isfinite(validFraction)

    return;

end


if validFraction < 0.5

    return;

end


%% Orientation

orientation = squeeze(orientation);


if ndims(orientation) > 2

    orientation = orientation(:,:,1);

end


if ~isequal(size(orientation),[3 3])

    return;

end


R = orientation;


%% Translation

location = squeeze(location);


if numel(location) == 3

    t = location(:);


elseif ismatrix(location) && ...
        size(location,2) == 3

    t = location(1,:)';


elseif ismatrix(location) && ...
        size(location,1) == 3

    t = location(:,1);


else

    return;

end


t = t(:);


if numel(t) ~= 3

    return;

end


if any(~isfinite(t))

    return;

end


if norm(t) < 1e-10

    return;

end


t = t/norm(t);


success = true;

end


%% =========================================================
% LOCAL FUNCTION 4
% QUATERNION -> ROTATION
% ==========================================================

function R = ...
    quatToRotationMatrix(q)


qx = q(1);
qy = q(2);
qz = q(3);
qw = q(4);


n = sqrt( ...
    qx^2 + ...
    qy^2 + ...
    qz^2 + ...
    qw^2);


if n < 1e-12

    R = eye(3);

    return;

end


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
% LOCAL FUNCTION 5
% ROTATION ERROR
% ==========================================================

function angleDeg = ...
    rotationDifferenceDegrees( ...
    Rest,Rgt)


Rest = squeeze(Rest);

Rgt = squeeze(Rgt);


if ndims(Rest)>2
    Rest = Rest(:,:,1);
end


if ndims(Rgt)>2
    Rgt = Rgt(:,:,1);
end


if ~isequal(size(Rest),[3 3]) || ...
        ~isequal(size(Rgt),[3 3])

    angleDeg = NaN;
    return;

end


if any(~isfinite(Rest(:))) || ...
        any(~isfinite(Rgt(:)))

    angleDeg = NaN;
    return;

end


Rerror = ...
    Rest*Rgt';


value = ...
    (trace(Rerror)-1)/2;


value = ...
    max(-1,min(1,value));


angleDeg = ...
    acosd(value);

end


%% =========================================================
% LOCAL FUNCTION 6
% TRANSLATION DIRECTION ERROR
% ==========================================================

function angleDeg = ...
    vectorAngleDegrees(a,b)


a = squeeze(a);
b = squeeze(b);


a = a(:);
b = b(:);


if numel(a)~=3 || ...
        numel(b)~=3

    angleDeg = NaN;
    return;

end


if any(~isfinite(a)) || ...
        any(~isfinite(b))

    angleDeg = NaN;
    return;

end


if norm(a)<1e-10 || ...
        norm(b)<1e-10

    angleDeg = NaN;
    return;

end


a = a/norm(a);
b = b/norm(b);


dotValue = ...
    dot(a,b);


dotValue = ...
    max(-1,min(1,dotValue));


angle1 = ...
    acosd(dotValue);


angle2 = ...
    180-angle1;


angleDeg = ...
    min(angle1,angle2);

end