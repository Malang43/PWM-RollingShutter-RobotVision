clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;

rng(1);

%% =========================================================
% EXPERIMENT 23
% Duty Cycle x PWM Phase Offset
%
% Dataset:
% TUM RGB-D fr1/xyz
%
% Feature method:
% SURF
%
% Fixed:
% PWM frequency = 100 Hz
% Exposure time = 2 ms
% Readout time = 20 ms
% Frame gap = 3
%
% Sweep:
% Duty cycle
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
% 3. LOAD GROUND TRUTH
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
% 5. FIXED PWM SETTINGS
% ==========================================================

pwmFreq = 100;

exposureTime = 0.002;      % 2 ms

modulationDepth = 0.90;

readoutTime = 0.020;       % 20 ms

numSamples = 100;


%% =========================================================
% 6. DUTY CYCLE AND PHASE SWEEP
% ==========================================================

dutyCyclesPercent = [10 25 50 75 90];

dutyCycles = dutyCyclesPercent/100;

phaseOffsets = [ ...
    0 ...
    0.125 ...
    0.25 ...
    0.50 ...
    0.875];

numDuty = length(dutyCycles);

numPhases = length(phaseOffsets);


%% =========================================================
% 7. STORAGE
%
% pair x duty x phase
% ==========================================================

cleanInliers = zeros(numPairs,1);

pwmInliers = ...
    zeros(numPairs,numDuty,numPhases);

retention = ...
    nan(numPairs,numDuty,numPhases);

poseSuccess = ...
    false(numPairs,numDuty,numPhases);

rotationError = ...
    nan(numPairs,numDuty,numPhases);

translationError = ...
    nan(numPairs,numDuty,numPhases);

rowGainStd = ...
    nan(numPairs,numDuty,numPhases);

meanGain = ...
    nan(numPairs,numDuty,numPhases);


%% =========================================================
% 8. MAIN LOOP
% ==========================================================

for k = 1:numPairs

    fprintf('\n========================================\n');
    fprintf('Pair %d/%d\n',k,numPairs);
    fprintf('========================================\n');

    idx1 = startIdx + k - 1;
    idx2 = idx1 + frameGap;


    %% Load images

    img1 = imread( ...
        fullfile(rgbFolder,files(idx1).name));

    img2 = imread( ...
        fullfile(rgbFolder,files(idx2).name));


    %% RGB timestamps

    rgbTime1 = ...
        str2double(erase(files(idx1).name,'.png'));

    rgbTime2 = ...
        str2double(erase(files(idx2).name,'.png'));


    %% Ground truth

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


    tgt = ...
        R1'*(t2World-t1World);


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
    % DUTY LOOP
    % ======================================================

    for d = 1:numDuty

        dutyCycle = dutyCycles(d);


        %% =================================================
        % PHASE LOOP
        % ==================================================

        for p = 1:numPhases

            phaseOffset = phaseOffsets(p);


            %% ---------------------------------------------
            % Simulate PWM
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
            % Row gain statistics
            % ----------------------------------------------

            rowGainStd(k,d,p) = ...
                (std(gain1)+std(gain2))/2;


            meanGain(k,d,p) = ...
                (mean(gain1)+mean(gain2))/2;


            %% ---------------------------------------------
            % Geometric inliers
            % ----------------------------------------------

            pwmInliers(k,d,p) = ...
                countSURFGeometricInliers( ...
                pwm1,pwm2);


            if cleanInliers(k) > 0

                retention(k,d,p) = ...
                    100 * ...
                    pwmInliers(k,d,p) ...
                    /cleanInliers(k);

            end


            %% ---------------------------------------------
            % Relative pose
            % ----------------------------------------------

            [success,Rest,test] = ...
                estimateSURFRelativeMotion( ...
                pwm1, ...
                pwm2, ...
                intrinsics);


            if success

                poseSuccess(k,d,p) = true;


                rotationError(k,d,p) = ...
                    rotationDifferenceDegrees( ...
                    Rest,Rgt);


                if ~any(isnan(tgt))

                    translationError(k,d,p) = ...
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
% Columns = duty cycle
% ==========================================================

meanRetention = ...
    nan(numPhases,numDuty);

failureRate = ...
    nan(numPhases,numDuty);

meanRotation = ...
    nan(numPhases,numDuty);

medianRotation = ...
    nan(numPhases,numDuty);

meanTranslation = ...
    nan(numPhases,numDuty);

medianTranslation = ...
    nan(numPhases,numDuty);

meanRowGainStd = ...
    nan(numPhases,numDuty);

meanIlluminationGain = ...
    nan(numPhases,numDuty);


for p = 1:numPhases

    for d = 1:numDuty


        meanRetention(p,d) = ...
            mean( ...
            retention(:,d,p), ...
            'omitnan');


        failureRate(p,d) = ...
            100 - ...
            100*sum( ...
            poseSuccess(:,d,p)) ...
            /numPairs;


        meanRotation(p,d) = ...
            mean( ...
            rotationError(:,d,p), ...
            'omitnan');


        medianRotation(p,d) = ...
            median( ...
            rotationError(:,d,p), ...
            'omitnan');


        meanTranslation(p,d) = ...
            mean( ...
            translationError(:,d,p), ...
            'omitnan');


        medianTranslation(p,d) = ...
            median( ...
            translationError(:,d,p), ...
            'omitnan');


        meanRowGainStd(p,d) = ...
            mean( ...
            rowGainStd(:,d,p), ...
            'omitnan');


        meanIlluminationGain(p,d) = ...
            mean( ...
            meanGain(:,d,p), ...
            'omitnan');

    end

end


%% =========================================================
% 10. PRINT RESULTS
% ==========================================================

fprintf('\n\n========================================\n');
fprintf('EXPERIMENT 23 FINAL RESULTS\n');
fprintf('========================================\n');


for d = 1:numDuty

    fprintf('\n========================================\n');

    fprintf( ...
        'DUTY CYCLE = %.0f%%\n', ...
        dutyCyclesPercent(d));

    fprintf('========================================\n');


    for p = 1:numPhases

        fprintf('\nPhase offset = %.3f cycles\n', ...
            phaseOffsets(p));


        fprintf( ...
            'Mean illumination gain = %.4f\n', ...
            meanIlluminationGain(p,d));


        fprintf( ...
            'Mean row-gain STD = %.4f\n', ...
            meanRowGainStd(p,d));


        fprintf( ...
            'SURF inlier retention = %.2f%%\n', ...
            meanRetention(p,d));


        fprintf( ...
            'SURF pose failure = %.2f%%\n', ...
            failureRate(p,d));


        fprintf( ...
            'Mean rotation error = %.3f deg\n', ...
            meanRotation(p,d));


        fprintf( ...
            'Median rotation error = %.3f deg\n', ...
            medianRotation(p,d));


        fprintf( ...
            'Mean translation error = %.3f deg\n', ...
            meanTranslation(p,d));


        fprintf( ...
            'Median translation error = %.3f deg\n', ...
            medianTranslation(p,d));

    end

end


%% =========================================================
% 11. SAVE RESULTS TABLE
% ==========================================================

totalConditions = ...
    numDuty*numPhases;


DutyCyclePercent = ...
    zeros(totalConditions,1);

PhaseOffset = ...
    zeros(totalConditions,1);

MeanIlluminationGain = ...
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


for d = 1:numDuty

    for p = 1:numPhases

        counter = counter+1;


        DutyCyclePercent(counter) = ...
            dutyCyclesPercent(d);


        PhaseOffset(counter) = ...
            phaseOffsets(p);


        MeanIlluminationGain(counter) = ...
            meanIlluminationGain(p,d);


        MeanRowGainStd(counter) = ...
            meanRowGainStd(p,d);


        MeanSURFInlierRetentionPercent(counter) = ...
            meanRetention(p,d);


        SURFPoseFailurePercent(counter) = ...
            failureRate(p,d);


        MeanRotationErrorDeg(counter) = ...
            meanRotation(p,d);


        MedianRotationErrorDeg(counter) = ...
            medianRotation(p,d);


        MeanTranslationErrorDeg(counter) = ...
            meanTranslation(p,d);


        MedianTranslationErrorDeg(counter) = ...
            medianTranslation(p,d);

    end

end


results = table( ...
    DutyCyclePercent, ...
    PhaseOffset, ...
    MeanIlluminationGain, ...
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
    repository_output(repoPaths,'parameter_sweeps/experiment23_duty_phase_results.csv'));


save( ...
    repository_output(repoPaths,'parameter_sweeps/experiment23_duty_phase_pairwise.mat'), ...
    'dutyCyclesPercent', ...
    'phaseOffsets', ...
    'retention', ...
    'poseSuccess', ...
    'rotationError', ...
    'translationError', ...
    'rowGainStd', ...
    'meanGain');


%% =========================================================
% 12. HEATMAP - INLIER RETENTION
% ==========================================================

figure;

imagesc( ...
    dutyCyclesPercent, ...
    phaseOffsets, ...
    meanRetention);

set(gca,'YDir','normal');

colorbar;

xlabel('PWM Duty Cycle (%)');

ylabel('Relative PWM Phase Offset (cycles)');

title('SURF Geometric-Inlier Retention (%)');

xticks(dutyCyclesPercent);

yticks(phaseOffsets);


for p = 1:numPhases

    for d = 1:numDuty

        text( ...
            dutyCyclesPercent(d), ...
            phaseOffsets(p), ...
            sprintf('%.1f', ...
            meanRetention(p,d)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end


%% =========================================================
% 13. HEATMAP - POSE FAILURE
% ==========================================================

figure;

imagesc( ...
    dutyCyclesPercent, ...
    phaseOffsets, ...
    failureRate);

set(gca,'YDir','normal');

colorbar;

xlabel('PWM Duty Cycle (%)');

ylabel('Relative PWM Phase Offset (cycles)');

title('SURF Pose Failure Rate (%)');

xticks(dutyCyclesPercent);

yticks(phaseOffsets);


for p = 1:numPhases

    for d = 1:numDuty

        text( ...
            dutyCyclesPercent(d), ...
            phaseOffsets(p), ...
            sprintf('%.0f', ...
            failureRate(p,d)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end

end


%% =========================================================
% 14. HEATMAP - ROW-GAIN VARIATION
% ==========================================================

figure;

imagesc( ...
    dutyCyclesPercent, ...
    phaseOffsets, ...
    meanRowGainStd);

set(gca,'YDir','normal');

colorbar;

xlabel('PWM Duty Cycle (%)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Row-Gain Standard Deviation');

xticks(dutyCyclesPercent);

yticks(phaseOffsets);


%% =========================================================
% 15. HEATMAP - MEAN ILLUMINATION
% ==========================================================

figure;

imagesc( ...
    dutyCyclesPercent, ...
    phaseOffsets, ...
    meanIlluminationGain);

set(gca,'YDir','normal');

colorbar;

xlabel('PWM Duty Cycle (%)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Illumination Gain');

xticks(dutyCyclesPercent);

yticks(phaseOffsets);


%% =========================================================
% 16. ROTATION ERROR HEATMAP
% ==========================================================

figure;

imagesc( ...
    dutyCyclesPercent, ...
    phaseOffsets, ...
    meanRotation);

set(gca,'YDir','normal');

colorbar;

xlabel('PWM Duty Cycle (%)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Rotation Error (degrees)');

xticks(dutyCyclesPercent);

yticks(phaseOffsets);


%% =========================================================
% 17. TRANSLATION ERROR HEATMAP
% ==========================================================

figure;

imagesc( ...
    dutyCyclesPercent, ...
    phaseOffsets, ...
    meanTranslation);

set(gca,'YDir','normal');

colorbar;

xlabel('PWM Duty Cycle (%)');

ylabel('Relative PWM Phase Offset (cycles)');

title('Mean Translation Direction Error (degrees)');

xticks(dutyCyclesPercent);

yticks(phaseOffsets);


%% =========================================================
% 18. FAILURE CURVES
% ==========================================================

figure;

for d = 1:numDuty

    plot( ...
        phaseOffsets, ...
        failureRate(:,d), ...
        '-o', ...
        'LineWidth',1.5);

    hold on;

end


xlabel('Relative PWM Phase Offset (cycles)');

ylabel('Pose Failure Rate (%)');

title('Phase Sensitivity at Different Duty Cycles');

legend( ...
    string(dutyCyclesPercent)+"%", ...
    'Location','best');

ylim([0 100]);

grid on;


%% =========================================================
% 19. RETENTION CURVES
% ==========================================================

figure;

for d = 1:numDuty

    plot( ...
        phaseOffsets, ...
        meanRetention(:,d), ...
        '-o', ...
        'LineWidth',1.5);

    hold on;

end


xlabel('Relative PWM Phase Offset (cycles)');

ylabel('Geometric-Inlier Retention (%)');

title('Feature Robustness at Different Duty Cycles');

legend( ...
    string(dutyCyclesPercent)+"%", ...
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


flicker1 = min(max(flicker1,0),1);

flicker2 = min(max(flicker2,0),1);

end


%% =========================================================
% LOCAL FUNCTION 2
% SURF GEOMETRIC INLIERS
% ==========================================================

function nInliers = ...
    countSURFGeometricInliers( ...
    img1,img2)


nInliers = 0;


gray1 = rgb2gray(im2uint8(img1));

gray2 = rgb2gray(im2uint8(img2));


points1 = detectSURFFeatures(gray1);

points2 = detectSURFFeatures(gray2);


if points1.Count < 8 || ...
        points2.Count < 8

    return;

end


[features1,valid1] = ...
    extractFeatures(gray1,points1);


[features2,valid2] = ...
    extractFeatures(gray2,points2);


pairs = ...
    matchFeatures( ...
    features1, ...
    features2, ...
    'Unique',true, ...
    'MaxRatio',0.7);


if size(pairs,1) < 8

    return;

end


matched1 = valid1(pairs(:,1));

matched2 = valid2(pairs(:,2));


try

    [~,mask] = ...
        estimateFundamentalMatrix( ...
        matched1.Location, ...
        matched2.Location, ...
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
% LOCAL FUNCTION 3
% SURF RELATIVE MOTION
% ==========================================================

function [success,R,t] = ...
    estimateSURFRelativeMotion( ...
    img1,img2,intrinsics)


success = false;

R = eye(3);

t = [NaN;NaN;NaN];


gray1 = rgb2gray(im2uint8(img1));

gray2 = rgb2gray(im2uint8(img2));


points1 = detectSURFFeatures(gray1);

points2 = detectSURFFeatures(gray2);


if points1.Count < 20 || ...
        points2.Count < 20

    return;

end


[features1,valid1] = ...
    extractFeatures(gray1,points1);


[features2,valid2] = ...
    extractFeatures(gray2,points2);


indexPairs = ...
    matchFeatures( ...
    features1, ...
    features2, ...
    'Unique',true, ...
    'MaxRatio',0.7);


if size(indexPairs,1) < 8

    return;

end


matched1 = valid1(indexPairs(:,1));

matched2 = valid2(indexPairs(:,2));


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


if ndims(orientation)>2

    orientation = orientation(:,:,1);

end


if ~isequal(size(orientation),[3 3])

    return;

end


R = orientation;


%% Translation

location = squeeze(location);


if numel(location)==3

    t = location(:);


elseif ismatrix(location) && ...
        size(location,2)==3

    t = location(1,:)';


elseif ismatrix(location) && ...
        size(location,1)==3

    t = location(:,1);


else

    return;

end


t = t(:);


if numel(t)~=3

    return;

end


if any(~isfinite(t))

    return;

end


if norm(t)<1e-10

    return;

end


t = t/norm(t);


success = true;

end


%% =========================================================
% LOCAL FUNCTION 4
% QUATERNION -> ROTATION
% ==========================================================

function R = quatToRotationMatrix(q)


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


Rerror = Rest*Rgt';


value = ...
    (trace(Rerror)-1)/2;


value = ...
    max(-1,min(1,value));


angleDeg = acosd(value);

end


%% =========================================================
% LOCAL FUNCTION 6
% TRANSLATION-DIRECTION ERROR
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


dotValue = dot(a,b);


dotValue = ...
    max(-1,min(1,dotValue));


angle1 = acosd(dotValue);


angle2 = 180-angle1;


angleDeg = min(angle1,angle2);

end