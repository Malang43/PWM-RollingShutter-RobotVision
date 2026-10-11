clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');


%% ============================================================
% FINAL FULL INPUT-EQUIVALENCE VERIFICATION
%
% 50 image pairs
% x 30 phase-readout conditions
% = 1500 pair-condition evaluations
%
% Two frames per evaluation:
% = 3000 perturbed RGB image instances
%
% MATLAB row gains and Python row gains have already been
% independently generated and verified.
%
% This script compares:
% 1. MATLAB row-gain values
% 2. Python row-gain values
% 3. MATLAB rounding
% 4. Python np.rint tie-to-even rounding
%
% Dataset:
% TUM fr1/xyz
%
% START_INDEX = 100
% GAP = 3
% N_PAIRS = 50
%% ============================================================

rootDir = repository_output(repoPaths,'verification');

rgbDir = ...
    fullfile(repoPaths.tumXYZ,'rgb');

matlabGainFile = ...
    repository_input(repoPaths,'verification/rowgain_matlab.csv');

pythonGainFile = ...
    repository_input(repoPaths,'verification/rowgain_python.csv');

%% ============================================================
% SETTINGS
%% ============================================================

START_INDEX = 100;
GAP = 3;
N_PAIRS = 50;

%% ============================================================
% IMAGE FILES
%% ============================================================

files = dir(fullfile(rgbDir,'*.png'));

[~,idx] = sort({files.name});
files = files(idx);

fprintf('\n============================================\n');
fprintf('FULL 1500-EVALUATION INPUT EQUIVALENCE CHECK\n');
fprintf('============================================\n\n');

fprintf('RGB images found: %d\n',numel(files));
fprintf('Start index: %d\n',START_INDEX);
fprintf('Gap: %d\n',GAP);
fprintf('Pairs: %d\n\n',N_PAIRS);

assert( ...
    START_INDEX + N_PAIRS - 1 + GAP <= numel(files), ...
    'Not enough RGB images for requested pair construction.');

%% ============================================================
% LOAD ROW-GAIN TABLES
%% ============================================================

A = readtable(matlabGainFile);
B = readtable(pythonGainFile);

assert(height(A) == height(B), ...
    'MATLAB/Python row-gain CSV sizes differ.');

%% Handle row variable naming difference

if ismember('RowIndex',A.Properties.VariableNames)
    matlabRow = A.RowIndex;
else
    matlabRow = A.Row;
end

if ismember('RowIndex',B.Properties.VariableNames)
    pythonRow = B.RowIndex;
else
    pythonRow = str2double(string(B.Row));
end

assert(all(matlabRow == pythonRow), ...
    'MATLAB/Python row ordering differs.');

%% ============================================================
% CONDITIONS
%% ============================================================

phases = unique(A.Phase);
readouts = unique(A.ReadoutMs);

phases = sort(phases);
readouts = sort(readouts);

N_CONDITIONS = ...
    numel(phases) * numel(readouts);

assert(N_CONDITIONS == 30, ...
    'Expected 30 phase-readout conditions.');

fprintf('Conditions: %d\n',N_CONDITIONS);
fprintf('Expected pair-condition evaluations: %d\n', ...
    N_PAIRS*N_CONDITIONS);

fprintf('Expected perturbed image instances: %d\n\n', ...
    N_PAIRS*N_CONDITIONS*2);

%% ============================================================
% OUTPUT STORAGE
%% ============================================================

totalEvaluations = ...
    N_PAIRS * N_CONDITIONS;

PairID = zeros(totalEvaluations,1);
ConditionID = zeros(totalEvaluations,1);

ImageIndex1 = zeros(totalEvaluations,1);
ImageIndex2 = zeros(totalEvaluations,1);

ReadoutMs = zeros(totalEvaluations,1);
Phase = zeros(totalEvaluations,1);

Frame1_MAE = zeros(totalEvaluations,1);
Frame1_MaxDiff = zeros(totalEvaluations,1);
Frame1_DifferentPixels = zeros(totalEvaluations,1);
Frame1_DifferentPercent = zeros(totalEvaluations,1);
Frame1_DiffGT1 = zeros(totalEvaluations,1);

Frame2_MAE = zeros(totalEvaluations,1);
Frame2_MaxDiff = zeros(totalEvaluations,1);
Frame2_DifferentPixels = zeros(totalEvaluations,1);
Frame2_DifferentPercent = zeros(totalEvaluations,1);
Frame2_DiffGT1 = zeros(totalEvaluations,1);

RowGain1_MaxDiff = zeros(totalEvaluations,1);
RowGain2_MaxDiff = zeros(totalEvaluations,1);

%% ============================================================
% MAIN LOOP
%% ============================================================

evaluationCounter = 0;
conditionCounter = 0;

for ir = 1:numel(readouts)

    for ip = 1:numel(phases)

        conditionCounter = conditionCounter + 1;

        rMs = readouts(ir);
        ph = phases(ip);

        %% ----------------------------------------------------
        % GET ROW GAINS FOR THIS CONDITION
        %% ----------------------------------------------------

        idxA = ...
            abs(A.ReadoutMs-rMs) < 1e-12 & ...
            abs(A.Phase-ph) < 1e-12;

        idxB = ...
            abs(B.ReadoutMs-rMs) < 1e-12 & ...
            abs(B.Phase-ph) < 1e-12;

        gainA1 = A.GainFrame1(idxA);
        gainA2 = A.GainFrame2(idxA);

        gainB1 = B.GainFrame1(idxB);
        gainB2 = B.GainFrame2(idxB);

        assert(numel(gainA1) == 480, ...
            'Unexpected MATLAB row-gain length.');

        assert(numel(gainB1) == 480, ...
            'Unexpected Python row-gain length.');

        rgDiff1 = max(abs(gainA1-gainB1));
        rgDiff2 = max(abs(gainA2-gainB2));

        %% ----------------------------------------------------
        % LOOP 50 IMAGE PAIRS
        %% ----------------------------------------------------

        for pairID = 1:N_PAIRS

            evaluationCounter = evaluationCounter + 1;

            idx1 = ...
                START_INDEX + pairID - 1;

            idx2 = ...
                idx1 + GAP;

            img1Path = ...
                fullfile(rgbDir,files(idx1).name);

            img2Path = ...
                fullfile(rgbDir,files(idx2).name);

            img1 = imread(img1Path);
            img2 = imread(img2Path);

            H1 = size(img1,1);
            H2 = size(img2,1);

            assert(H1 == numel(gainA1), ...
                'Frame 1 height mismatch.');

            assert(H2 == numel(gainA2), ...
                'Frame 2 height mismatch.');

            %% =================================================
            % FRAME 1
            %% =================================================

            rawA1 = ...
                double(img1) .* ...
                reshape(gainA1,[H1 1 1]);

            % MATLAB round()
            outA1 = round(rawA1);
            outA1 = min(max(outA1,0),255);
            outA1 = uint8(outA1);

            rawB1 = ...
                double(img1) .* ...
                reshape(gainB1,[H1 1 1]);

            % Python np.rint() equivalent
            outB1 = pythonRintUint8(rawB1);

            D1 = ...
                abs(double(outA1)-double(outB1));

            %% =================================================
            % FRAME 2
            %% =================================================

            rawA2 = ...
                double(img2) .* ...
                reshape(gainA2,[H2 1 1]);

            outA2 = round(rawA2);
            outA2 = min(max(outA2,0),255);
            outA2 = uint8(outA2);

            rawB2 = ...
                double(img2) .* ...
                reshape(gainB2,[H2 1 1]);

            outB2 = pythonRintUint8(rawB2);

            D2 = ...
                abs(double(outA2)-double(outB2));

            %% =================================================
            % STORE RESULTS
            %% =================================================

            PairID(evaluationCounter) = pairID;
            ConditionID(evaluationCounter) = conditionCounter;

            ImageIndex1(evaluationCounter) = idx1;
            ImageIndex2(evaluationCounter) = idx2;

            ReadoutMs(evaluationCounter) = rMs;
            Phase(evaluationCounter) = ph;

            RowGain1_MaxDiff(evaluationCounter) = rgDiff1;
            RowGain2_MaxDiff(evaluationCounter) = rgDiff2;

            Frame1_MAE(evaluationCounter) = ...
                mean(D1(:));

            Frame1_MaxDiff(evaluationCounter) = ...
                max(D1(:));

            Frame1_DifferentPixels(evaluationCounter) = ...
                sum(D1(:)>0);

            Frame1_DifferentPercent(evaluationCounter) = ...
                100*sum(D1(:)>0)/numel(D1);

            Frame1_DiffGT1(evaluationCounter) = ...
                sum(D1(:)>1);

            Frame2_MAE(evaluationCounter) = ...
                mean(D2(:));

            Frame2_MaxDiff(evaluationCounter) = ...
                max(D2(:));

            Frame2_DifferentPixels(evaluationCounter) = ...
                sum(D2(:)>0);

            Frame2_DifferentPercent(evaluationCounter) = ...
                100*sum(D2(:)>0)/numel(D2);

            Frame2_DiffGT1(evaluationCounter) = ...
                sum(D2(:)>1);

        end

        fprintf( ...
            'Completed condition %02d / %02d: readout=%d ms, phase=%.3f\n', ...
            conditionCounter, ...
            N_CONDITIONS, ...
            rMs, ...
            ph);

    end
end

%% ============================================================
% CREATE TABLE
%% ============================================================

T = table( ...
    PairID, ...
    ConditionID, ...
    ImageIndex1, ...
    ImageIndex2, ...
    ReadoutMs, ...
    Phase, ...
    RowGain1_MaxDiff, ...
    RowGain2_MaxDiff, ...
    Frame1_MAE, ...
    Frame1_MaxDiff, ...
    Frame1_DifferentPixels, ...
    Frame1_DifferentPercent, ...
    Frame1_DiffGT1, ...
    Frame2_MAE, ...
    Frame2_MaxDiff, ...
    Frame2_DifferentPixels, ...
    Frame2_DifferentPercent, ...
    Frame2_DiffGT1);

%% ============================================================
% SAVE
%% ============================================================

outFile = fullfile( ...
    rootDir, ...
    'final_1500_input_equivalence.csv');

writetable(T,outFile);

%% ============================================================
% GLOBAL STATISTICS
%% ============================================================

allMAE = [ ...
    T.Frame1_MAE; ...
    T.Frame2_MAE];

allMaxDiff = [ ...
    T.Frame1_MaxDiff; ...
    T.Frame2_MaxDiff];

allDiffPercent = [ ...
    T.Frame1_DifferentPercent; ...
    T.Frame2_DifferentPercent];

allDiffGT1 = [ ...
    T.Frame1_DiffGT1; ...
    T.Frame2_DiffGT1];

allRowGainMax = [ ...
    T.RowGain1_MaxDiff; ...
    T.RowGain2_MaxDiff];

%% ============================================================
% FINAL SUMMARY
%% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('FINAL 1500-EVALUATION EQUIVALENCE SUMMARY\n');
fprintf('============================================\n\n');

fprintf('Pair-condition evaluations = %d\n', ...
    height(T));

fprintf('Perturbed RGB image instances = %d\n', ...
    2*height(T));

fprintf('Unique image pairs = %d\n', ...
    numel(unique(T.PairID)));

fprintf('Conditions per pair = %d\n\n', ...
    N_CONDITIONS);

fprintf('Maximum row-gain abs difference = %.15g\n', ...
    max(allRowGainMax));

fprintf('Mean pixel MAE across all image instances = %.12g\n', ...
    mean(allMAE));

fprintf('Median pixel MAE across all image instances = %.12g\n', ...
    median(allMAE));

fprintf('Worst image-level pixel MAE = %.12g\n', ...
    max(allMAE));

fprintf('Maximum individual pixel difference = %.0f\n', ...
    max(allMaxDiff));

fprintf('Mean differing-pixel percentage = %.6f%%\n', ...
    mean(allDiffPercent));

fprintf('Median differing-pixel percentage = %.6f%%\n', ...
    median(allDiffPercent));

fprintf('Worst differing-pixel percentage = %.6f%%\n', ...
    max(allDiffPercent));

fprintf('Image instances with any pixel difference > 1 = %d / %d\n', ...
    sum(allDiffGT1 > 0), ...
    numel(allDiffGT1));

fprintf('Pair-condition evaluations with any difference > 1 = %d / %d\n', ...
    sum( ...
        T.Frame1_DiffGT1 > 0 | ...
        T.Frame2_DiffGT1 > 0), ...
    height(T));

fprintf('\nSaved:\n%s\n',outFile);

%% ============================================================
% FINAL VERDICT
%% ============================================================

if height(T) == 1500 && ...
        max(allRowGainMax) < 1e-12 && ...
        max(allMaxDiff) <= 1 && ...
        sum(allDiffGT1 > 0) == 0

    fprintf('\n');
    fprintf('RESULT: FULL 1500-EVALUATION INPUT CHECK PASSED.\n');
    fprintf('MATLAB AND PYTHON ROW-GAIN PROFILES ARE NUMERICALLY EQUIVALENT,\n');
    fprintf('AND ALL 3000 PERTURBED RGB IMAGE INSTANCES DIFFER BY AT MOST\n');
    fprintf('ONE 8-BIT INTENSITY LEVEL PER PIXEL.\n');

else

    fprintf('\n');
    fprintf('RESULT: INPUT-EQUIVALENCE CHECK REQUIRES REVIEW.\n');

end

%% ============================================================
% LOCAL FUNCTION:
% Emulate NumPy np.rint() + clip + uint8
%% ============================================================

function out = pythonRintUint8(x)

    lower = floor(x);
    frac = x - lower;

    rounded = zeros(size(x));

    lowerMask = frac < 0.5;
    upperMask = frac > 0.5;

    tieMask = ...
        ~(lowerMask | upperMask);

    rounded(lowerMask) = ...
        lower(lowerMask);

    rounded(upperMask) = ...
        lower(upperMask) + 1;

    tieFloor = ...
        lower(tieMask);

    tieRounded = ...
        tieFloor;

    oddMask = ...
        mod(tieFloor,2) == 1;

    tieRounded(oddMask) = ...
        tieFloor(oddMask) + 1;

    rounded(tieMask) = ...
        tieRounded;

    rounded = ...
        min(max(rounded,0),255);

    out = uint8(rounded);

end