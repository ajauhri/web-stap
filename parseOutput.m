%% do parsing
clear all; close all;
!rm -f .tmp*

TIMESTAMP_INDEX = 2;
MANUAL_CRAWLING_MODE = false;

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
   fname = sprintf('%s/%s-conns.csv.bz2', OUTPUT_DIR, sites{i});
   fprintf('[%d of %d] %s\n', i, length(sites), sites{i})
   
   if ~MANUAL_CRAWLING_MODE
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end
       conns = str2num(out);

       fname = sprintf('%s/%s-m-conns.csv.bz2', OUTPUT_DIR, sites{i});
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end
       connsM = str2num(out);

       fname = sprintf('%s/%s-loadtime.csv.bz2', OUTPUT_DIR, sites{i});
       [status, out] = system(sprintf('bzcat %s', fname));
       if status ~= 0
           fprintf('Skipping %s (incomplete) \n', sites{i});
           continue
       end

       % load times structure:
       % [timeConnect,timeDomLoad, timeDns, timeRedirect, timeResponse]

       loadtime = str2num(out);

       fname = sprintf('%s/%s-m-loadtime.csv.bz2', OUTPUT_DIR, sites{i});
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
       
       fname = sprintf('%s/%s-m-stap.csv.bz2', OUTPUT_DIR, sites{i});
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
   
   fname = sprintf('%s/%s-stap.csv.bz2', OUTPUT_DIR, sites{i});
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
numSites = length(sites);

toc
fprintf('Done!\n')

% link stap indices
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
end
save output

%% plot staps (single site)
siteIndex = 1;
stapID = 123;
display(sites{siteIndex});
display(stap_feature_names(stapID))
relevantStap = stapDataAggregated{siteIndex, stapID};

timestamps = relevantStap(:,1);
feature = relevantStap(:,end);
plot(timestamps,feature)

%% plot everything individually (all sites)
save_figs = true;
use_export_fig = false;
use_hgsave = true;
close all;
mkdir('figs-manual');
tic
for i=1:numSites
    sitename = sites(i);
    fprintf('[%d of %d] %s\n', i, length(sites), sites{i})
    mkdir(sprintf('figs-manual/%s',sitename{:}));
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
%        hold all
%        plot(stap_time_seriesM(:,1),stap_time_seriesM(:,2), ...
%            '--','Linewidth', 1, 'MarkerSize',4,'Color',[77 175 74]/255)
       box off
       ylabel(featureName{:})
       title(sprintf('%s -- %s', sitename{:}, cell2mat(strrep(featureName, '_', '\_'))))
       legend('Desktop UA' ,'Mobile UA')
       
       subplot(2,1,2)
       plot(stap_time_series(:,1),cumsum(stap_time_series(:,2)), ...
           'Linewidth', 1, 'MarkerSize',4, 'Color', [55 126 184]/255)
%        hold all
%        plot(stap_time_seriesM(:,1),cumsum(stap_time_seriesM(:,2)), ...
%            '--','Linewidth', 1, 'MarkerSize',4,'Color',[77 175 74]/255)
       box off
       ylabel('Cumulative sum')
       xlabel('Time (seconds)')
       legend('Desktop UA' ,'Mobile UA')
       
       if save_figs
           set(gcf,'PaperPositionMode','auto')
           if use_export_fig
                export_fig(sprintf('figs-manual/%s/%d.%s.png', ...
                   sitename{:}, j, featureName{:}), '-r300')
           else
               print(gcf,'-dpng','-r300', sprintf('figs-manual/%s/%d.%s.png', ...
                   sitename{:}, j, featureName{:}))
           end
           if  use_hgsave
               hgsave(sprintf('figs-manual/%s/%d.%s.fig', ...
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
close all

means = mean(squeeze(aggDat(:,119,:)/1024));
stds = std(squeeze(aggDat(:,119,:)/1024));
meansM = mean(squeeze(aggDatM(:,119,:)/1024));
stdsM = std(squeeze(aggDatM(:,119,:)/1024));

errorbar(1:BINS, means,stds, 'linewidth', 1)
hold all
errorbar(1:BINS, meansM,stdsM,'--', 'linewidth', 1)
box off
axis tight
title('Network Activity (Sent)')
ylabel('KB sent')
xlabel('Time bin (seconds * 5)')
legend('Desktop UA', 'Mobile UA')

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
conns = cell2mat(cellfun(@(c) c(1:600,2), allConns, 'uniformoutput', false));
connsM = cell2mat(cellfun(@(c) c(1:600,2), allConnsM, 'uniformoutput', false));

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
plot((1:600)/4.5,mean(conns, 2),'linewidth', 1)
hold all
plot((1:600)/4.5,mean(connsM, 2), '--', 'linewidth', 1)
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
set(gcf,'PaperPositionMode','auto')
print(gcf,'-dpng','-r300', 'all-conns-hist.png')
