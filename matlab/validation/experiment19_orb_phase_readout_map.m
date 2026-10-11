clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;

rng(1);

%% =========================================================
% EXPERIMENT 19
% ORB validation of PWM Phase x Readout-Time interaction map
%
% Dataset:
% TUM RGB-D fr1/xyz
%
% Same simulation as Experiment 18
% Only feature pipeline changes from SURF -> ORB
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

fprintf('Ground-truth poses loaded: %d\n',size(gtData,1));


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
% 5. FIXED PWM SETTINGS
% ==========================================================

pwmFreq = 100;

exposureTime = 0.001;

dutyCycle = 0.25;

modulationDepth = 0.90;

numSamples = 100;


%% =========================================================
% 6. PHASE AND READOUT SWEEP
% ==========================================================

phaseOffsets = [ ...
    0 ...
    0.125 ...
    0.25 ...
    0.50 ...
    0.875];

readoutTimesMs = [5 10 15 20 25 30];

readoutTimes = readoutTimesMs/1000;

numPhases = length(phaseOffsets);

numReadouts = length(readoutTimes);


%% =========================================================
% 7. STORAGE
% ==========================================================

cleanInliers = zeros(numPairs,1);

pwmInliers = ...
    zeros(numPairs,numPhases,numReadouts);

retention = ...
    nan(numPairs,numPhases,numReadouts);

poseSuccess = ...
    false(numPairs,numPhases,numReadouts);

rotationError = ...
    nan(numPairs,numPhases,numReadouts);

translationError = ...
    nan(numPairs,numPhases,numReadouts);

rowGainStd = ...
    nan(numPairs,numPhases,numReadouts);


%% =========================================================
% 8. MAIN LOOP
% ==========================================================

for k = 1:numPairs

    fprintf('\n========================================\n');
    fprintf('Pair %d/%d\n',k,numPairs);
    fprintf('========================================\n');

    idx1 = startIdx + k - 1;
    idx2 = idx1 + frameGap;


    %% -----------------------------------------------------
    % Load images
    % ------------------------------------------------------

    img1 = imread( ...
        fullfile(rgbFolder,files(idx1).name));

    img2 = imread( ...
        fullfile(rgbFolder,files(idx2).name));


    %% -----------------------------------------------------
    % RGB timestamps
    % ------------------------------------------------------

    rgbTime1 = ...
        str2double(erase(files(idx1).name,'.png'));

    rgbTime2 = ...
        str2double(erase(files(idx2).name,'.png'));


    %% -----------------------------------------------------
    % Ground truth
    % ------------------------------------------------------

    [~,gtIdx1] = ...
        min(abs(gtTime-rgbTime1));

    [~,gtIdx2] = ...
        min(abs(gtTime-rgbTime2));


    t1World = gtData(gtIdx1,2:4)';
    t2World = gtData(gtIdx2,2:4)';


    q1 = gtData(gtIdx1,5:8);
    q2 = gtData(gtIdx2,5:8);


    R1 = quatToRotationMatrix(q1);
    R2 = quatToRotationMatrix(q2);


    Rgt = R1' * R2;


    tgt = R1' * ...
        (t2World-t1World);


    if norm(tgt) > 1e-9

        tgt = tgt/norm(tgt);

    else

        tgt = [NaN;NaN;NaN];

    end


    %% =====================================================
    % CLEAN ORB BASELINE
    % ======================================================

    cleanInliers(k) = ...
        countORBGeometricInliers( ...
        img1,img2);


    %% =====================================================
    % PHASE LOOP
    % ======================================================

    for p = 1:numPhases

        phaseOffset = phaseOffsets(p);


        %% =================================================
        % READOUT LOOP
        % ==================================================

        for r = 1:numReadouts

            readoutTime = ...
                readoutTimes(r);


            %% ---------------------------------------------
            % PWM simulation
            % ----------------------------------------------

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


            %% ---------------------------------------------
            % Row-gain variability
            % ----------------------------------------------

            rowGainStd(k,p,r) = ...
                (std(gain1)+std(gain2))/2;


            %% ---------------------------------------------
            % ORB geometric inliers
            % ----------------------------------------------

            pwmInliers(k,p,r) = ...
                countORBGeometricInliers( ...
                pwm1,pwm2);


            if cleanInliers(k) > 0

                retention(k,p,r) = ...
                    100 * ...
                    pwmInliers(k,p,r) ...
                    /cleanInliers(k);

            end


            %% ---------------------------------------------
            % ORB-based relative pose
            % ----------------------------------------------

            [success,Rest,test] = ...
                estimateORBRelativeMotion( ...
                pwm1, ...
                pwm2, ...
                intrinsics);


            if success

                poseSuccess(k,p,r) = true;


                rotationError(k,p,r) = ...
                    rotationDifferenceDegrees( ...
                    Rest,Rgt);


                if ~any(isnan(tgt))

                    translationError(k,p,r) = ...
                        vectorAngleDegrees( ...
                        test,tgt);

                end

            end

        end

    end

end


%% =========================================================
% 9. SUMMARY
% ==========================================================

meanRetention = ...
    nan(numPhases,numReadouts);

failureRate = ...
    nan(numPhases,numReadouts);

meanRotation = ...
    nan(numPhases,numReadouts);

medianRotation = ...
    nan(numPhases,numReadouts);

meanTranslation = ...
    nan(numPhases,numReadouts);

medianTranslation = ...
    nan(numPhases,numReadouts);

meanRowGainStd = ...
    nan(numPhases,numReadouts);


for p = 1:numPhases

    for r = 1:numReadouts


        meanRetention(p,r) = ...
            mean( ...
            retention(:,p,r), ...
            'omitnan');


        failureRate(p,r) = ...
            100 - ...
            100*sum( ...
            poseSuccess(:,p,r)) ...
            /numPairs;


        meanRotation(p,r) = ...
            mean( ...
            rotationError(:,p,r), ...
            'omitnan');


        medianRotation(p,r) = ...
            median( ...
            rotationError(:,p,r), ...
            'omitnan');


        meanTranslation(p,r) = ...
            mean( ...
            translationError(:,p,r), ...
            'omitnan');


        medianTranslation(p,r) = ...
            median( ...
            translationError(:,p,r), ...
            'omitnan');


        meanRowGainStd(p,r) = ...
            mean( ...
            rowGainStd(:,p,r), ...
            'omitnan');

    end

end


%% =========================================================
% 10. PRINT RESULTS
% ==========================================================

fprintf('\n\n========================================\n');
fprintf('EXPERIMENT 19 FINAL RESULTS - ORB\n');
fprintf('========================================\n');


for p = 1:numPhases

    fprintf('\n========================================\n');

    fprintf( ...
        'PHASE OFFSET = %.3f cycles\n', ...
        phaseOffsets(p));

    fprintf('========================================\n');


    for r = 1:numReadouts

        fprintf('\nReadout time = %d ms\n', ...
            readoutTimesMs(r));


        fprintf( ...
            'Mean row-gain STD = %.4f\n', ...
            meanRowGainStd(p,r));


        fprintf( ...
            'ORB inlier retention = %.2f%%\n', ...
            meanRetention(p,r));


        fprintf( ...
            'ORB pose failure = %.2f%%\n', ...
            failureRate(p,r));


        fprintf( ...
            'Mean rotation error = %.3f deg\n', ...
            meanRotation(p,r));


        fprintf( ...
            'Median rotation error = %.3f deg\n', ...
            medianRotation(p,r));


        fprintf( ...
            'Mean translation error = %.3f deg\n', ...
            meanTranslation(p,r));


        fprintf( ...
            'Median translation error = %.3f deg\n', ...
            medianTranslation(p,r));

    end

end


%% =========================================================
% 11. SAVE RESULTS TABLE
% ==========================================================

totalConditions = ...
    numPhases*numReadouts;


PhaseOffset = ...
    zeros(totalConditions,1);

ReadoutTimeMs = ...
    zeros(totalConditions,1);

MeanRowGainStd = ...
    zeros(totalConditions,1);

MeanORBInlierRetentionPercent = ...
    zeros(totalConditions,1);

ORBPoseFailurePercent = ...
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


for p = 1:numPhases

    for r = 1:numReadouts

        counter = counter+1;


        PhaseOffset(counter) = ...
            phaseOffsets(p);


        ReadoutTimeMs(counter) = ...
            readoutTimesMs(r);


        MeanRowGainStd(counter) = ...
            meanRowGainStd(p,r);


        MeanORBInlierRetentionPercent(counter) = ...
            meanRetention(p,r);


        ORBPoseFailurePercent(counter) = ...
            failureRate(p,r);


        MeanRotationErrorDeg(counter) = ...
            meanRotation(p,r);


        MedianRotationErrorDeg(counter) = ...
            medianRotation(p,r);


        MeanTranslationErrorDeg(counter) = ...
            meanTranslation(p,r);


        MedianTranslationErrorDeg(counter) = ...
            medianTranslation(p,r);

    end

end


results = table( ...
    PhaseOffset, ...
    ReadoutTimeMs, ...
    MeanRowGainStd, ...
    MeanORBInlierRetentionPercent, ...
    ORBPoseFailurePercent, ...
    MeanRotationErrorDeg, ...
    MedianRotationErrorDeg, ...
    MeanTranslationErrorDeg, ...
    MedianTranslationErrorDeg);


disp(results);


writetable( ...
    results, ...
    repository_output(repoPaths,'orb_validation/experiment19_orb_phase_readout_results.csv'));


save( ...
    repository_output(repoPaths,'orb_validation/experiment19_orb_pairwise_data.mat'), ...
    'phaseOffsets', ...
    'readoutTimesMs', ...
    'retention', ...
    'poseSuccess', ...
    'rotationError', ...
    'translationError', ...
    'rowGainStd');


%% =========================================================
% 12. HEATMAP - ORB INLIER RETENTION
% ==========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    meanRetention);

set(gca,'YDir','normal');

colorbar;

xlabel('Rolling-Shutter Readout Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('ORB Geometric-Inlier Retention (%)');

xticks(readoutTimesMs);

yticks(phaseOffsets);


for p = 1:numPhases

    for r = 1:numReadouts

        text( ...
            readoutTimesMs(r), ...
            phaseOffsets(p), ...
            sprintf('%.1f', ...
            meanRetention(p,r)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end


%% =========================================================
% 13. HEATMAP - ORB POSE FAILURE
% ==========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    failureRate);

set(gca,'YDir','normal');

colorbar;

xlabel('Rolling-Shutter Readout Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('ORB Pose Failure Rate (%)');

xticks(readoutTimesMs);

yticks(phaseOffsets);


for p = 1:numPhases

    for r = 1:numReadouts

        text( ...
            readoutTimesMs(r), ...
            phaseOffsets(p), ...
            sprintf('%.0f', ...
            failureRate(p,r)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end


%% =========================================================
% 14. HEATMAP - ROTATION ERROR
% ==========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    meanRotation);

set(gca,'YDir','normal');

colorbar;

xlabel('Rolling-Shutter Readout Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('ORB Mean Rotation Error (degrees)');

xticks(readoutTimesMs);

yticks(phaseOffsets);


%% =========================================================
% 15. HEATMAP - TRANSLATION ERROR
% ==========================================================

figure;

imagesc( ...
    readoutTimesMs, ...
    phaseOffsets, ...
    meanTranslation);

set(gca,'YDir','normal');

colorbar;

xlabel('Rolling-Shutter Readout Time (ms)');

ylabel('Relative PWM Phase Offset (cycles)');

title('ORB Mean Translation Direction Error (degrees)');

xticks(readoutTimesMs);

yticks(phaseOffsets);


%% =========================================================
% 16. FAILURE CURVES
% ==========================================================

figure;

for r = 1:numReadouts

    plot( ...
        phaseOffsets, ...
        failureRate(:,r), ...
        '-o', ...
        'LineWidth',1.5);

    hold on;

end


xlabel('Relative PWM Phase Offset (cycles)');

ylabel('ORB Pose Failure Rate (%)');

title('ORB Phase Sensitivity at Different Readout Times');

legend( ...
    string(readoutTimesMs)+" ms", ...
    'Location','best');

ylim([0 100]);

grid on;


%% =========================================================
% 17. RETENTION CURVES
% ==========================================================

figure;

for r = 1:numReadouts

    plot( ...
        phaseOffsets, ...
        meanRetention(:,r), ...
        '-o', ...
        'LineWidth',1.5);

    hold on;

end


xlabel('Relative PWM Phase Offset (cycles)');

ylabel('ORB Geometric-Inlier Retention (%)');

title('ORB Feature Robustness at Different Readout Times');

legend( ...
    string(readoutTimesMs)+" ms", ...
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

rowTime = readoutTime/h;


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


    led1 = phase1 < dutyCycle;


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


    led2 = phase2 < dutyCycle;


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


flicker1 = min(max(flicker1,0),1);

flicker2 = min(max(flicker2,0),1);

end


%% =========================================================
% LOCAL FUNCTION 2
% ORB GEOMETRIC INLIERS
% ==========================================================

function nInliers = ...
    countORBGeometricInliers( ...
    img1,img2)


nInliers = 0;


gray1 = ...
    rgb2gray(im2uint8(img1));

gray2 = ...
    rgb2gray(im2uint8(img2));


%% ORB detection

points1 = ...
    detectORBFeatures(gray1);

points2 = ...
    detectORBFeatures(gray2);


if points1.Count < 8 || ...
        points2.Count < 8

    return;

end


%% ORB descriptors

[features1,valid1] = ...
    extractFeatures( ...
    gray1, ...
    points1, ...
    'Method','ORB');


[features2,valid2] = ...
    extractFeatures( ...
    gray2, ...
    points2, ...
    'Method','ORB');


%% ORB matching

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


%% Fundamental matrix

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
% ORB RELATIVE MOTION
% ==========================================================

function [success,R,t] = ...
    estimateORBRelativeMotion( ...
    img1,img2,intrinsics)


success = false;

R = eye(3);

t = [NaN;NaN;NaN];


gray1 = ...
    rgb2gray(im2uint8(img1));

gray2 = ...
    rgb2gray(im2uint8(img2));


%% ORB detection

points1 = ...
    detectORBFeatures(gray1);

points2 = ...
    detectORBFeatures(gray2);


if points1.Count < 20 || ...
        points2.Count < 20

    return;

end


%% ORB descriptors

[features1,valid1] = ...
    extractFeatures( ...
    gray1, ...
    points1, ...
    'Method','ORB');


[features2,valid2] = ...
    extractFeatures( ...
    gray2, ...
    points2, ...
    'Method','ORB');


%% Match ORB descriptors

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


%% Essential matrix

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


matched1 = ...
    matched1(inlierMask);


matched2 = ...
    matched2(inlierMask);


if matched1.Count < 8

    return;

end


%% Relative pose

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


%% Orientation shape correction

orientation = ...
    squeeze(orientation);


if ndims(orientation) > 2

    orientation = ...
        orientation(:,:,1);

end


if ~isequal( ...
        size(orientation), ...
        [3 3])

    return;

end


R = orientation;


%% Translation shape correction

location = ...
    squeeze(location);


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
% QUATERNION -> ROTATION MATRIX
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


if numel(a) ~= 3 || ...
        numel(b) ~= 3

    angleDeg = NaN;
    return;

end


if any(~isfinite(a)) || ...
        any(~isfinite(b))

    angleDeg = NaN;
    return;

end


if norm(a) < 1e-10 || ...
        norm(b) < 1e-10

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