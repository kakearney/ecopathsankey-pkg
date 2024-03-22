function Json = ecopathsankey(EM, file, varargin)
%ECOPATHSANKEY Create JSON file for use with d3 Ecopath sankey diagrams
%
% Json = ecopathsankey(EM, file)
% Json = ecopathsankey(EM, file, p1, v1, ...)
%
% Input variables:
%
%   Ewein:      Ecopath input structure (see ecopathlite.m)
%
%   file:       name of output .json file (extension can be left off)
%
% Optional input variables (passed as parameter/value pairs):
%
%   linkscale:  function to apply to flux values to scale.  By default, no
%               scaling is applied, but most webs spanning multiple orders
%               of magnitude will require it. [@(x) x]
%
%   round:      Fraction to round trophic level to for x-positioning
%               purposes (0.1 = round to nearest tenth, 0.05 = round to
%               nearest five-hendredths, etc). Keeping trophic level overly
%               precise leads to an unnecessarily high number of sankey
%               layers, and results in a cluttered graph, but too coarse a
%               precision may lead to too much node-stacking, decreasing
%               the size of the nodes.  The "right" value for a given food
%               web may require some experimentation. [0.1]
%
%   showdet:    Show flow to detritus on plot.  Still a work in progress,
%               since this causes detrital groups to be moved from their
%               proper TL = 1 position. Not recommended.  [false]
%
% Output variables:
%
%   Json:       structure of nodes and links properties, mirroring that
%               written to the JSON file.

% Copyright 2015-2016 Kelly Kearney

%--------------------
% Parse inputs
%--------------------

Opt.linkscale = @(x) x;
Opt.round = 0.1;
Opt.showdet = false;

Opt = parsepv(Opt, varargin);

%--------------------
% Data setup
%--------------------

EM = sortbytrophic(EM);
G = EM.graph('oos', false, 'det', Opt.showdet);

% Scale data if necessary

G.Edges.Weight = Opt.linkscale(G.Edges.Weight);

% Rearrange so gears are first (not really necessary, but this
% makes it easier to diagnose some errors groups are sorted by trophic
% level, top to bottom) 

order = [EM.ngroup+(1:EM.ngear) 1:EM.ngroup];
G = reordernodes(G, order);

nnode = EM.ngroup + EM.ngear;
idx = 0:(nnode-1);

% Set the x-position of nodes based on trophic level.  

tl = round(G.Nodes.TL./Opt.round) * Opt.round;
dl = min(diff(unique(tl)));

layer = tl./dl;

tlfull = tl;
tlround = layer .* dl; % To get fleet TL

layer = layer - min(layer);

%--------------------
% Write to JSON file
%--------------------

Ep = EM.ecopath;

% Reformat for JSON structure

Json.nodes = struct('nodes', num2cell(idx), ...
                    'name', G.Nodes.Name', ...
                    'layer', num2cell(layer'), ...
                    'B',   num2cell([nan(EM.ngear,1); Ep.b])', ...
                    'PB',  num2cell([nan(EM.ngear,1); Ep.pb])', ...
                    'QB',  num2cell([nan(EM.ngear,1); Ep.qb])', ...
                    'EE',  num2cell([nan(EM.ngear,1); Ep.ee])', ...
                    'TLf', num2cell(tlfull'), ...
                    'TLr', num2cell(tlround'));
                

val = G.Edges.Weight;
if min(val) < 0
    val = (min(val)) + 0.01*(max(val(:)) - min(val(:)));
end
    
Json.links = struct('source', num2cell(findnode(G, G.Edges.EndNodes(:,1))'-1), ...
                    'target', num2cell(findnode(G, G.Edges.EndNodes(:,2))'-1), ...
                    'value',  num2cell(val'), ...
                    'Q',      num2cell(G.Edges.Weight'));


% Save to file
             
[pth,fl,ex] = fileparts(file);
if isempty(ex)
    file = fullfile(pth, [fl '.json']);
elseif ~strcmp(ex, '.json')
    warning('File should be a .json file');
end

Jopt = struct('Compact', 0, ...
             'FileName', file, ...
             'NoRowBracket', 1);
         
savejson('', Json, Jopt);


