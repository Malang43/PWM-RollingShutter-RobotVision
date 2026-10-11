function paths = repository_paths(sequence)
% Load the example and optional local path assignments, without changing RNG.
if nargin < 1, sequence = ''; end
paths = setup_paths_example();
localConfig = fullfile(paths.repoRoot,'matlab','setup_paths.m');
if isfile(localConfig), run(localConfig); end % Local script assigns paths.*.
% Canonical containment keeps writes inside this repository and out of inputs.
repo = char(java.io.File(paths.repoRoot).getCanonicalPath());
out = char(java.io.File(paths.outputRoot).getCanonicalPath());
required = fullfile(repo,'reproduction_work');
assert(startsWith(lower([out filesep]),lower([required filesep])), ...
    'outputRoot must be inside repository reproduction_work.');
assert(~strcmpi(out,char(java.io.File(paths.resultsRoot).getCanonicalPath())), ...
    'Output root must differ from saved result inputs.');
for key = {'tumXYZ','tumDesk'}
    dataset = paths.(key{1});
    if ~isempty(dataset)
        ds = char(java.io.File(dataset).getCanonicalPath());
        assert(~startsWith(lower([out filesep]),lower([ds filesep])), ...
            'Output root must not be inside a dataset.');
    end
end
if strcmp(sequence,'xyz')
    assert(~isempty(paths.tumXYZ) && isfolder(fullfile(paths.tumXYZ,'rgb')), ...
        'Set paths.tumXYZ in setup_paths_example.m or local setup_paths.m.');
elseif strcmp(sequence,'desk')
    assert(~isempty(paths.tumDesk) && isfolder(fullfile(paths.tumDesk,'rgb')), ...
        'Set paths.tumDesk in setup_paths_example.m or local setup_paths.m.');
end
end
