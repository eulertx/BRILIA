%mergeSimilarSeq will merge sequences with similar sequences, but differing
%by either X nts or Y% difference. This is similar to removeDupSeq.m, but
%instead of looking for identical seq only, this one selectively removes
%sequences that do not change the overall lineage tree drastically.
%
%  VDJdata = mergeSimilarSeq(VDJdata, Map, DiffCutoff)
%
%  INPUT
%    VDJdata: main BRILIA data cell array
%    Map: struct of indices of VDJdata columns
%    DiffCutoff: integer number of nts or fraction length of sequences for 
%      use in determining cutoff distance at which two sequences will not 
%      be grouped as one. Cutoff = 1 means nts with 1 nt difference will be
%      considered the same ONLY IF the lineage relations remains unchanged.
%
%  OUTPUT
%    O1:
%
function VDJdata = mergeSimilarSeq(varargin)
%To enable post-processing capabilities
if nargin >= 3
    varargin = cleanCommandLineInput(varargin{:});
    [VDJdata, Map, Cutoff] = deal(varargin{1:3});
    if isempty(VDJdata) || Cutoff <= 0; return; end %quick return
    Map = getVDJmapper(Map); %In case user uses VDJheader instead of Map
    VDJdata = mergeSimilarSeq_Calc(VDJdata, Map, Cutoff);
else
    FileNames = getBriliaFiles();
    if isempty(FileNames); return; end
    Cutoff = input('Merge sequences with differences greater than:\n 0 to 0.99 for seq length, or integer >= 1 for hamming distance: ');
    for f = 1:length(FileNames)
        [VDJdata, VDJheader, ~, ~, Map] = openSeqData(FileNames{f});
        CurNum = size(VDJdata, 1);
        VDJdata = mergeSimilarSeq_Calc(VDJdata, Map, Cutoff);
        [Path, ~, Ext, Pre] = parseFileName(FileNames{f});
        SaveName = fullfile(Path, sprintf('%s.Merge%0.2f%s', Pre, Cutoff, Ext));
        saveSeqData(SaveName, VDJdata, VDJheader);
        NewNum = size(VDJdata, 2);
        fprintf('%s: Finished with "%s".\n  Reduced %d similar sequences.\n', mfilename, FileNames{f}, CurNum - NewNum);
    end
end

function VDJdata = mergeSimilarSeq_Calc(VDJdata, Map, Cutoff)
IsSpliced = iscell(VDJdata{1});
if ~IsSpliced
    VDJdata = spliceData(VDJdata, Map); %Has to be done to ensure proper group numbers
end

warning('%s:', mfilename)
for y = 1:length(VDJdata)
    VDJdata{y} = mergeSimilarSeqPerGroup(VDJdata{y}, Map, Cutoff);
end
VDJdata = joinData(VDJdata, Map); %Have to join to ensure cluster-based splicing w/ correct GrpNum
if IsSpliced
    VDJdata = spliceData(VDJdata, Map); %Re-splice to ensure cluster-based splicing
end

function VDJdata = mergeSimilarSeqPerGroup(VDJdata, Map, Cutoff)
if size(VDJdata, 1) <= 1; return; end

AncMap = zeros(size(VDJdata, 1), 4);
AncMap(:, [1:2, 4]) = cell2mat(VDJdata(:, [Map.SeqNum, Map.ParNum, Map.Template]));
TC0 = sum(AncMap(:, 4));
%CODING_NOTE: instead of redoing this comparison, consider saving info in VDJdata after lineage inference
SeqIdx = nonzeros([Map.hSeq; Map.lSeq]);
Seq1 = ''; %Keep this to prevent an unassigned Seq1 length later
for j = 1:size(VDJdata, 1)
    if AncMap(j, 2) > 0
        Seq1 = horzcat(VDJdata{j, SeqIdx}); %The children
        Seq2 = horzcat(VDJdata{AncMap(j, 2) == AncMap(:, 1), SeqIdx}); %The parent
        AncMap(j, 3) = length(Seq1) - sum(cmprSeqMEX(Seq1, Seq2));
    end
end

if Cutoff >= 1 %Cutoff should be a integer
    CutLen = round(Cutoff);
else %Cutoff is a fraction of the sequence length
    CutLen = round(Cutoff * length(Seq1));
end

%Those that fall under the cutoff will be regrouped
Idx = find(AncMap(:, 3) <= CutLen & AncMap(:, 2) > 0);
for j = 1:length(Idx)
    MainPar = AncMap(Idx(j), 2); %This is the sequence that will remain
    MainParIdx = find(AncMap(:, 1) == MainPar);
    SamePar = AncMap(Idx(j), 1); %This is the sequence that will be lost
    MergeLoc = AncMap(:, 2) == SamePar; %These sequences must have new parents
    AncMap(MergeLoc, 2) = MainPar; %Reassigned parent to orphans
    AncMap(MainParIdx, 4) = AncMap(MainParIdx, 4) + AncMap(Idx(j), 4); %Added up the templates
end

AncMap(Idx, :) = [];
TC1 = sum(AncMap(:, 4));
if ~isequal(TC0, TC1); error('erer'); end
VDJdata(Idx, :) = [];
VDJdata(:, [Map.SeqNum; Map.ParNum; Map.Template]) = num2cell(AncMap(:, [1:2 4]));