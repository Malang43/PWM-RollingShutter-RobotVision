clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');

close all;
rng(1);

%% =========================================================
% EXPERIMENT 18C
% CLEAN-BASELINE POSE SANITY CHECK
%
% Purpose:
% Check whether translation-direction error is already unstable
% on the original, unmodified TUM images before PWM is applied.
%
% Dataset:
% TUM RGB-D fr1/xyz
%
% Same image pairs as Experiment 18B:
% startIdx = 100
% numPairs = 50
% frameGap = 3
%% =========================================================

%% =========================================================
% 1. DATASET
%% =========================================================

datasetFolder = repoPaths.tumXYZ;
rgbFolder = fullfile(datasetFolder,'rgb');
gtFile = fullfile(datasetFolder,'groundtruth.txt');

files = dir(fullfile(rgbFolder,'*.png'));

% Sort images numerically by timestamp
rgbTimesAll = zeros(numel(files),1);

for i = 1:numel(files)
    rgbTimesAll(i) = ...
        str2double(erase(files(i).name,'.png'));
end

[~,order] = sort(rgbTimesAll);

files = files(order);
rgbTimesAll = rgbTimesAll(order);

fprintf('RGB images found: %d\n',numel(files));

%% =========================================================
% 2. OUTPUT FOLDER
%% =========================================================

outputFolder = repository_output(repoPaths,'legacy_statistics');

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% =========================================================
% 3. CAMERA INTRINSICS
%% =========================================================

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
% 4. LOAD TUM GROUND TRUTH
%% =========================================================

gtData = readmatrix( ...
    gtFile, ...
    'FileType','text', ...
    'CommentStyle','#');

gtData = ...
    gtData(~any(isnan(gtData),2),:);

gtTime = gtData(:,1);

fprintf( ...
    'Ground-truth poses loaded: %d\n', ...
    size(gtData,1));

%% =========================================================
% 5. FRAME SETTINGS
%% =========================================================

startIdx = 100;
numPairs = 50;
frameGap = 3;

if startIdx + numPairs - 1 + frameGap > numel(files)

    error( ...
        'Not enough RGB images for selected frame gap.');

end

%% =========================================================
% 6. STORAGE
%% =========================================================

PairIndex = (1:numPairs)';

Frame1Timestamp = ...
    nan(numPairs,1);

Frame2Timestamp = ...
    nan(numPairs,1);

GTAssocErrorFrame1_s = ...
    nan(numPairs,1);

GTAssocErrorFrame2_s = ...
    nan(numPairs,1);

GTTranslationMagnitude_m = ...
    nan(numPairs,1);

CleanMatches = ...
    zeros(numPairs,1);

CleanEssentialInliers = ...
    zeros(numPairs,1);

CleanPoseRecovered = ...
    false(numPairs,1);

CleanValidFraction = ...
    nan(numPairs,1);

CleanRotationErrorDeg = ...
    nan(numPairs,1);

CleanTranslationRawErrorDeg = ...
    nan(numPairs,1);

CleanTranslationSignInvariantErrorDeg = ...
    nan(numPairs,1);

%% =========================================================
% 7. MAIN LOOP
%% =========================================================

for k = 1:numPairs

    fprintf('\n============================\n');
    fprintf('Clean pair %d/%d\n',k,numPairs);
    fprintf('============================\n');

    idx1 = startIdx + k - 1;
    idx2 = idx1 + frameGap;

    %% -----------------------------------------------------
    % Load original CLEAN images
    %% -----------------------------------------------------

    img1 = imread( ...
        fullfile( ...
        rgbFolder, ...
        files(idx1).name));

    img2 = imread( ...
        fullfile( ...
        rgbFolder, ...
        files(idx2).name));

    %% -----------------------------------------------------
    % RGB timestamps
    %% -----------------------------------------------------

    rgbTime1 = rgbTimesAll(idx1);
    rgbTime2 = rgbTimesAll(idx2);

    Frame1Timestamp(k) = rgbTime1;
    Frame2Timestamp(k) = rgbTime2;

    %% -----------------------------------------------------
    % Associate RGB frames with nearest TUM GT
    %% -----------------------------------------------------

    [GTAssocErrorFrame1_s(k),gtIdx1] = ...
        min(abs(gtTime-rgbTime1));

    [GTAssocErrorFrame2_s(k),gtIdx2] = ...
        min(abs(gtTime-rgbTime2));

    %% -----------------------------------------------------
    % GT camera positions
    %% -----------------------------------------------------

    C1world = ...
        gtData(gtIdx1,2:4)';

    C2world = ...
        gtData(gtIdx2,2:4)';

    %% -----------------------------------------------------
    % GT orientations
    %
    % TUM quaternion:
    % qx qy qz qw
    %% -----------------------------------------------------

    q1 = ...
        gtData(gtIdx1,5:8);

    q2 = ...
        gtData(gtIdx2,5:8);

    R1cw = ...
        quatToRotationMatrix(q1);

    R2cw = ...
        quatToRotationMatrix(q2);

    %% -----------------------------------------------------
    % Relative GT rotation
    %% -----------------------------------------------------

    Rgt = ...
        R1cw' * R2cw;

    %% -----------------------------------------------------
    % Relative GT translation
    %
    % Camera-2 center expressed
    % in camera-1 coordinates
    %% -----------------------------------------------------

    tgtMetric = ...
        R1cw' * ...
        (C2world-C1world);

    GTTranslationMagnitude_m(k) = ...
        norm(tgtMetric);

    if GTTranslationMagnitude_m(k) > 1e-9

        tgt = ...
            tgtMetric / ...
            GTTranslationMagnitude_m(k);

    else

        tgt = ...
            [NaN;NaN;NaN];

    end

    %% -----------------------------------------------------
    % Estimate CLEAN relative pose
    %% -----------------------------------------------------

    [ ...
        success, ...
        Rest, ...
        test, ...
        validFraction, ...
        nMatches, ...
        nInliers] = ...
        estimateRelativeMotion( ...
        img1, ...
        img2, ...
        intrinsics);

    CleanMatches(k) = ...
        nMatches;

    CleanEssentialInliers(k) = ...
        nInliers;

    CleanValidFraction(k) = ...
        validFraction;

    %% -----------------------------------------------------
    % Pose errors
    %% -----------------------------------------------------

    if success

        CleanPoseRecovered(k) = true;

        CleanRotationErrorDeg(k) = ...
            rotationDifferenceDegrees( ...
            Rest, ...
            Rgt);

        if ~any(isnan(tgt))

            rawAngle = ...
                vectorAngleRawDegrees( ...
                test, ...
                tgt);

            CleanTranslationRawErrorDeg(k) = ...
                rawAngle;

            CleanTranslationSignInvariantErrorDeg(k) = ...
                min( ...
                rawAngle, ...
                180-rawAngle);

        end

    end

end

%% =========================================================
% 8. SUMMARY
%% =========================================================

poseRecoveryRate = ...
    100 * ...
    sum(CleanPoseRecovered) / ...
    numPairs;

poseFailureRate = ...
    100 - ...
    poseRecoveryRate;

fprintf('\n\n========================================\n');
fprintf('CLEAN BASELINE SUMMARY\n');
fprintf('========================================\n');

fprintf( ...
    'Clean pose recovery = %.1f%%\n', ...
    poseRecoveryRate);

fprintf( ...
    'Clean pose failure = %.1f%%\n', ...
    poseFailureRate);

fprintf( ...
    'Mean GT translation = %.4f m\n', ...
    mean( ...
    GTTranslationMagnitude_m, ...
    'omitnan'));

fprintf( ...
    'Median GT translation = %.4f m\n', ...
    median( ...
    GTTranslationMagnitude_m, ...
    'omitnan'));

fprintf( ...
    'Minimum GT translation = %.4f m\n', ...
    min( ...
    GTTranslationMagnitude_m));

fprintf( ...
    'Maximum GT translation = %.4f m\n', ...
    max( ...
    GTTranslationMagnitude_m));

fprintf('\n--- Rotation error ---\n');

fprintf( ...
    'Mean = %.3f deg\n', ...
    mean( ...
    CleanRotationErrorDeg, ...
    'omitnan'));

fprintf( ...
    'Median = %.3f deg\n', ...
    median( ...
    CleanRotationErrorDeg, ...
    'omitnan'));

fprintf('\n--- RAW translation-direction error ---\n');

fprintf( ...
    'Mean = %.3f deg\n', ...
    mean( ...
    CleanTranslationRawErrorDeg, ...
    'omitnan'));

fprintf( ...
    'Median = %.3f deg\n', ...
    median( ...
    CleanTranslationRawErrorDeg, ...
    'omitnan'));

fprintf('\n--- Sign-invariant translation error ---\n');

fprintf( ...
    'Mean = %.3f deg\n', ...
    mean( ...
    CleanTranslationSignInvariantErrorDeg, ...
    'omitnan'));

fprintf( ...
    'Median = %.3f deg\n', ...
    median( ...
    CleanTranslationSignInvariantErrorDeg, ...
    'omitnan'));

fprintf('\n--- GT association ---\n');

fprintf( ...
    'Maximum RGB->GT association error = %.6f s\n', ...
    max([ ...
    GTAssocErrorFrame1_s; ...
    GTAssocErrorFrame2_s]));

%% =========================================================
% 9. BASELINE-SENSITIVITY CORRELATIONS
%% =========================================================

validRaw = ...
    isfinite( ...
    GTTranslationMagnitude_m) & ...
    isfinite( ...
    CleanTranslationRawErrorDeg);

if sum(validRaw) >= 3

    Rraw = corrcoef( ...
        GTTranslationMagnitude_m(validRaw), ...
        CleanTranslationRawErrorDeg(validRaw));

    fprintf( ...
        '\nCorrelation: GT baseline vs RAW translation error = %.3f\n', ...
        Rraw(1,2));

end

validSign = ...
    isfinite( ...
    GTTranslationMagnitude_m) & ...
    isfinite( ...
    CleanTranslationSignInvariantErrorDeg);

if sum(validSign) >= 3

    Rsign = corrcoef( ...
        GTTranslationMagnitude_m(validSign), ...
        CleanTranslationSignInvariantErrorDeg(validSign));

    fprintf( ...
        'Correlation: GT baseline vs sign-invariant translation error = %.3f\n', ...
        Rsign(1,2));

end

validRot = ...
    isfinite( ...
    GTTranslationMagnitude_m) & ...
    isfinite( ...
    CleanRotationErrorDeg);

if sum(validRot) >= 3

    Rrot = corrcoef( ...
        GTTranslationMagnitude_m(validRot), ...
        CleanRotationErrorDeg(validRot));

    fprintf( ...
        'Correlation: GT baseline vs rotation error = %.3f\n', ...
        Rrot(1,2));

end

%% =========================================================
% 10. SAVE CSV
%% =========================================================

results = table( ...
    PairIndex, ...
    Frame1Timestamp, ...
    Frame2Timestamp, ...
    GTAssocErrorFrame1_s, ...
    GTAssocErrorFrame2_s, ...
    GTTranslationMagnitude_m, ...
    CleanMatches, ...
    CleanEssentialInliers, ...
    CleanPoseRecovered, ...
    CleanValidFraction, ...
    CleanRotationErrorDeg, ...
    CleanTranslationRawErrorDeg, ...
    CleanTranslationSignInvariantErrorDeg);

disp(results);

writetable( ...
    results, ...
    fullfile( ...
    outputFolder, ...
    'experiment18C_clean_baseline_results.csv'));

%% =========================================================
% 11. SAVE MAT FILE
%% =========================================================

save( ...
    fullfile( ...
    outputFolder, ...
    'experiment18C_clean_baseline_data.mat'), ...
    'results', ...
    'GTTranslationMagnitude_m', ...
    'CleanPoseRecovered', ...
    'CleanRotationErrorDeg', ...
    'CleanTranslationRawErrorDeg', ...
    'CleanTranslationSignInvariantErrorDeg');

%% =========================================================
% 12. DIAGNOSTIC PLOT 1
%
% GT translation magnitude
% vs raw translation-direction error
%% =========================================================

figure;

scatter( ...
    GTTranslationMagnitude_m, ...
    CleanTranslationRawErrorDeg, ...
    45, ...
    'filled');

xlabel( ...
    'Ground-Truth Translation Magnitude (m)');

ylabel( ...
    'Clean Raw Translation-Direction Error (deg)');

title( ...
    'Clean Translation Error vs Ground-Truth Baseline');

grid on;

%% =========================================================
% 13. DIAGNOSTIC PLOT 2
%
% GT translation magnitude
% vs rotation error
%% =========================================================

figure;

scatter( ...
    GTTranslationMagnitude_m, ...
    CleanRotationErrorDeg, ...
    45, ...
    'filled');

xlabel( ...
    'Ground-Truth Translation Magnitude (m)');

ylabel( ...
    'Clean Rotation Error (deg)');

title( ...
    'Clean Rotation Error vs Ground-Truth Baseline');

grid on;

%% =========================================================
% 14. OPTIONAL PAIR INDEX PLOT
%
% Useful for finding problematic pairs
%% =========================================================

figure;

plot( ...
    PairIndex, ...
    CleanTranslationRawErrorDeg, ...
    '-o', ...
    'LineWidth',1.2);

xlabel('Pair Index');

ylabel( ...
    'Clean Raw Translation-Direction Error (deg)');

title( ...
    'Clean Translation-Direction Error Across Image Pairs');

grid on;

fprintf('\nResults saved to:\n');
fprintf('%s\n',outputFolder);

%% =========================================================
% LOCAL FUNCTION 1
% RELATIVE CAMERA MOTION
%% =========================================================

function [ ...
    success, ...
    R, ...
    t, ...
    validFraction, ...
    nMatches, ...
    nInliers] = ...
    estimateRelativeMotion( ...
    img1, ...
    img2, ...
    intrinsics)

success = false;

R = eye(3);

t = ...
    [NaN;NaN;NaN];

validFraction = NaN;

nMatches = 0;

nInliers = 0;

%% ---------------------------------------------------------
% Convert images
%% ---------------------------------------------------------

gray1 = ...
    rgb2gray( ...
    im2uint8(img1));

gray2 = ...
    rgb2gray( ...
    im2uint8(img2));

%% ---------------------------------------------------------
% SURF detection
%% ---------------------------------------------------------

points1 = ...
    detectSURFFeatures(gray1);

points2 = ...
    detectSURFFeatures(gray2);

if points1.Count < 20 || ...
        points2.Count < 20

    return;

end

%% ---------------------------------------------------------
% Descriptor extraction
%% ---------------------------------------------------------

[features1,valid1] = ...
    extractFeatures( ...
    gray1, ...
    points1);

[features2,valid2] = ...
    extractFeatures( ...
    gray2, ...
    points2);

%% ---------------------------------------------------------
% Matching
%% ---------------------------------------------------------

indexPairs = ...
    matchFeatures( ...
    features1, ...
    features2, ...
    'Unique',true, ...
    'MaxRatio',0.7);

nMatches = ...
    size(indexPairs,1);

if nMatches < 8

    return;

end

matched1 = ...
    valid1( ...
    indexPairs(:,1));

matched2 = ...
    valid2( ...
    indexPairs(:,2));

%% ---------------------------------------------------------
% Essential matrix
%% ---------------------------------------------------------

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

nInliers = ...
    sum(inlierMask);

matched1 = ...
    matched1(inlierMask);

matched2 = ...
    matched2(inlierMask);

if matched1.Count < 8

    return;

end

%% ---------------------------------------------------------
% Relative camera pose
%% ---------------------------------------------------------

try

    [ ...
        orientation, ...
        location, ...
        validFraction] = ...
        relativeCameraPose( ...
        E, ...
        intrinsics, ...
        matched1.Location, ...
        matched2.Location);

catch

    validFraction = NaN;

    return;

end

if isempty(validFraction) || ...
        ~isfinite(validFraction)

    validFraction = NaN;

    return;

end

%% ---------------------------------------------------------
% Keep SAME success criterion
% as Experiment 18B
%% ---------------------------------------------------------

if validFraction < 0.5

    return;

end

%% ---------------------------------------------------------
% Orientation shape safety
%% ---------------------------------------------------------

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

%% ---------------------------------------------------------
% Translation shape safety
%% ---------------------------------------------------------

location = ...
    squeeze(location);

if numel(location) == 3

    t = ...
        location(:);

elseif ismatrix(location) && ...
        size(location,2) == 3

    t = ...
        location(1,:)';

elseif ismatrix(location) && ...
        size(location,1) == 3

    t = ...
        location(:,1);

else

    return;

end

t = t(:);

if numel(t) ~= 3 || ...
        any(~isfinite(t)) || ...
        norm(t) < 1e-10

    return;

end

t = ...
    t/norm(t);

success = true;

end

%% =========================================================
% LOCAL FUNCTION 2
% TUM QUATERNION -> ROTATION MATRIX
%
% q = [qx qy qz qw]
%% =========================================================

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

R = [ ...

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
% LOCAL FUNCTION 3
% ROTATION ERROR
%% =========================================================

function angleDeg = ...
    rotationDifferenceDegrees( ...
    Rest, ...
    Rgt)

Rest = squeeze(Rest);
Rgt = squeeze(Rgt);

if ndims(Rest) > 2

    Rest = ...
        Rest(:,:,1);

end

if ndims(Rgt) > 2

    Rgt = ...
        Rgt(:,:,1);

end

if ~isequal( ...
        size(Rest), ...
        [3 3]) || ...
        ~isequal( ...
        size(Rgt), ...
        [3 3])

    angleDeg = NaN;

    return;

end

if any(~isfinite(Rest(:))) || ...
        any(~isfinite(Rgt(:)))

    angleDeg = NaN;

    return;

end

Rerror = ...
    Rest * Rgt';

value = ...
    (trace(Rerror)-1)/2;

value = ...
    max( ...
    -1, ...
    min(1,value));

angleDeg = ...
    acosd(value);

end

%% =========================================================
% LOCAL FUNCTION 4
% RAW TRANSLATION-DIRECTION ERROR
%
% 0 deg = same direction
% 180 deg = opposite direction
%% =========================================================

function angleDeg = ...
    vectorAngleRawDegrees( ...
    a, ...
    b)

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

a = ...
    a/norm(a);

b = ...
    b/norm(b);

dotValue = ...
    dot(a,b);

dotValue = ...
    max( ...
    -1, ...
    min(1,dotValue));

angleDeg = ...
    acosd(dotValue);

end