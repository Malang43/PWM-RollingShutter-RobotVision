clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');

close all;

%% ============================================================
% FINAL JOURNAL FIGURE REGENERATION SCRIPT
% Regenerates polished Figures 2--8 for the manuscript.
%
% SAVE THIS FILE AS:
%   <original-source path: see MANIFEST.md>
%
% RUN IT FROM MATLAB.
% Because absolute paths are used, the Current Folder can be anywhere.
%
% OUTPUT:
%   <original-source path: see MANIFEST.md>
%
% Figure 1 is NOT regenerated here because the conceptual mechanism
% figure has already been finalized separately.
%% ============================================================

%% ----------------------- USER PATHS --------------------------
rootFinal = repoPaths.resultsRoot;
xyzRoot = repoPaths.resultsRoot;

surfStatsFile = repository_input(repoPaths,'legacy_statistics/experiment18E_final_statistics.csv');

comparisonFile = repository_input(repoPaths,'legacy_statistics/experiment18H_SURF_vs_LightGlue_comparison.csv');

mechanismFolder = fullfile(repoPaths.resultsRoot,'mechanism_analysis');

oldFigureFolder = fullfile(repoPaths.figuresRoot,'main');

outputFolder = repository_output(repoPaths,'journal_figures');

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

fprintf('\nFINAL JOURNAL FIGURE REGENERATION\n');
fprintf('Output folder:\n%s\n\n',outputFolder);

%% ---------------------- GLOBAL STYLE -------------------------
fontName = 'Arial';
fontSize = 11;
axisLineWidth = 1.0;
lineWidth = 2.0;
markerSize = 7;

% Consistent method colors
surfColor = [0.00 0.35 0.70];
lgColor   = [0.85 0.33 0.10];

% Heatmap colormap
heatMap = parula(256);

% Figure canvas
figPos4 = [100 100 1180 760];
figPos2 = [100 100 1120 460];

%% ============================================================
% FIGURE 2
% SURF phase-readout statistics
%% ============================================================

if ~isfile(surfStatsFile)
    error('Cannot find SURF statistics file:\n%s',surfStatsFile);
end

T = readtable(surfStatsFile);

phaseVals = unique(T.PhaseOffset,'stable');
readoutVals = unique(T.ReadoutTimeMs,'stable');

nP = numel(phaseVals);
nR = numel(readoutVals);

failure = nan(nP,nR);
retention = nan(nP,nR);
dRot = nan(nP,nR);
dTrans = nan(nP,nR);
nRecovered = nan(nP,nR);

for p = 1:nP
    for r = 1:nR
        idx = T.PhaseOffset == phaseVals(p) & ...
              T.ReadoutTimeMs == readoutVals(r);

        failure(p,r) = T.PoseFailurePercent(idx);
        retention(p,r) = T.MedianInlierRetentionPercent(idx);
        dRot(p,r) = T.MedianDeltaRotationErrorDeg(idx);
        dTrans(p,r) = T.MedianDeltaTranslationErrorDeg(idx);
        nRecovered(p,r) = T.NposeRecovered(idx);
    end
end

fig = figure('Color','w','Position',figPos4);
tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax = nexttile;
imagesc(readoutVals,phaseVals,failure);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,...
    'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb = colorbar; cb.Label.String = 'Failure rate (%)';
xlabel('Readout time (ms)');
ylabel('Relative PWM phase (cycles)');
title('(a) Pose-recovery failure','FontWeight','bold');
xticks(readoutVals); yticks(phaseVals);
addHeatmapLabels(ax,readoutVals,phaseVals,failure,'%.0f',fontName,10);

ax = nexttile;
imagesc(readoutVals,phaseVals,retention);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,...
    'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb = colorbar; cb.Label.String = 'Retention (%)';
xlabel('Readout time (ms)');
ylabel('Relative PWM phase (cycles)');
title('(b) Median inlier retention','FontWeight','bold');
xticks(readoutVals); yticks(phaseVals);
addHeatmapLabels(ax,readoutVals,phaseVals,retention,'%.1f',fontName,9);

ax = nexttile;
imagesc(readoutVals,phaseVals,dRot);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,...
    'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb = colorbar; cb.Label.String = '\Delta rotation error (deg)';
xlabel('Readout time (ms)');
ylabel('Relative PWM phase (cycles)');
title('(c) Rotation degradation','FontWeight','bold');
xticks(readoutVals); yticks(phaseVals);
addHeatmapLabelsWithN(ax,readoutVals,phaseVals,dRot,nRecovered,'%.1f',fontName,8);

ax = nexttile;
imagesc(readoutVals,phaseVals,dTrans);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,...
    'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb = colorbar; cb.Label.String = '\Delta translation error (deg)';
xlabel('Readout time (ms)');
ylabel('Relative PWM phase (cycles)');
title('(d) Translation-direction degradation','FontWeight','bold');
xticks(readoutVals); yticks(phaseVals);
addHeatmapLabelsWithN(ax,readoutVals,phaseVals,dTrans,nRecovered,'%.0f',fontName,8);

exportBoth(fig,outputFolder,'Figure02_phase_readout_statistics');
close(fig);

%% ============================================================
% FIGURE 3
% Cross-sequence validation: fr1/xyz vs fr1/desk
% Updated XYZ values from final Experiment 18B/18E run.
%% ============================================================

readouts = [5 10 15 20 25 30];
phases = [0 0.125 0.25 0.5 0.875];

xyzFail = [ ...
     0  24   4  16   6  22;
    64  98  68  78  56  48;
   100 100 100 100  96  90;
   100 100 100 100 100  98;
     6  62  66  86  64  56];

deskFail = [ ...
     0  26   4  24  24  28;
    70 100  84  92  78  58;
   100 100 100 100  98  88;
   100 100 100 100 100 100;
     8  78  64  86  56  48];

fig = figure('Color','w','Position',figPos2);
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

ax = nexttile;
imagesc(readouts,phases,xyzFail);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,...
    'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb=colorbar; cb.Label.String='Failure rate (%)';
xlabel('Readout time (ms)');
ylabel('Relative PWM phase (cycles)');
title('(a) TUM fr1/xyz','FontWeight','bold');
xticks(readouts); yticks(phases);
addHeatmapLabels(ax,readouts,phases,xyzFail,'%.0f',fontName,10);

ax = nexttile;
imagesc(readouts,phases,deskFail);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,...
    'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb=colorbar; cb.Label.String='Failure rate (%)';
xlabel('Readout time (ms)');
ylabel('Relative PWM phase (cycles)');
title('(b) TUM fr1/desk','FontWeight','bold');
xticks(readouts); yticks(phases);
addHeatmapLabels(ax,readouts,phases,deskFail,'%.0f',fontName,10);

exportBoth(fig,outputFolder,'Figure03_cross_sequence_validation');
close(fig);

%% ============================================================
% FIGURE 4
% Frequency and exposure
%% ============================================================

freqVals = [100 200 300 500 1000];
expVals  = [1 2 5 8 10];
phase5 = [0 0.125 0.25 0.5 0.875];

freqRet = [ ...
     8.75  8.16  9.28 13.11 15.68;
     1.78  7.34  8.34 11.92 15.73;
     0.05  3.68  7.05 10.72 15.50;
     0.00  1.44  3.28  8.30 15.38;
     0.72  7.47  9.90 13.72 15.38];

freqFail = [ ...
    18 24 12 14 0;
    78 44 22 10 0;
   100 72 54 28 0;
   100 100 82 30 0;
    86 48 22 16 0];

expRet = [ ...
     8.81  9.85 14.97 13.91 15.44;
     1.78  1.82  9.33 11.41 15.52;
     0.05  0.00  1.76  8.15 15.32;
     0.00  0.00  0.00  4.50 15.56;
     0.74  0.81  6.44 10.01 15.62];

expFail = [ ...
    16 12   2  0 0;
    80 76   0  0 0;
   100 100 64  0 0;
   100 100 100 20 0;
    86 80  12  0 0];

fig = figure('Color','w','Position',figPos4);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax=nexttile;
imagesc(freqVals,phase5,freqRet);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb=colorbar; cb.Label.String='Retention (%)';
xlabel('PWM frequency (Hz)'); ylabel('Relative PWM phase (cycles)');
title('(a) Frequency: inlier retention','FontWeight','bold');
xticks(freqVals); yticks(phase5);
addHeatmapLabels(ax,freqVals,phase5,freqRet,'%.1f',fontName,9);

ax=nexttile;
imagesc(freqVals,phase5,freqFail);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb=colorbar; cb.Label.String='Failure rate (%)';
xlabel('PWM frequency (Hz)'); ylabel('Relative PWM phase (cycles)');
title('(b) Frequency: pose failure','FontWeight','bold');
xticks(freqVals); yticks(phase5);
addHeatmapLabels(ax,freqVals,phase5,freqFail,'%.0f',fontName,9);

ax=nexttile;
imagesc(expVals,phase5,expRet);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb=colorbar; cb.Label.String='Retention (%)';
xlabel('Exposure time (ms)'); ylabel('Relative PWM phase (cycles)');
title('(c) Exposure: inlier retention','FontWeight','bold');
xticks(expVals); yticks(phase5);
addHeatmapLabels(ax,expVals,phase5,expRet,'%.1f',fontName,9);

ax=nexttile;
imagesc(expVals,phase5,expFail);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb=colorbar; cb.Label.String='Failure rate (%)';
xlabel('Exposure time (ms)'); ylabel('Relative PWM phase (cycles)');
title('(d) Exposure: pose failure','FontWeight','bold');
xticks(expVals); yticks(phase5);
addHeatmapLabels(ax,expVals,phase5,expFail,'%.0f',fontName,9);

exportBoth(fig,outputFolder,'Figure04_frequency_exposure');
close(fig);

%% ============================================================
% FIGURE 5
% Duty cycle and modulation depth
%% ============================================================

dutyVals = [10 25 50 75 90];
modVals  = [10 30 50 70 90];

dutyRet = [ ...
     1.75  9.87 32.03 58.50 76.35;
     0.20  1.87 15.41 40.08 58.85;
     0.00  0.00  4.25 24.59 45.66;
     0.00  0.00  0.00  9.53 39.61;
     0.00  0.81 16.25 42.25 61.47];

dutyFail = [ ...
    64 12  0 0 0;
    96 76  0 0 0;
   100 100 32 0 0;
   100 100 100 0 0;
   100 82  0 0 0];

modRet = [ ...
    90.01 69.61 45.68 21.59  9.82;
    88.13 60.68 31.92  9.92  1.82;
    85.75 50.00 20.79  3.46  0.00;
    86.04 47.75 17.76  1.62  0.00;
    88.47 60.16 30.66  7.86  0.81];

modFail = [ ...
     0 0  2  0 12;
     0 0  0  2 76;
     0 2  0 32 100;
     0 0  0 58 100;
     0 0  0 14 82];

fig = figure('Color','w','Position',figPos4);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax=nexttile;
imagesc(dutyVals,phase5,dutyRet);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb=colorbar; cb.Label.String='Retention (%)';
xlabel('PWM duty cycle (%)'); ylabel('Relative PWM phase (cycles)');
title('(a) Duty cycle: inlier retention','FontWeight','bold');
xticks(dutyVals); yticks(phase5);
addHeatmapLabels(ax,dutyVals,phase5,dutyRet,'%.1f',fontName,9);

ax=nexttile;
imagesc(dutyVals,phase5,dutyFail);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb=colorbar; cb.Label.String='Failure rate (%)';
xlabel('PWM duty cycle (%)'); ylabel('Relative PWM phase (cycles)');
title('(b) Duty cycle: pose failure','FontWeight','bold');
xticks(dutyVals); yticks(phase5);
addHeatmapLabels(ax,dutyVals,phase5,dutyFail,'%.0f',fontName,9);

ax=nexttile;
imagesc(modVals,phase5,modRet);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap);
cb=colorbar; cb.Label.String='Retention (%)';
xlabel('PWM modulation depth (%)'); ylabel('Relative PWM phase (cycles)');
title('(c) Modulation depth: inlier retention','FontWeight','bold');
xticks(modVals); yticks(phase5);
addHeatmapLabels(ax,modVals,phase5,modRet,'%.1f',fontName,9);

ax=nexttile;
imagesc(modVals,phase5,modFail);
set(ax,'YDir','normal','FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
colormap(ax,heatMap); caxis(ax,[0 100]);
cb=colorbar; cb.Label.String='Failure rate (%)';
xlabel('PWM modulation depth (%)'); ylabel('Relative PWM phase (cycles)');
title('(d) Modulation depth: pose failure','FontWeight','bold');
xticks(modVals); yticks(phase5);
addHeatmapLabels(ax,modVals,phase5,modFail,'%.0f',fontName,9);

exportBoth(fig,outputFolder,'Figure05_duty_modulation');
close(fig);

%% ============================================================
% FIGURE 6
% Inter-frame row-gain mismatch mechanism
%
% This searches the Exp25 folder for a CSV containing:
%   mismatch/RMS + retention + failure columns.
% If none is found, the previous Figure 6 is copied as a fallback.
%% ============================================================

[mechanismTable, mechanismSource] = findMechanismTable(mechanismFolder);

if ~isempty(mechanismTable)

    names = mechanismTable.Properties.VariableNames;
    mismatchName = findVar(names,{'GainMismatchRMS','MismatchRMS','RMSMismatch','gain_mismatch'});
    retentionName = findVar(names,{'Retention','InlierRetention','retention'});
    failureName = findVar(names,{'PoseFailure','FailureRate','failure'});

    x = mechanismTable.(mismatchName);
    y1 = mechanismTable.(retentionName);
    y2 = mechanismTable.(failureName);

    valid1 = isfinite(x) & isfinite(y1);
    valid2 = isfinite(x) & isfinite(y2);

    r1 = corr(x(valid1),y1(valid1),'Rows','complete');
    r2 = corr(x(valid2),y2(valid2),'Rows','complete');

    fig = figure('Color','w','Position',figPos2);
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    ax=nexttile;
    scatter(x(valid1),y1(valid1),32,'filled','MarkerFaceAlpha',0.75);
    hold on;
    if sum(valid1) >= 2
        pp = polyfit(x(valid1),y1(valid1),1);
        xx = linspace(min(x(valid1)),max(x(valid1)),100);
        plot(xx,polyval(pp,xx),'LineWidth',lineWidth,'Color',[0.85 0.33 0.10]);
    end
    hold off;
    set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
    grid off;
    xlabel('Inter-frame row-gain mismatch RMS');
    ylabel('Geometric-inlier retention (%)');
    title('(a) Feature retention','FontWeight','bold');
    text(0.05,0.92,sprintf('r = %.3f',r1),'Units','normalized',...
        'FontName',fontName,'FontSize',fontSize,'FontWeight','bold');

    ax=nexttile;
    scatter(x(valid2),y2(valid2),32,'filled','MarkerFaceAlpha',0.75);
    hold on;
    if sum(valid2) >= 2
        pp = polyfit(x(valid2),y2(valid2),1);
        xx = linspace(min(x(valid2)),max(x(valid2)),100);
        plot(xx,polyval(pp,xx),'LineWidth',lineWidth,'Color',[0.85 0.33 0.10]);
    end
    hold off;
    set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
    grid off;
    xlabel('Inter-frame row-gain mismatch RMS');
    ylabel('Pose-failure rate (%)');
    title('(b) Pose failure','FontWeight','bold');
    text(0.05,0.92,sprintf('r = %.3f',r2),'Units','normalized',...
        'FontName',fontName,'FontSize',fontSize,'FontWeight','bold');

    exportBoth(fig,outputFolder,'Figure06_gain_mismatch_mechanism');
    close(fig);

    fprintf('Figure 6 source: %s\n',mechanismSource);

else
    oldPng = fullfile(oldFigureFolder,'Figure06_gain_mismatch_mechanism.png');
    oldPdf = fullfile(oldFigureFolder,'Figure06_gain_mismatch_mechanism.pdf');

    warning(['Could not automatically locate the Exp25 mechanism CSV. ' ...
        'Copying the previous Figure 6 as fallback.']);

    if isfile(oldPng)
        copyfile(oldPng,fullfile(outputFolder,'Figure06_gain_mismatch_mechanism.png'));
    end
    if isfile(oldPdf)
        copyfile(oldPdf,fullfile(outputFolder,'Figure06_gain_mismatch_mechanism.pdf'));
    end
end

%% ============================================================
% FIGURE 7
% Overall parameter trends
%% ============================================================

freqMeanFail = mean(freqFail,1,'omitnan');
expMeanFail  = mean(expFail,1,'omitnan');
dutyMeanFail = mean(dutyFail,1,'omitnan');
modMeanFail  = mean(modFail,1,'omitnan');

fig = figure('Color','w','Position',figPos4);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax=nexttile;
plot(freqVals,freqMeanFail,'-o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off; ylim([0 100]);
xlabel('PWM frequency (Hz)'); ylabel('Mean pose failure (%)');
title('(a) PWM frequency','FontWeight','bold');

ax=nexttile;
plot(expVals,expMeanFail,'-o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off; ylim([0 100]);
xlabel('Exposure time (ms)'); ylabel('Mean pose failure (%)');
title('(b) Exposure time','FontWeight','bold');

ax=nexttile;
plot(dutyVals,dutyMeanFail,'-o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off; ylim([0 100]);
xlabel('PWM duty cycle (%)'); ylabel('Mean pose failure (%)');
title('(c) Duty cycle','FontWeight','bold');

ax=nexttile;
plot(modVals,modMeanFail,'-o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off; ylim([0 100]);
xlabel('PWM modulation depth (%)'); ylabel('Mean pose failure (%)');
title('(d) Modulation depth','FontWeight','bold');

exportBoth(fig,outputFolder,'Figure07_parameter_summary');
close(fig);

%% ============================================================
% FIGURE 8
% Clean SURF vs SuperPoint+LightGlue comparison
% Aggregated across the six readout settings at each phase.
%% ============================================================

if ~isfile(comparisonFile)
    error('Cannot find comparison file:\n%s',comparisonFile);
end

C = readtable(comparisonFile);

phaseComp = unique(C.PhaseOffset,'stable');

surfFailAgg = nan(size(phaseComp));
lgFailAgg   = nan(size(phaseComp));
surfRetAgg  = nan(size(phaseComp));
lgRetAgg    = nan(size(phaseComp));
surfRotAgg  = nan(size(phaseComp));
lgRotAgg    = nan(size(phaseComp));
surfTransAgg= nan(size(phaseComp));
lgTransAgg  = nan(size(phaseComp));

for i = 1:numel(phaseComp)
    m = C.PhaseOffset == phaseComp(i);

    % failure/retention: mean across the six readout conditions
    surfFailAgg(i) = mean(C.SURF_PoseFailurePercent(m),'omitnan');
    lgFailAgg(i)   = mean(C.LightGlue_PoseFailurePercent(m),'omitnan');

    surfRetAgg(i)  = mean(C.SURF_MedianInlierRetentionPercent(m),'omitnan');
    lgRetAgg(i)    = mean(C.LightGlue_MedianInlierRetentionPercent(m),'omitnan');

    % degradation: median across readout conditions
    surfRotAgg(i)  = median(C.SURF_MedianDeltaRotationErrorDeg(m),'omitnan');
    lgRotAgg(i)    = median(C.LightGlue_MedianDeltaRotationErrorDeg(m),'omitnan');

    surfTransAgg(i)= median(C.SURF_MedianDeltaTranslationErrorDeg(m),'omitnan');
    lgTransAgg(i)  = median(C.LightGlue_MedianDeltaTranslationErrorDeg(m),'omitnan');
end

fig = figure('Color','w','Position',figPos4);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax=nexttile;
plot(phaseComp,surfFailAgg,'--o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
hold on;
plot(phaseComp,lgFailAgg,'-s','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',lgColor,'MarkerFaceColor','w');
hold off;
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off; ylim([0 105]);
xlabel('Relative PWM phase (cycles)');
ylabel('Mean pose failure (%)');
title('(a) Pose-recovery failure','FontWeight','bold');
legend('SURF','SuperPoint + LightGlue','Location','best','Box','off');

ax=nexttile;
plot(phaseComp,surfRetAgg,'--o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
hold on;
plot(phaseComp,lgRetAgg,'-s','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',lgColor,'MarkerFaceColor','w');
hold off;
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off; ylim([0 100]);
xlabel('Relative PWM phase (cycles)');
ylabel('Mean median inlier retention (%)');
title('(b) Correspondence robustness','FontWeight','bold');
legend('SURF','SuperPoint + LightGlue','Location','best','Box','off');

ax=nexttile;
plot(phaseComp,surfRotAgg,'--o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
hold on;
plot(phaseComp,lgRotAgg,'-s','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',lgColor,'MarkerFaceColor','w');
hold off;
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off;
xlabel('Relative PWM phase (cycles)');
ylabel('Median \Delta rotation error (deg)');
title('(c) Rotation degradation','FontWeight','bold');
legend('SURF','SuperPoint + LightGlue','Location','best','Box','off');

ax=nexttile;
plot(phaseComp,surfTransAgg,'--o','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',surfColor,'MarkerFaceColor','w');
hold on;
plot(phaseComp,lgTransAgg,'-s','LineWidth',lineWidth,'MarkerSize',markerSize,...
    'Color',lgColor,'MarkerFaceColor','w');
hold off;
set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',axisLineWidth,'Box','on');
grid off;
xlabel('Relative PWM phase (cycles)');
ylabel('Median \Delta translation error (deg)');
title('(d) Translation-direction degradation','FontWeight','bold');
legend('SURF','SuperPoint + LightGlue','Location','best','Box','off');

exportBoth(fig,outputFolder,'Figure08_SURF_vs_LightGlue');
close(fig);

%% ============================================================
% COPY FIGURE 1 INTO THE NEW OUTPUT FOLDER IF IT EXISTS
%% ============================================================

fig1Candidates = { ...
    fullfile(oldFigureFolder,'Figure01_conceptual_mechanism.png'), ...
    fullfile(repoPaths.figuresRoot,'main','Figure01_conceptual_mechanism.png')};

for k = 1:numel(fig1Candidates)
    if isfile(fig1Candidates{k})
        copyfile(fig1Candidates{k}, ...
            fullfile(outputFolder,'Figure01_conceptual_mechanism.png'));
        break;
    end
end

%% ============================================================
% FINISH
%% ============================================================

fprintf('\n============================================\n');
fprintf('ALL JOURNAL FIGURES COMPLETE\n');
fprintf('============================================\n');
fprintf('Saved to:\n%s\n\n',outputFolder);
fprintf('Use the PDF versions in Overleaf for Figures 2--8 when possible.\n');
fprintf('Keep Figure 1 as PNG unless you have a vector version.\n');

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function addHeatmapLabels(ax,xVals,yVals,M,fmt,fontName,fontSize)
axes(ax);
for i = 1:numel(yVals)
    for j = 1:numel(xVals)
        v = M(i,j);
        if isfinite(v)
            text(xVals(j),yVals(i),sprintf(fmt,v), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontName',fontName, ...
                'FontSize',fontSize, ...
                'FontWeight','bold', ...
                'Color','k');
        end
    end
end
end

function addHeatmapLabelsWithN(ax,xVals,yVals,M,N,fmt,fontName,fontSize)
axes(ax);
for i = 1:numel(yVals)
    for j = 1:numel(xVals)
        v = M(i,j);
        n = N(i,j);

        if isfinite(v)
            label = sprintf([fmt '\nN=%d'],v,n);
        else
            if n == 0
                label = 'FAIL';
            else
                label = sprintf('N=%d',n);
            end
        end

        text(xVals(j),yVals(i),label, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontName',fontName, ...
            'FontSize',fontSize, ...
            'FontWeight','bold', ...
            'Color','k');
    end
end
end

function exportBoth(fig,outFolder,baseName)

pngFile = fullfile(outFolder,[baseName '.png']);
pdfFile = fullfile(outFolder,[baseName '.pdf']);

exportgraphics(fig,pngFile,'Resolution',600);
exportgraphics(fig,pdfFile,'ContentType','vector');

fprintf('Saved: %s\n',baseName);

end

function [T,sourceFile] = findMechanismTable(folder)

T = [];
sourceFile = '';

if ~isfolder(folder)
    return;
end

files = dir(fullfile(folder,'**','*.csv'));

for k = 1:numel(files)

    f = fullfile(files(k).folder,files(k).name);

    try
        X = readtable(f);
        names = X.Properties.VariableNames;

        a = findVar(names,{'GainMismatchRMS','MismatchRMS','RMSMismatch','gain_mismatch'});
        b = findVar(names,{'Retention','InlierRetention','retention'});
        c = findVar(names,{'PoseFailure','FailureRate','failure'});

        if ~isempty(a) && ~isempty(b) && ~isempty(c)
            T = X;
            sourceFile = f;
            return;
        end
    catch
    end
end
end

function name = findVar(names,candidates)

name = '';

normNames = lower(regexprep(names,'[^a-zA-Z0-9]',''));

for i = 1:numel(candidates)

    key = lower(regexprep(candidates{i},'[^a-zA-Z0-9]',''));

    idx = find(contains(normNames,key),1);

    if ~isempty(idx)
        name = names{idx};
        return;
    end
end
end
