function G = ecopathsankey(Ewein, file, varargin)
%ECOPATHSANKEY Create JSON file for use with d3 Ecopath sankey diagrams
%
% G = ecopathsankey(Ewein, file)
% G = ecopathsankey(Ewein, file, p1, v1, ...)
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
%   G:          structure of nodes and links properties, mirroring that
%               written to the JSON file.

% Copyright 2015 Kelly Kearney

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

% Ecopath calculations

Ep = ecopathlite(Ewein, 'silent', true);

% Links show flow.  For now, not showing flow back to detritus (makes
% things far too messy in most cases).

adj = Ep.flow(1:end-1, 1:end-2);  % For now, ignore outside fluxes and resp
if ~Opt.showdet
    adj(:,Ep.Idx.det) = 0;
end

% % Eliminate cannibalism (until I can get that working in the sankey script)
% 
% if any(diag(adj))
%     warning('Self-cycles (cannibalism) cannot be displayed in current version');
%     adj = adj .* ~eye(size(adj));
% end

% Scale data if necessary

val = adj;
val(val~=0) = Opt.linkscale(val(val~=0));

% Node names

if ~isfield(Ewein, 'fleet')
    Ewein.fleet = cellstr(num2str((1:Ewein.ngear)', 'Fleet%d'));
end

grp = [Ewein.fleet; Ewein.name];
nnode = length(grp);

% Rearrange so gears are first (not really necessary, but this
% makes it easier to diagnose some errors since webs are usually ordered
% top to bottom of the food chain)

order = [Ewein.ngroup+1:Ewein.ngroup+Ewein.ngear 1:Ewein.ngroup];
adj = adj(order, order);
val = val(order, order);

idx = 0:(nnode-1);

% Set the x-position of nodes based on trophic level.  Put detritus 1 layer
% below lowest and fleet 1 layer above

tl = round(Ep.trophic./Opt.round) * Opt.round;
tl = [ones(Ewein.ngear,1)*max(tl); tl];

dl = min(diff(unique(tl)));

layer = tl./dl;
layer(1:Ewein.ngear) = max(layer) + 1;

tlfull = [nan(Ewein.ngear,1); Ep.trophic];
tlround = layer .* dl; % To get fleet TL

layer = layer - min(layer);


%--------------------
% Write to JSON file
%--------------------

% Nodes

G.nodes = struct('node', num2cell(idx), ...
                 'name', grp', ...
                 'layer', num2cell(layer'), ...
                 'B', num2cell([nan(Ewein.ngear,1); Ep.b])', ...
                 'PB', num2cell([nan(Ewein.ngear,1); Ep.pb])', ...
                 'QB', num2cell([nan(Ewein.ngear,1); Ep.qb])', ...
                 'EE', num2cell([nan(Ewein.ngear,1); Ep.ee])', ...
                 'TLf', num2cell(tlfull'), ...
                 'TLr', num2cell(tlround'));


             
% Links
             
[isrc,isnk] = find(val);
vidx = sub2ind(size(val), isrc, isnk);
val = val(vidx);
q = adj(vidx);

% val = adj(find(adj));

if min(val) < 0
    val = (min(val)) + 0.01*diff(minmax(val));
end

G.links = struct('source', num2cell(idx(isrc)), ...
                 'target', num2cell(idx(isnk)), ...
                 'value',  num2cell(val'), ...
                 'Q',      num2cell(q'));
             
% Save to file
             
[pth,fl,ex] = fileparts(file);
if isempty(ex)
    file = fullfile(pth, [fl '.json']);
elseif ~strcmp(ex, 'json')
    warning('File should be a .json file');
end

Jopt = struct('Compact', 0, ...
             'FileName', file, ...
             'NoRowBracket', 1);
         
savejson('', G, Jopt);


