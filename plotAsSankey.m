function plotAsSankey(EM, varargin)
%PLOTASSANKEY Plots an ecopathmodel object as sankey diagram
%
% plotAsSankey(EM, p1, v1, p2, v2, ...)
%
% This function plots an ecopathmodel food web as an interactive sankey
% diagram.  The sankey diagram shows the biomass fluxes through the food
% web, with a horizontal axis representing  trophic level.
%
% The diagram is built using the D3 Javascript library (specifically, using
% Denes Csala's modified sankey.js plugin, which allows the visualization
% of reverse links).  The resulting figure is stored as a small html file
% (holding a single SVG canvas) with acocmpanying script and stylesheet
% files that is viewed using Matlab's web browser. Alternatively, the files
% can be exported to a folder of the user's choice.
%
% A note on cross-origin requests: When opened using most web browsers,
% the index.html file created by this function will throw an error that
% cross origin requests are not allowed, and the page will remain blank
% (the error message is visible via the web console, e.g. under Chrome's
% Developer Tools).  This error is due to the default loading of the D3
% library across html.  To get around this error, you can: 
% 1) Use a browser that allows cross-origin requests, such as Matlab's Web
%    Browser, or Firefox.
% 2) Set up a local web server, and access the file via http://localhost.
%    Google for instructions for your operating system (I personally like
%    the python option: python -m SimpleHTTPServer).
% 3) Download a local copy of D3 from https://github.com/d3/d3 (Note that
%    this code required Version 3, and is not compatible (yet) with
%    Version 4 or above; on the GitHub page, click on Release Notes to
%    download older versions of D3), and set the d3path input variable to
%    point to your local copy of d3.min.js.
%
% Input variables:
%
%   EM:         an ecopathmodel object
%
% Optional input variables (passed as parameter/value pairs):
%
%   linkscale:  function handle.  Function should take as input a vector of
%               biomass flux values (i.e. Qij) and return a vector of the
%               same size.  Due to the loss of biomass to respiration,
%               non-predatory loss, and unassimilated matter (all flows not
%               depicted in this diagram), the flows at the upper end of
%               the food web are often orders of magnitude smaller than
%               those at the bottom; this can be used to lessen the visual
%               difference in edge width.  Note that nonlinear
%               tranformations will "break" the additive nature of the
%               sankey diagram, and strong transforms (such as logarithms) 
%               may even make the fluxes out of the node appear larger than
%               the fluxes into that node.
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
%   showdet:    Logical scalar, true to show flows to detritus on the plot.
%               This option is still a work in progress, since it causes
%               detrital groups to be moved from their proper TL = 1
%               position.
%
%   export:     name of folder to which the files that support the
%               visualization will be exported.  This includes:
%               index.html:         main html file, holding a single div
%                                   element with an SVG canvas. 
%               sankey.js:          the sankey diagram plugin; Denes
%                                   Csala's version from
%                                   http://sankey.csaladen.es.
%               ecopathsankey.js:   script to build ecopath-specific
%                                   diagram
%               ecopathsankey.css:  stylesheet
%            
%               If left empty, the files will be saved to a folder in the
%               temporaray directory.
%
%   d3path:     Path to the Data Driven Documents (D3) script.  By default,
%               this points to the latest online version of D3 Version 3 at
%               https://d3js.org/d3.v3.min.js (Version 4 is not yet
%               supported by my ecopathsankey plugin).

% Copyright 2016 Kelly Kearney

% Parse and check input

p = inputParser;
p.addParameter('export',    '',     @(x) validateattributes(x, {'char'}, {}));
p.addParameter('linkscale', @(x) x, @(x) validateattributes(x, {'function_handle'}, {}));
p.addParameter('round',     0.1,    @(x) validateattributes(x, {'numeric'}, {'scalar'}));
p.addParameter('showdet',   false,  @(x) validateattributes(x, {'logical'}, {'scalar'}));
p.addParameter('d3path',    '',     @(x) validateattributes(x, {'char'}, {}));

p.parse(varargin{:});
Opt = p.Results;

validateattributes(EM, {'ecopathmodel'}, {});

% Set up file names

if isempty(Opt.export)
    Opt.export = tempname;
end

if ~exist(Opt.export, 'dir')
    mkdir(Opt.export);
end

pth = fileparts(mfilename('fullpath'));
js1 = fullfile(pth, 'sankey.js');
js2 = fullfile(pth, 'ecopathsankey.js');
css = fullfile(pth, 'ecopathsankey.css');

copyfile(js1, Opt.export);
copyfile(js2, Opt.export);
copyfile(css, Opt.export);
js1 = 'sankey.js';
js2 = 'ecopathsankey.js';
css = 'ecopathsankey.css';
json = 'ecopathmodel.json';

index = fullfile(Opt.export, 'index.html');

if ~isempty(Opt.d3path)
    [~,d3file, ex] = fileparts(Opt.d3path);
    d3file = [d3file ex];
    copyfile(Opt.d3path, Opt.export);
else
    d3file = 'https://d3js.org/d3.v3.min.js';
end

% Create HTML index file

htmltemplate = {...
'<!DOCTYPE html>'
'<html>'
'  <head>'
'		<script src="_D3_"></script>'
'		<script src="_JS1_"></script>'
'		<script src="_JS2_"></script>'
'		<link href="_CSS_" rel="stylesheet">'
'  </head>'
'  <body>'
'		<div id="chart"></div>'
'    <script type="text/javascript">'	
'		d3.json("_JSON_", function(data) {' 
'		   d3.select("#chart")'
'				.datum(data)'
'		    .call(ecopathSankeyChart());'
'		});'
'		</script>'
'  </body>'
'</html>'};

htmltemplate = strrep(htmltemplate, '_D3_', d3file);
htmltemplate = strrep(htmltemplate, '_JS1_', js1);
htmltemplate = strrep(htmltemplate, '_JS2_', js2);
htmltemplate = strrep(htmltemplate, '_CSS_', css);
htmltemplate = strrep(htmltemplate, '_JSON_', json);


fid = fopen(index, 'wt');
fprintf(fid, '%s\n', htmltemplate{:});
fclose(fid);

% Create JSON file

Json = ecopathsankey(EM, fullfile(Opt.export, json), ...
    'linkscale', Opt.linkscale, ...
    'round', Opt.round, ...
    'showdet', Opt.showdet);

% View file in web browser

web(index);
