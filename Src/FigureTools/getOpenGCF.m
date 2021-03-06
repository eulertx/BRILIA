%getOpenGCF will get a current figure handle ONLY if there is one open.
%Otherwise, will return an empty matrix. Better than simple 'gcf' which
%will create a figure if there is none.
%
%  Gx = getOpenGCF
%
%  Gx = getOpenGCF(Gx)
%
%  Gx = getOpenGCF('all')
%
%  [Gx, varargout] = getOpenGCA(varargin{:})
%
%  INPUT
%    Gx: figure or axes handle
%    'all': will get all open figures
%    varargin: 1xM cell of inputs, in which this function checks if the
%      first one is a graphics handle or 'all'
%
%  OUTPUT
%    Gx: figure handle(s) that is (are) open or parent of axes handle
%    varargout: same as varargin, EXCEPT IF the first varargin cell is a
%      figure handle, then varargout removes the first cell

function [Gx, varargout] = getOpenGCF(varargin)
Gx = [];
varargout{1} = varargin;

if isempty(varargin) 
    if ~isempty(findobj(0, 'type', 'figure'))
        Gx = gcf;
    end
    return;
end

if isempty(varargin{1})
    if ~isempty(findobj(0, 'type', 'figure'))
        Gx = gcf;
    end
    varargout{1}(1) = [];
    return;
end

if ischar(varargin{1}) && strcmpi(varargin{1}, 'all')
    Gx = findobj(0, 'type', 'figure');
    if isempty(Gx)
        Gx = [];
    end
    varargout{1}(1) = [];
    return;
end

if strcmpi(class(varargin{1}), 'matlab.graphics.Graphics') %Determine all axes handles
    Ox = varargin{1};
    GetIdx = zeros(length(Ox), 1, 'logical');
    for j = 1:length(Ox)
        if strcmpi(class(Ox(j)), 'matlab.ui.Figure')
            GetIdx(j) = 1;
        end
    end
    Gx = Ox(GetIdx);
    varargout{1}(1) = [];
    return;
end

if strcmpi(class(varargin{1}(1)), 'matlab.graphics.axis.Axes')
    Gx = get(varargin{1}(1), 'parent');
    varargout{1}(1) = [];
    return;
end

if strcmpi(class(varargin{1}(1)), 'matlab.ui.Figure')
    Gx = varargin{1}(1);
    varargout{1}(1) = [];
    return;
end
