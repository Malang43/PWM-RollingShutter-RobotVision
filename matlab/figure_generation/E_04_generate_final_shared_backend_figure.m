clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');

close all;

%% EXPERIMENT 18J - FINAL JOURNAL FIGURE
rootDir = repository_output(repoPaths,'main_shared_backend');

conditionFile = repository_input(repoPaths,'main_shared_backend/experiment18J_shared_backend_condition_summary.csv');
globalFile = repository_input(repoPaths,'main_shared_backend/experiment18J_shared_backend_global_summary.csv');

assert(isfile(conditionFile),'Missing condition summary.');
assert(isfile(globalFile),'Missing global summary.');

C = readtable(conditionFile);
G = readtable(globalFile);

C.Method = string(C.Method);
G.Method = string(G.Method);

phases = unique(C.Phase,'sorted');
methods = ["SURF","LightGlue"];

phaseSummary = table();

for m = 1:numel(methods)
    method = methods(m);

    for pidx = 1:numel(phases)
        ph = phases(pidx);

        idx = C.Method==method & abs(C.Phase-ph)<1e-12;
        X = C(idx,:);

        row = table( ...
            method, ...
            ph, ...
            mean(X.PoseFailurePercent,'omitnan'), ...
            mean(X.MedianInlierRetentionPercent,'omitnan'), ...
            'VariableNames',{ ...
            'Method','Phase', ...
            'MeanPoseFailurePercent', ...
            'MeanMedianRetentionPercent'});

        phaseSummary = [phaseSummary; row];
    end
end

surfGlobal = G(G.Method=="SURF",:);
lgGlobal   = G(G.Method=="LightGlue",:);

surfFailure = surfGlobal.OverallPairwisePoseFailurePercent;
lgFailure = lgGlobal.OverallPairwisePoseFailurePercent;

surfRetention = surfGlobal.MeanConditionMedianInlierRetentionPercent;
lgRetention = lgGlobal.MeanConditionMedianInlierRetentionPercent;

surfA = phaseSummary(phaseSummary.Method=="SURF",:);
lgA = phaseSummary(phaseSummary.Method=="LightGlue",:);

fig = figure('Color','w','Position',[100 100 1180 500]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile;

plot(surfA.Phase,surfA.MeanPoseFailurePercent,'-o', ...
    'LineWidth',2.2,'MarkerSize',7);
hold on;
plot(lgA.Phase,lgA.MeanPoseFailurePercent,'-s', ...
    'LineWidth',2.2,'MarkerSize',7);
hold off;

xlabel('Relative PWM phase (cycles)');
ylabel('Pose-failure rate (%)');
title('(a) Pairwise pose failure','FontWeight','bold');
legend('SURF','SuperPoint + LightGlue','Location','best','Box','off');
ylim([0 105]);
xticks(phases);
box on;
set(gca,'FontName','Arial','FontSize',11,'LineWidth',1);

text(0.03,0.93, ...
    sprintf('Overall: SURF %.1f%% | LightGlue %.1f%%',surfFailure,lgFailure), ...
    'Units','normalized','FontSize',10,'FontWeight','bold');

nexttile;

plot(surfA.Phase,surfA.MeanMedianRetentionPercent,'-o', ...
    'LineWidth',2.2,'MarkerSize',7);
hold on;
plot(lgA.Phase,lgA.MeanMedianRetentionPercent,'-s', ...
    'LineWidth',2.2,'MarkerSize',7);
hold off;

xlabel('Relative PWM phase (cycles)');
ylabel('Median inlier retention (%)');
title('(b) Geometric-inlier retention','FontWeight','bold');
legend('SURF','SuperPoint + LightGlue','Location','best','Box','off');
ylim([0 110]);
xticks(phases);
box on;
set(gca,'FontName','Arial','FontSize',11,'LineWidth',1);

text(0.03,0.93, ...
    sprintf('Overall: SURF %.1f%% | LightGlue %.1f%%',surfRetention,lgRetention), ...
    'Units','normalized','FontSize',10,'FontWeight','bold');

pngFile = fullfile(rootDir,'Figure08_shared_backend_SURF_vs_LightGlue.png');
pdfFile = fullfile(rootDir,'Figure08_shared_backend_SURF_vs_LightGlue.pdf');

exportgraphics(fig,pngFile,'Resolution',600);
exportgraphics(fig,pdfFile,'ContentType','vector');

fprintf('\nFINAL FIGURE CREATED\n');
fprintf('%s\n',pngFile);
fprintf('%s\n',pdfFile);

fprintf('\nNUMBERS FOR MANUSCRIPT\n');
fprintf('SURF pose failure: %.3f%%\n',surfFailure);
fprintf('LightGlue pose failure: %.3f%%\n',lgFailure);
fprintf('SURF mean condition median retention: %.3f%%\n',surfRetention);
fprintf('LightGlue mean condition median retention: %.3f%%\n',lgRetention);
fprintf('Failure-rate difference: %.3f percentage points\n',surfFailure-lgFailure);
fprintf('Retention difference: %.3f percentage points\n',lgRetention-surfRetention);
