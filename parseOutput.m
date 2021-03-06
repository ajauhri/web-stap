%% do parsing
clear all; close all;
!rm -f .tmp*

TIMESTAMP_INDEX = 2;
MANUAL_CRAWLING_MODE = false;
BROWSER = 'chrome';

if MANUAL_CRAWLING_MODE
    OUTPUT_DIR = 'specific_jobs';
else
    OUTPUT_DIR = 'output';
end

files = dir(OUTPUT_DIR);
sites = [];

for i=3:length(files)
    sites = [sites {strtok(files(i).name,'-')}];
end

sites = unique(sites);
numSites = length(sites);
allConns = cell(1, numSites);
allConnsM = cell(1, numSites);
allLoadtimes = cell(1, numSites);
allLoadtimesM = cell(1, numSites);
allStaps = cell(1, numSites);
allStapsM = cell(1, numSites);

tic
parfor i=1:numSites
   fname = sprintf('%s/%s-desktop-%s-conns.csv.bz2', OUTPUT_DIR, sites{i}, BROWSER);
   fprintf('[%d of %d] %s\n', i, length(sites), sites{i})
   
   if ~MANUAL_CRAWLING_MODE
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end
       conns = str2num(out);

       fname = sprintf('%s/%s-mobile-%s-conns.csv.bz2', OUTPUT_DIR, sites{i}, BROWSER);
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end
       connsM = str2num(out);

       fname = sprintf('%s/%s-desktop-%s-loadtime.csv.bz2', OUTPUT_DIR, sites{i}, BROWSER);
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end

       % load times structure:
       % [timeConnect,timeDomLoad, timeDns, timeRedirect, timeResponse]

       loadtime = str2num(out);

       fname = sprintf('%s/%s-mobile-%s-loadtime.csv.bz2', OUTPUT_DIR, sites{i}, BROWSER);
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end
       loadtimeM = str2num(out);

       % if dom never loaded, or if page loaded abnormally fast...
       % TODO: fix this -- too many false positives
       if loadtime(2) < 0 || loadtimeM(2) < 0 || ... 
               loadtime(1) <= 0 || loadtimeM(1) <= 0
           fprintf('Skipping %s (no page load) \n', sites{i});
           continue
       end
       
       fname = sprintf('%s/%s-mobile-%s-stap.csv.bz2', OUTPUT_DIR, sites{i}, BROWSER);
       tmpname = sprintf('.tmp.%s', sites{i});
       cmd = sprintf( 'bash masterStapParse.sh %s %s', fname, sites{i});
       
       [status, out] = system(cmd);
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end
       stapsM = importdata(tmpname);
       delete(tmpname)
   end
   
   fname = sprintf('%s/%s-desktop-%s-stap.csv.bz2', OUTPUT_DIR, sites{i}, BROWSER);
   tmpname = sprintf('.tmp.%s', sites{i});
   cmd = sprintf( 'bash masterStapParse.sh %s %s', fname, sites{i});
   
   [status, out] = system(cmd);
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       continue
   end
   staps = importdata(tmpname);
   delete(tmpname)
   
   if ~MANUAL_CRAWLING_MODE && (length(conns) < 250 || length(connsM) < 250 || ...
           isempty(staps) || isempty(stapsM) || ...
           size(stapsM, 2) ~= 3 || size(stapsM, 2) ~= 3)
       fprintf('Skipping %s (odd output)\n', sites{i});
      continue 
   end
   
   startTime = min(staps(:,TIMESTAMP_INDEX));
   staps(:,TIMESTAMP_INDEX) = staps(:,TIMESTAMP_INDEX) - startTime;
   if ~MANUAL_CRAWLING_MODE
       startTime = conns(1,1);
       conns(:,1) = conns(:,1) - startTime;
       startTime = connsM(1,1);
       connsM(:,1) = connsM(:,1) - startTime;
       startTime = min(stapsM(:,TIMESTAMP_INDEX));
       stapsM(:,TIMESTAMP_INDEX) = stapsM(:,TIMESTAMP_INDEX) - startTime;
       
       % ensure we're actually looking at time
       assert(~any(staps(:,TIMESTAMP_INDEX) > 250))
       assert(~any(stapsM(:,TIMESTAMP_INDEX) > 250))
   else
       loadtime = [];
       conns = [];
       connsM = [];
       stapsM = [];
       loadtimeM = [];
   end
   
   allConns{i} = conns;
   allConnsM{i} = connsM;
   allLoadtimes{i} = loadtime;
   allLoadtimesM{i} = loadtimeM;
   allStaps{i} = staps;
   allStapsM{i}= stapsM;
end

% remove failed sites
for i=length(sites):-1:1
    if isempty(allStaps{i})
        sites(i) = [];
        allConns(i) = [];
        allConnsM(i) = [];
        allLoadtimes(i) = [];
        allLoadtimesM(i) = [];
        allStaps(i) = [];
        allStapsM(i) = [];
    end
end
failedSites = numSites - length(sites);
numSites = length(sites);

toc
fprintf('Done! %d sites parsed successfully, %d failed.\n', numSites, failedSites)

%% link stap indices
fprintf('Extracting features using feature_names...\n')
load feature_names
stap_feature_names = feature_names;

assert(size(stap_feature_names,2) == 1)
stapTypes = length(stap_feature_names);
numSites = length(allStaps);

stapDataAggregated = cell(numSites, stapTypes);
stapDataAggregatedM = cell(numSites, stapTypes);

for i=1:numSites
    staps = allStaps{i};
    stapsM = allStapsM{i};
    for j=1:stapTypes
       relevantStaps = staps(staps(:,1) == j, 2:3);
       stapDataAggregated{i,j} = relevantStaps;
       
       if ~MANUAL_CRAWLING_MODE
           relevantStapsM = stapsM(stapsM(:,1) == j, 2:3);
           stapDataAggregatedM{i,j} = relevantStapsM;
       end
    end
    if round(mod(i, numSites / 20)) == 0
      fprintf('%.2f%% [%d of %d] \n', i/numSites*100,i,numSites)
    end
end
fprintf('Saving output...\n')
save output

%% plot staps (single site)
siteIndex = length(sites) - 17;
stapID = 119;
relevantStap = stapDataAggregated{siteIndex, stapID};

timestamps = relevantStap(:,1);
feature = relevantStap(:,end);
plot(timestamps,feature)
title(sites{siteIndex});
ylabel(strrep(stap_feature_names(stapID), '_', '\_'))
xlabel('Time (sec)')
axis tight

%% plot everything individually (all sites)
save_figs = true;
use_export_fig = false;
use_hgsave = true;
close all;
mkdir('figs');
tic
for i=1:numSites
    sitename = sites(i);
    fprintf('[%d of %d] %s\n', i, length(sites), sites{i})
    mkdir(sprintf('figs/%s',sitename{:}));
    for j=1:stapTypes
       featureName = stap_feature_names(j);
       relevantStap = stapDataAggregated{i, j};
       relevantStapM = stapDataAggregatedM{i, j};
       
       if size(relevantStap,1) <= 5
          continue 
       end
       fprintf('--> plotting %s (%d of %d) \n', featureName{:}, j, stapTypes)
       % relevantStap-format: [timestamp, feature]
       
       stap_time_series = sortrows(relevantStap);
       stap_time_seriesM = sortrows(relevantStapM);
       subplot(2,1,1)
       plot(stap_time_series(:,1),stap_time_series(:,2), ...
           'Linewidth', 1, 'MarkerSize',4, 'Color', [55 126 184]/255)
       hold all
       plot(stap_time_seriesM(:,1),stap_time_seriesM(:,2), ...
           '--','Linewidth', 1, 'MarkerSize',4,'Color',[77 175 74]/255)
       box off
       ylabel(featureName{:})
       title(sprintf('%s -- %s', sitename{:}, cell2mat(strrep(featureName, '_', '\_'))))
       legend('Desktop UA' ,'Mobile UA')
       
       subplot(2,1,2)
       plot(stap_time_series(:,1),cumsum(stap_time_series(:,2)), ...
           'Linewidth', 1, 'MarkerSize',4, 'Color', [55 126 184]/255)
       hold all
       plot(stap_time_seriesM(:,1),cumsum(stap_time_seriesM(:,2)), ...
           '--','Linewidth', 1, 'MarkerSize',4,'Color',[77 175 74]/255)
       box off
       ylabel('Cumulative sum')
       xlabel('Time (seconds)')
       legend('Desktop UA' ,'Mobile UA')
       
       if save_figs
           set(gcf,'PaperPositionMode','auto')
           if use_export_fig
                export_fig(sprintf('figs/%s/%d.%s.png', ...
                   sitename{:}, j, featureName{:}), '-r300')
           else
               print(gcf,'-dpng','-r300', sprintf('figs/%s/%d.%s.png', ...
                   sitename{:}, j, featureName{:}))
           end
           if  use_hgsave
               hgsave(sprintf('figs/%s/%d.%s.fig', ...
                   sitename{:}, j, featureName{:}));
           end
       else
           pause
       end
       clf('reset')
    end
end
close all
toc

%% calculate aggregates
DURATION = 150; % seconds
BINS = 30;

binduration = DURATION / BINS;
aggDat = zeros(numSites, stapTypes, BINS);
aggDatM = zeros(numSites, stapTypes, BINS);

for i=1:numSites
    fprintf('[%d of %d]\n', i, numSites)
    for j=1:stapTypes
       relevantStap = stapDataAggregated{i, j};
       relevantStapM = stapDataAggregatedM{i, j};

       stap_time_series = sortrows(relevantStap);
       stap_time_seriesM = sortrows(relevantStapM);
       
        for b=1:BINS
            binDat = stap_time_series(binduration * (b-1) <= stap_time_series(:,1) & ...
                stap_time_series(:,1) < (binduration * b), 2);
            aggDat(i, j, b) = sum(binDat);
            
            binDatM = stap_time_seriesM(binduration * (b-1) <= stap_time_seriesM(:,1) & ...
                stap_time_seriesM(:,1) < (binduration * b), 2);
            aggDatM(i, j, b) = sum(binDatM);
        end
        
    end
end
fprintf('Done!\n')

%% plot aggregate means
% close all

subplot(2,1,1)

means = mean(squeeze(aggDat(:,119,:)/1024));
stds = std(squeeze(aggDat(:,119,:)/1024));
meansM = mean(squeeze(aggDatM(:,119,:)/1024));
stdsM = std(squeeze(aggDatM(:,119,:)/1024));

errorbar((0:BINS-1)*binduration, means,stds, 'linewidth', 1', 'Color', [55 126 184]/255)
hold all
errorbar((0:BINS-1)*binduration, meansM,stdsM,'--', 'linewidth', 1, 'Color', [77 175 74]/255)
box off
axis tight
title('Network Activity (Sent)')
ylabel('KB sent')
xlabel('Time (seconds)')
legend('Desktop UA', 'Mobile UA')
tmp = ylim;
ylim([0 tmp(2)])

subplot(2,1,2)
means = mean(squeeze(aggDat(:,118,:)/1024));
stds = std(squeeze(aggDat(:,118,:)/1024));
meansM = mean(squeeze(aggDatM(:,118,:)/1024));
stdsM = std(squeeze(aggDatM(:,118,:)/1024));

errorbar((0:BINS-1)*binduration, means,stds, 'linewidth', 1', 'Color', [55 126 184]/255)
hold all
errorbar((0:BINS-1)*binduration, meansM,stdsM,'--', 'linewidth', 1, 'Color', [77 175 74]/255)
box off
axis tight
title('Network Activity (Received)')
ylabel('KB received')
xlabel('Time (seconds)')
legend('Desktop UA', 'Mobile UA')
tmp = ylim;
ylim([0 tmp(2)])

%% plot aggregate errorbars
mkdir('figs-aggregate')
close all
save_figs = true;
for j=1:stapTypes
    featureName = stap_feature_names(j);
    
    means = mean(squeeze(aggDat(:,j,:)));
    stds = std(squeeze(aggDat(:,j,:)));
    errorbar((0:BINS-1)*binduration, means,stds, 'linewidth', 1,'Color', [55 126 184]/255)
    hold all

    meansM = mean(squeeze(aggDatM(:,j,:)));
    stdsM = std(squeeze(aggDatM(:,j,:)));
    errorbar((0:BINS-1)*binduration, meansM,stdsM,'--', 'linewidth', 1, 'Color',[77 175 74]/255)
    
    ylabel(strcat(strrep(featureName, '_', '\_'), ' syscalls'))
    xlabel('Time (seconds)')
    legend('Desktop UA', 'Mobile UA')
    box off
    tmp = ylim;
    tmp(1) = 0;
    ylim(tmp)
    xlim([0 BINS * binduration])
    
    if save_figs
        set(gcf,'PaperPositionMode','auto');
        print(gcf,'-dpng','-r300', sprintf('figs-aggregate/%d-%s-eb.png', ...
            j, featureName{:}))
        hgsave(sprintf('figs-aggregate/%d-%s-eb.fig', ...
            j, featureName{:}))
    else
        pause
    end
    clf('reset')
end
close all

%% plot aggregates boxplots
mkdir('figs-aggregate')
close all
save_figs = true;
for j=1:stapTypes
    featureName = stap_feature_names(j);
    
    subplot(2,1,1)
    boxplot(squeeze(aggDat(:,j,:)), 'plotstyle','compact','symbol', '')
    set(gca,'XTickLabel',{' '})
    title(strrep(featureName, '_', '\_'))
    axis tight
    ylabel('Frequency (desktop)')
%     ylim([0 1e4])
    subplot(2,1,2)
    boxplot(squeeze(aggDatM(:,j,:)),  'plotstyle','compact','symbol', '')
    set(gca,'XTickLabel',{' '})
%     ylim([0 1e4])
    axis tight
    ylabel('Frequency (mobile)')
    
    if save_figs
        set(gcf,'PaperPositionMode','auto');
        print(gcf,'-dpng','-r300', sprintf('figs-aggregate/%d-%s.png', ...
            j, featureName{:}))
    else
        pause
    end
    clf('reset')
end
close all

%% plot loadtimes
loadtimes = cell2mat(cellfun(@(c) c', allLoadtimes, 'uniformoutput', false));
loadtimesM = cell2mat(cellfun(@(c) c', allLoadtimesM, 'uniformoutput', false));

lnames = ['timeConnect','timeDomLoad', 'timeDns', 'timeRedirect', 'timeResponse'];

%% setup connection matrix
conns = cell2mat(cellfun(@(c) c(1:500,2), allConns, 'uniformoutput', false));
connsM = cell2mat(cellfun(@(c) c(1:500,2), allConnsM, 'uniformoutput', false));

%% plot results
close all
for i=1:numSites
    conns = allConns{i};
    plot(conns(:,1), conns(:,2))
    hold all
end
% legend(sites)

%% boxplots

subplot(2,1,1)
boxplot(conns')
ylabel('Connections')
set(gca,'XTickLabel',{' '})
title('Desktop UA')
subplot(2,1,2)

boxplot(connsM')
set(gca,'XTickLabel',{' '})
ylabel('Connections')
title('Mobile UA')

%% means
plot((1:size(conns,1))/4.5,mean(conns, 2),'linewidth', 1)
hold all
plot((1:size(conns,1))/4.5,mean(connsM, 2), '--', 'linewidth', 1)
legend('Desktop UA', 'Mobile UA')
ylabel('Mean connections')
xlabel('Time (seconds)')
axis tight

%% barplot
bar([mean(conns); mean(connsM)]')
ylabel('Mean connections')
xlabel('Site index')

%% histogram
subplot(2,1,1)
hist([mean(conns)' mean(connsM)'], 20)
legend('Desktop UA', 'Mobile UA')
xlabel('Mean connections')
subplot(2,1,2)
hist([max(conns)' max(connsM)'], 20)
legend('Desktop UA', 'Mobile UA')
xlabel('Peak connections')

%% image-style
subplot(2,1,1)
imagesc(conns, [0 50])
ylabel('Time')
title('Desktop UA')
subplot(2,1,2)
imagesc(connsM, [0 50])
ylabel('Time')
title('Mobile UA')

%% single site
plot((1:600)/4.5, conns(:,15))
hold all
plot((1:600)/4.5, connsM(:,15),'--')
legend('Desktop UA', 'Mobile UA')
ylabel('Number of Connections')
xlabel('Time (seconds)')

%%
%%
%% BROWSER SPECIFIC PLOTTING
%%    ASSUMES: firefox, chrome structs
%%
%%
%% plot staps (single site), specific site
close all
site = 'ebay.com';

subplot(1,2,1)
v2struct(firefox)
siteIndex = find(strcmp(sites, site));
assert(siteIndex > 0)
stapID_FF = 118;
relevantStap = stapDataAggregated{siteIndex, stapID_FF};

timestamps = relevantStap(:,1);
feature = relevantStap(:,end);
totalSyscallsFirefox = sum(feature);

plot(timestamps,feature)
title(strcat(site, ' -- firefox'));
ylabel(strrep(stap_feature_names(stapID_FF), '_', '\_'))
xlabel('Time (sec)')
axis tight

subplot(1,2,2)
v2struct(chrome)
siteIndex = find(strcmp(sites, site));
assert(siteIndex > 0)

relevantStap = stapDataAggregated{siteIndex, stapID_FF};

timestamps = relevantStap(:,1);
feature = relevantStap(:,end);
totalSyscallsChrome = sum(feature);

plot(timestamps,feature)
title(strcat(site, ' -- chrome'));
ylabel(strrep(stap_feature_names(stapID_FF), '_', '\_'))
xlabel('Time (sec)')
axis tight

fprintf('-- %s (%s) --\n', stap_feature_names{stapID_FF}, site)
fprintf('Total Chrome network: %.2fMB\n', totalSyscallsChrome / 1024 / 1024)
fprintf('Total Firefox network: %.2fMB\n\n', totalSyscallsFirefox / 1024 / 1024)

%% plot total syscalls
% aggDat = [site,syscall,timestep]
close all

v2struct(chrome)
aggDatOnlySyscalls = aggDat(:,1:115,:);

totalSyscallsChrome = sum(mean((sum(aggDatOnlySyscalls,2)),1)); % mean per site
plot((0:BINS-1)*binduration, squeeze(mean((sum(aggDatOnlySyscalls,2)),1)), ...
    'linewidth', 1, 'Color', [69 117 180]/255)

v2struct(firefox)
aggDatOnlySyscalls = aggDat(:,1:115,:);
totalSyscallsFirefox = sum(mean((sum(aggDatOnlySyscalls,2)),1)); % mean per site
hold all
plot((0:BINS-1)*binduration, squeeze(mean((sum(aggDatOnlySyscalls,2)),1)), ...
    '--', 'linewidth', 1, 'Color', [215 48 39]/255)
legend('Chrome', 'Firefox')
ylabel('Mean number of system calls')
xlabel('Time (sec)')
box off

fprintf('Total Chrome syscalls: %d\n', totalSyscallsChrome)
fprintf('Total Firefox syscalls: %d\n', totalSyscallsFirefox)

%% number of connections
close all
figure; hold all;

v2struct(chrome)
conns = cell2mat(cellfun(@(c) c(1:500,2), allConns, 'uniformoutput', false));
connsM = cell2mat(cellfun(@(c) c(1:500,2), allConnsM, 'uniformoutput', false));
plot((1:size(conns,1))/4.5,mean(conns, 2),'linewidth', 1)
plot((1:size(connsM,1))/4.5,mean(connsM, 2),'--', 'linewidth', 1)

v2struct(firefox)
conns = cell2mat(cellfun(@(c) c(1:500,2), allConns, 'uniformoutput', false));
connsM = cell2mat(cellfun(@(c) c(1:500,2), allConnsM, 'uniformoutput', false));
hold all
plot((1:size(conns,1))/4.5,mean(conns, 2), 'linewidth', 1)
plot((1:size(connsM,1))/4.5,mean(connsM, 2),'--', 'linewidth', 1)
legend('Chrome', 'Chrome-mobile','Firefox', 'Firefox-mobile')
ylabel('Mean connections')
xlabel('Time (seconds)')
axis tight

%%
set(gcf,'PaperPositionMode','auto')
print(gcf,'-dpng','-r300', 'browser-syscalls.png')
