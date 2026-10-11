clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');


%% ============================================================
% FULL 30-CONDITION MATLAB-vs-PYTHON IMAGE EQUIVALENCE CHECK
%
% Uses one representative TUM image and all:
% 5 phases x 6 readout times = 30 conditions
%
% The purpose is to quantify the effect of the tiny row-gain
% differences and MATLAB/Python rounding on final uint8 images.
%% ============================================================

rootDir = repository_output(repoPaths,'verification');

rgbDir = fullfile(repoPaths.tumXYZ,'rgb');

%% ------------------------------------------------------------
% LOAD IMAGE 100
%% ------------------------------------------------------------

files = dir(fullfile(rgbDir,'*.png'));

[~,idx] = sort({files.name});
files = files(idx);

imgPath = fullfile(rgbDir,files(100).name);

fprintf('Using image:\n%s\n\n',imgPath);

img = imread(imgPath);

H = size(img,1);

%% ------------------------------------------------------------
% LOAD ROW-GAIN TABLES
%% ------------------------------------------------------------

A = readtable(repository_input(repoPaths,'verification/rowgain_matlab.csv'));
B = readtable(repository_input(repoPaths,'verification/rowgain_python.csv'));

assert(height(A) == height(B), ...
    'Row-gain table sizes differ.');

%% ------------------------------------------------------------
% CONDITION LIST
%% ------------------------------------------------------------

phases = unique(A.Phase);
readouts = unique(A.ReadoutMs);

nConditions = numel(phases) * numel(readouts);

fprintf('Conditions = %d\n\n',nConditions);

%% ------------------------------------------------------------
% OUTPUT ARRAYS
%% ------------------------------------------------------------

ConditionID = zeros(nConditions,1);
ReadoutMs = zeros(nConditions,1);
Phase = zeros(nConditions,1);

MeanAbsPixelDifference = zeros(nConditions,1);
MaxPixelDifference = zeros(nConditions,1);

DifferentPixels = zeros(nConditions,1);
DifferentPixelsPercent = zeros(nConditions,1);

PixelsDiffGT1 = zeros(nConditions,1);

RowGainMeanAbsDifference = zeros(nConditions,1);
RowGainMaxAbsDifference = zeros(nConditions,1);

%% ------------------------------------------------------------
% LOOP CONDITIONS
%% ------------------------------------------------------------

c = 0;

for ir = 1:numel(readouts)

    for ip = 1:numel(phases)

        c = c + 1;

        rMs = readouts(ir);
        ph = phases(ip);

        idxA = ...
            abs(A.ReadoutMs-rMs) < 1e-12 & ...
            abs(A.Phase-ph) < 1e-12;

        idxB = ...
            abs(B.ReadoutMs-rMs) < 1e-12 & ...
            abs(B.Phase-ph) < 1e-12;

        gainA = A.GainFrame2(idxA);
        gainB = B.GainFrame2(idxB);

        assert(numel(gainA) == H, ...
            'MATLAB gain length mismatch.');

        assert(numel(gainB) == H, ...
            'Python gain length mismatch.');

        %% ----------------------------------------------------
        % ROW-GAIN DIFFERENCE
        %% ----------------------------------------------------

        dg = abs(gainA-gainB);

        RowGainMeanAbsDifference(c) = mean(dg);
        RowGainMaxAbsDifference(c) = max(dg);

        %% ----------------------------------------------------
        % MATLAB-STYLE IMAGE
        %% ----------------------------------------------------

        imgA = ...
            double(img) .* reshape(gainA,[H 1 1]);

        imgA = round(imgA);
        imgA = min(max(imgA,0),255);
        imgA = uint8(imgA);

        %% ----------------------------------------------------
        % PYTHON np.rint EMULATION
        %
        % Python np.rint uses bankers rounding:
        % ties go to the nearest even integer.
        %% ----------------------------------------------------

        x = ...
            double(img) .* reshape(gainB,[H 1 1]);

        floorX = floor(x);
        fracX = x-floorX;

        imgBdouble = zeros(size(x));

        lowerMask = fracX < 0.5;
        upperMask = fracX > 0.5;
        tieMask = abs(fracX-0.5) < 1e-12;

        imgBdouble(lowerMask) = ...
            floorX(lowerMask);

        imgBdouble(upperMask) = ...
            floorX(upperMask)+1;

        % ties -> even
        tieFloor = floorX(tieMask);

        tieRounded = tieFloor;

        oddMask = mod(tieFloor,2) == 1;

        tieRounded(oddMask) = ...
            tieFloor(oddMask)+1;

        imgBdouble(tieMask) = ...
            tieRounded;

        imgBdouble = ...
            min(max(imgBdouble,0),255);

        imgB = uint8(imgBdouble);

        %% ----------------------------------------------------
        % PIXEL DIFFERENCE
        %% ----------------------------------------------------

        D = abs(double(imgA)-double(imgB));

        MeanAbsPixelDifference(c) = mean(D(:));
        MaxPixelDifference(c) = max(D(:));

        DifferentPixels(c) = sum(D(:)>0);

        DifferentPixelsPercent(c) = ...
            100*DifferentPixels(c)/numel(D);

        PixelsDiffGT1(c) = sum(D(:)>1);

        %% ----------------------------------------------------
        % STORE CONDITION
        %% ----------------------------------------------------

        ConditionID(c) = c;
        ReadoutMs(c) = rMs;
        Phase(c) = ph;

        fprintf( ...
            ['Condition %02d | readout=%2d ms | phase=%.3f | ', ...
             'meanPix=%.6f | maxPix=%.0f | diffPix=%.3f%%\n'], ...
            c, ...
            rMs, ...
            ph, ...
            MeanAbsPixelDifference(c), ...
            MaxPixelDifference(c), ...
            DifferentPixelsPercent(c));

    end
end

%% ============================================================
% TABLE
%% ============================================================

T = table( ...
    ConditionID, ...
    ReadoutMs, ...
    Phase, ...
    RowGainMeanAbsDifference, ...
    RowGainMaxAbsDifference, ...
    MeanAbsPixelDifference, ...
    MaxPixelDifference, ...
    DifferentPixels, ...
    DifferentPixelsPercent, ...
    PixelsDiffGT1);

outFile = fullfile( ...
    rootDir, ...
    'fullgrid_matlab_python_image_equivalence.csv');

writetable(T,outFile);

%% ============================================================
% GLOBAL SUMMARY
%% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('FULL-GRID IMAGE EQUIVALENCE SUMMARY\n');
fprintf('============================================\n\n');

fprintf( ...
    'Conditions tested = %d\n', ...
    height(T));

fprintf( ...
    'Max row-gain abs difference = %.15g\n', ...
    max(T.RowGainMaxAbsDifference));

fprintf( ...
    'Mean of condition pixel-MAE = %.12g\n', ...
    mean(T.MeanAbsPixelDifference));

fprintf( ...
    'Worst condition pixel-MAE = %.12g\n', ...
    max(T.MeanAbsPixelDifference));

fprintf( ...
    'Maximum pixel difference over all conditions = %.0f\n', ...
    max(T.MaxPixelDifference));

fprintf( ...
    'Mean differing-pixel percentage = %.6f%%\n', ...
    mean(T.DifferentPixelsPercent));

fprintf( ...
    'Worst differing-pixel percentage = %.6f%%\n', ...
    max(T.DifferentPixelsPercent));

fprintf( ...
    'Total conditions with any pixel difference > 1 = %d / %d\n', ...
    sum(T.PixelsDiffGT1 > 0), ...
    height(T));

fprintf('\nSaved:\n%s\n',outFile);

if max(T.MaxPixelDifference) <= 1 && ...
        max(T.RowGainMaxAbsDifference) < 1e-12

    fprintf('\nRESULT: FULL GRID IS NUMERICALLY EQUIVALENT AT THE ROW-GAIN LEVEL\n');
    fprintf('AND DIFFERS BY AT MOST ONE 8-BIT INTENSITY LEVEL PER PIXEL.\n');

else

    fprintf('\nRESULT: LARGER IMPLEMENTATION DIFFERENCES EXIST.\n');

end