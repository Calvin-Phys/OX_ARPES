RS_MAP = OxA_CUT(i05_178742_RD.x, i05_178742_RD.y,sum(i05_178742_RD.value,[3 4]));
RS_MAP.x_name = i05_178742_RD.x_name;
RS_MAP.x_unit = i05_178742_RD.x_unit;
RS_MAP.y_name = i05_178742_RD.y_name;
RS_MAP.y_unit = i05_178742_RD.y_unit;


%%

set(groot,{'DefaultAxesXColor','DefaultAxesYColor','DefaultAxesZColor'},{'k','k','k'});
set(groot, 'DefaultAxesFontName', 'Arial');
set(groot, 'DefaultTextFontName', 'Arial');
h1 = figure('Name','map FS','Renderer', 'painters');
h1.Units = 'centimeters';
h1.Position = [2 2 18.5 14];


tiledlayout(3, 4,'TileSpacing','compact','Padding','compact');

% cut 1
ha1 = nexttile;
ha1.Layer = 'top'; 
set(ha1,'DefaultLineLineWidth',0.5);
set(ha1,'linewidth',0.5);
fontname(ha1,"Arial");
set(ha1,'fontsize',6);

hold on
DATA = RS_MAP;
% DATA.value = DATA.value.^1.6;
imagesc(ha1,DATA.x,DATA.y,DATA.value');

scatter([-0.2 0.4 0.5],[-2.8 -3.1 -3.9],15,"red","x")

xlabel(ha1,'Position X (mm)');
ylabel(ha1,'Position Y (mm)');

set(ha1,'YDir','normal');

load('oxa_colourmap.mat');
colormap(ha1,flip(oxa_blue));
clim(ha1,[0 1.7*max(DATA.value,[],"all")]);

axis tight
axis equal
xtickangle(0);

% This syntax just sets the axis limits to their current value
xlim(ha1, xlim(ha1));
ylim(ha1, ylim(ha1));

% Set right and upper axis lines to same color as axes
xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color,'Alpha',1);
yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color,'Alpha',1);

% copyobj(lines_BZ,ha1);

set(ha1,'TickDir','out');
box(ha1,'off');
set(ha1,'XMinorTick','on','YMinorTick','on');
ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

xticklabels(strrep(xticklabels,'-','−'));
yticklabels(strrep(yticklabels,'-','−'));

% cut 2
ha1 = nexttile;
ha1.Layer = 'top'; 
set(ha1,'DefaultLineLineWidth',0.5);
set(ha1,'linewidth',0.5);
fontname(ha1,"Arial");
set(ha1,'fontsize',6);

hold on
DATA = i05_178742_X020_Y280;
% DATA.value = DATA.value.^1.6;
imagesc(ha1,DATA.x,DATA.y,DATA.value');

xlabel(ha1,'Angle (deg)');
ylabel(ha1,'Kinetic Energy (eV)');

set(ha1,'YDir','normal');

load('oxa_colourmap.mat');
colormap(ha1,flip(oxa_blue));
clim(ha1,[0 1.7*max(DATA.value,[],"all")]);

axis tight
% axis equal
xtickangle(0);

% This syntax just sets the axis limits to their current value
xlim(ha1, xlim(ha1));
ylim(ha1, ylim(ha1));

% Set right and upper axis lines to same color as axes
xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color,'Alpha',1);
yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color,'Alpha',1);

% copyobj(lines_BZ,ha1);

set(ha1,'TickDir','out');
box(ha1,'off');
set(ha1,'XMinorTick','on','YMinorTick','on');
ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

xticklabels(strrep(xticklabels,'-','−'));
yticklabels(strrep(yticklabels,'-','−'));

% cut 3
ha1 = nexttile;
ha1.Layer = 'top'; 
set(ha1,'DefaultLineLineWidth',0.5);
set(ha1,'linewidth',0.5);
fontname(ha1,"Arial");
set(ha1,'fontsize',6);

hold on
DATA = i05_178742_X040_Y310;
% DATA.value = DATA.value.^1.6;
imagesc(ha1,DATA.x,DATA.y,DATA.value');

xlabel(ha1,'Angle (deg)');
ylabel(ha1,'Kinetic Energy (eV)');

set(ha1,'YDir','normal');

load('oxa_colourmap.mat');
colormap(ha1,flip(oxa_blue));
clim(ha1,[0 1.7*max(DATA.value,[],"all")]);

axis tight
% axis equal
xtickangle(0);

% This syntax just sets the axis limits to their current value
xlim(ha1, xlim(ha1));
ylim(ha1, ylim(ha1));

% Set right and upper axis lines to same color as axes
xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color,'Alpha',1);
yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color,'Alpha',1);

% copyobj(lines_BZ,ha1);

set(ha1,'TickDir','out');
box(ha1,'off');
set(ha1,'XMinorTick','on','YMinorTick','on');
ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

xticklabels(strrep(xticklabels,'-','−'));
yticklabels(strrep(yticklabels,'-','−'));

% cut 4
ha1 = nexttile;
ha1.Layer = 'top'; 
set(ha1,'DefaultLineLineWidth',0.5);
set(ha1,'linewidth',0.5);
fontname(ha1,"Arial");
set(ha1,'fontsize',6);

hold on
DATA = i05_178742_X050_Y390;
% DATA.value = DATA.value.^1.6;
imagesc(ha1,DATA.x,DATA.y,DATA.value');

xlabel(ha1,'Angle (deg)');
ylabel(ha1,'Kinetic Energy (eV)');

set(ha1,'YDir','normal');

load('oxa_colourmap.mat');
colormap(ha1,flip(oxa_blue));
clim(ha1,[0 1.7*max(DATA.value,[],"all")]);

axis tight
% axis equal
xtickangle(0);

% This syntax just sets the axis limits to their current value
xlim(ha1, xlim(ha1));
ylim(ha1, ylim(ha1));

% Set right and upper axis lines to same color as axes
xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color,'Alpha',1);
yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color,'Alpha',1);

set(ha1,'TickDir','out');
box(ha1,'off');
set(ha1,'XMinorTick','on','YMinorTick','on');
ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

xticklabels(strrep(xticklabels,'-','−'));
yticklabels(strrep(yticklabels,'-','−'));

%

for iPC = 1:6
    hai = nexttile;
    hai.Layer = 'top'; 
    set(hai,'DefaultLineLineWidth',0.5);
    set(hai,'linewidth',0.5);
    fontname(hai,"Arial");
    set(hai,'fontsize',6);

    scoreMap = result.pca.scoreMap(:, :, iPC).';

    hImage = imagesc(hai, RS_MAP.x, RS_MAP.y, scoreMap);

    xlabel(hai,'Position X (mm)');
    ylabel(hai,'Position Y (mm)');
    
    set(hai,'YDir','normal');
    
    load('oxa_colourmap.mat');
    colormap(hai,oxa_redwhiteblue);
    clim(hai,[-1.2*max(scoreMap,[],"all") 1.2*max(scoreMap,[],"all")]);
    
    axis tight
    axis equal
    xtickangle(0);
    
    % This syntax just sets the axis limits to their current value
    xlim(hai, xlim(hai));
    ylim(hai, ylim(hai));
    
    % Set right and upper axis lines to same color as axes
    xline(max(xlim(hai)), 'k-', 'Color', hai.XAxis.Color,'Alpha',1);
    yline(max(ylim(hai)), 'k-', 'Color', hai.YAxis.Color,'Alpha',1);
    
    
    set(hai,'TickDir','out');
    box(hai,'off');
    set(hai,'XMinorTick','on','YMinorTick','on');
    hai.XAxis.MinorTickValues = interp1(1:length(hai.XTick),hai.XTick,0.5:0.5:(length(hai.XTick)+0.5),'linear','extrap');
    hai.YAxis.MinorTickValues = interp1(1:length(hai.YTick),hai.YTick,0.5:0.5:(length(hai.YTick)+0.5),'linear','extrap');
    
    xticklabels(strrep(xticklabels,'-','−'));
    yticklabels(strrep(yticklabels,'-','−'));

    title( hai, sprintf('PC#%d (%.2f%%)', iPC, result.pca.explained(iPC)));

end


%
ha1 = nexttile;
ha1.Layer = 'top'; 
set(ha1,'DefaultLineLineWidth',0.5);
set(ha1,'linewidth',0.5);
fontname(ha1,"Arial");
set(ha1,'fontsize',6);

hold on
DATA = result.clustering(4).map;
% DATA.value = DATA.value.^1.6;
imagesc(ha1,RS_MAP.x,RS_MAP.y,DATA');

xlabel(ha1,'Position X (mm)');
ylabel(ha1,'Position Y (mm)');

set(ha1,'YDir','normal');

title( 'Cluster map (5)');
colormap(ha1, turbo(5));
clim(ha1, [0.5 5 + 0.5]);

axis tight
axis equal
xtickangle(0);

% This syntax just sets the axis limits to their current value
xlim(ha1, xlim(ha1));
ylim(ha1, ylim(ha1));

% Set right and upper axis lines to same color as axes
xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color,'Alpha',1);
yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color,'Alpha',1);

% copyobj(lines_BZ,ha1);

set(ha1,'TickDir','out');
box(ha1,'off');
set(ha1,'XMinorTick','on','YMinorTick','on');
ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

xticklabels(strrep(xticklabels,'-','−'));
yticklabels(strrep(yticklabels,'-','−'));

%
ha1 = nexttile;
ha1.Layer = 'top'; 
set(ha1,'DefaultLineLineWidth',0.5);
set(ha1,'linewidth',0.5);
fontname(ha1,"Arial");
set(ha1,'fontsize',6);

hold on
DATA = result.clustering(5).map;
% DATA.value = DATA.value.^1.6;
imagesc(ha1,RS_MAP.x,RS_MAP.y,DATA');

xlabel(ha1,'Position X (mm)');
ylabel(ha1,'Position Y (mm)');

set(ha1,'YDir','normal');

title( 'Cluster map (6)');
colormap(ha1, turbo(6));
clim(ha1, [0.5 6 + 0.5]);

axis tight
axis equal
xtickangle(0);

% This syntax just sets the axis limits to their current value
xlim(ha1, xlim(ha1));
ylim(ha1, ylim(ha1));

% Set right and upper axis lines to same color as axes
xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color,'Alpha',1);
yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color,'Alpha',1);

% copyobj(lines_BZ,ha1);

set(ha1,'TickDir','out');
box(ha1,'off');
set(ha1,'XMinorTick','on','YMinorTick','on');
ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

xticklabels(strrep(xticklabels,'-','−'));
yticklabels(strrep(yticklabels,'-','−'));

fontsize(gcf, 6, 'points');

exportgraphics(h1,".\PCA.pdf",'ContentType','vector','BackgroundColor','none');