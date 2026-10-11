function filename = repository_output(paths,relativePath)
% New output location. Call with a relative directory or a relative filename.
filename = fullfile(paths.outputRoot,relativePath);
[~,~,extension] = fileparts(filename);
if isempty(extension), folder = filename; else, folder = fileparts(filename); end
if ~isfolder(folder), mkdir(folder); end
end
