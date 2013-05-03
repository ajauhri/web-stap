%% do parsing
clear all; close all;
PARSE_SYSCALLS = true;
TIMESTAMP_INDEX = 2;

files = dir('output');
sites = [];

for i=3:length(files)
    sites = [sites {strtok(files(i).name,'-')}];
end

sites = unique(sites);
sites = fliplr(sites);
allConns = [];
allConnsM = [];
allLoadtimes = [];
allLoadtimesM = [];
allStaps = [];
allStapsM = [];

for i=length(sites):-1:1
   fname = sprintf('output/%s-conns.csv.bz2', sites{i});
   fprintf('[%d of %d] %s\n', length(sites) - i + 1, ...
       length(sites), sites{i})
   
   [status, out] = system(sprintf('bzcat %s', fname));
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   conns = str2num(out);
   
   fname = sprintf('output/%s-m-conns.csv.bz2', sites{i});
   [status, out] = system(sprintf('bzcat %s', fname));
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   connsM = str2num(out);
   
   fname = sprintf('output/%s-loadtime.csv.bz2', sites{i});
   [status, out] = system(sprintf('bzcat %s', fname));
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   
   % load times structure:
   % [timeConnect,timeDomLoad, timeDns, timeRedirect, timeResponse]
   
   loadtime = str2num(out);
   
   fname = sprintf('output/%s-m-loadtime.csv.bz2', sites{i});
   [status, out] = system(sprintf('bzcat %s', fname));
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   loadtimeM = str2num(out);
   
   % if dom never loaded, or if page loaded abnormally fast...
   if loadtime(2) < 0 || loadtimeM(2) < 0 || ... 
           loadtime(1) <= 0 || loadtimeM(1) <= 0
       fprintf('Skipping %s (no page load) \n', sites{i});
       sites(i) = [];
       continue
   end
   
   fname = sprintf('output/%s-stap.csv.bz2', sites{i});
   if PARSE_SYSCALLS
       cmd = sprintf( 'bash parseStapSyscalls.sh %s', fname);
   else
       cmd = sprintf( 'bash parseStapAll.sh %s', fname);
   end
   [status, out] = system(cmd);
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   staps = importdata('.tmp');
   
   fname = sprintf('output/%s-m-stap.csv.bz2', sites{i});
   if PARSE_SYSCALLS
       cmd = sprintf( 'bash parseStapSyscalls.sh %s', fname);
   else
       cmd = sprintf( 'bash parseStapAll.sh %s', fname);
   end
   [status, out] = system(cmd);
   if status ~= 0
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   stapsM = importdata('.tmp');
   
   if length(conns) < 250 || length(connsM) < 250 || isempty(staps) || isempty(stapsM)
       fprintf('Skipping %s (odd output)\n', sites{i});
       sites(i) = [];
      continue 
   end
   
   startTime = conns(1,1);
   conns(:,1) = conns(:,1) - startTime;
   startTime = connsM(1,1);
   connsM(:,1) = connsM(:,1) - startTime;
   startTime = min(staps(:,TIMESTAMP_INDEX));
   staps(:,TIMESTAMP_INDEX) = staps(:,TIMESTAMP_INDEX) - startTime;
   startTime = min(stapsM(:,TIMESTAMP_INDEX));
   stapsM(:,TIMESTAMP_INDEX) = stapsM(:,TIMESTAMP_INDEX) - startTime;
   
   % ensure we're actually looking at time
   assert(~any(staps(:,TIMESTAMP_INDEX) > 1000))
   assert(~any(stapsM(:,TIMESTAMP_INDEX) > 1000))
   
   allConns = [allConns; {conns}];
   allConnsM = [allConnsM; {connsM}];
   allLoadtimes = [allLoadtimes; loadtime];
   allLoadtimesM = [allLoadtimesM; loadtimeM];
   allStaps = [allStaps; {staps}];
   allStapsM = [allStapsM; {stapsM}];
end
save parsed

%% link stap indices; remove empty sites
if PARSE_SYSCALLS
    load syscallNames
    stap_feature_names = syscallNames;
else
    load stap_dim
    stap_feature_names = stap_dim;
end
assert(size(stap_feature_names,2) == 1)
stapTypes = length(stap_feature_names);
numSites = length(allStaps);

stapDataAggregated = cell(numSites, stapTypes);
stapDataAggregatedM = cell(numSites, stapTypes);

for i=1:numSites
    staps = allStaps{i};
    for j=1:stapTypes
       relevantStaps = staps(staps(:,1) == j, 2);
       stapDataAggregated{i,j} = relevantStaps;
       
       relevantStapsM = stapsM(stapsM(:,1) == j, 2);
       stapDataAggregatedM{i,j} = relevantStapsM;
    end
end

%% plot staps (single site)
siteIndex = 1;

% for TCP download stap
stapID = 16;
display(sites(length(sites) - siteIndex + 1));
relevantStap = stapDataAggregated{siteIndex, stapID};

timestamps = relevantStap(:,2);
bytesRec = relevantStap(:,end);
bytesSent = relevantStap(:,end-1);
plot(cumsum(bytesRec))

%% plot staps (all sites)
save_figs = true;
close all;
mkdir('figs');
for i=1:1
    sitename = sites(length(sites) - i + 1);
    mkdir(sprintf('figs/%s',sitename{:}));
    for j=1:stapTypes
       relevantStap = stapDataAggregated{i, j};
       relevantStapM = stapDataAggregatedM{i, j};
       % [process_name, PID, timestep, ...]
       timestamps = relevantStap(:,3);
       timestampsM = relevantStapM(:,3);

       for k=4:length(stap_feature_names{j})
           feature_names = stap_feature_names{j};
           stap_time_series = sortrows([timestamps relevantStap(:,k)]);
           stap_time_seriesM = sortrows([timestampsM relevantStapM(:,k)]);
           subplot(2,1,1)
           plot(stap_time_series(:,1),stap_time_series(:,2), ...
               'Linewidth', 1, 'MarkerSize',4, 'Color', [55 126 184]/255)
           hold all
           plot(stap_time_seriesM(:,1),stap_time_seriesM(:,2), ...
               '--','Linewidth', 1, 'MarkerSize',4,'Color',[77 175 74]/255)
           box off
           ylabel(feature_names{k})
           title(sprintf('%s -- %s', sitename{:}, feature_names{k}))
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
               print(gcf,'-dpng','-r300', sprintf('figs/%s/%d.%s.png', ...
                   sitename{:}, j, feature_names{k}))
           end
%            pause
           clf('reset') 
       end
    end
end
close all

%% calculate aggregates
DURATION = 150; % seconds
BINS = 30;

binduration = DURATION / BINS;
aggDat = zeros(numSites, sum(cellfun(@length,stap_feature_names)), BINS);
aggDatM = zeros(numSites, sum(cellfun(@length,stap_feature_names)), BINS);

for i=1:numSites
    fprintf('[%d of %d]\n', i, numSites)
    stapIndex = 1;
    for j=1:stapTypes
        relevantStap = stapDataAggregated{i, j};
        relevantStapM = stapDataAggregatedM{i, j};
        timestamps = relevantStap(:,3);
        timestampsM = relevantStapM(:,3);
        
        for k=1:length(stap_feature_names{j})
            stapIndex = stapIndex + 1;
            stap_time_series = sortrows([timestamps relevantStap(:,k)]);
            stap_time_seriesM = sortrows([timestampsM relevantStapM(:,k)]);
            for b=1:BINS
                binDat = stap_time_series(binduration * (b-1) <= stap_time_series(:,1) & ...
                    stap_time_series(:,1) < (binduration * b), 2);
                aggDat(i, stapIndex, b) = sum(binDat);
                
                binDatM = stap_time_seriesM(binduration * (b-1) <= stap_time_seriesM(:,1) & ...
                    stap_time_seriesM(:,1) < (binduration * b), 2);
                aggDatM(i, stapIndex, b) = sum(binDatM);
            end
        end
    end
end
fprintf('Done!')

%% plot aggregates
mkdir('figs-aggregate')
save_figs = true;
stapIndex = 1;
for j=1:stapTypes
    for k=1:length(stap_feature_names{j})
        stapIndex = stapIndex + 1;
        feature_name = stap_feature_names{j}{k};

        boxplot(squeeze(aggDat(:,stapIndex,:)))
        title(sprintf('%d -- %s', j, feature_name))

        if save_figs
            set(gcf,'PaperPositionMode','auto');
            print(gcf,'-dpng','-r300', sprintf('figs-aggregate/%d-%s.png', ...
                j, feature_name))
        end
        clf('reset')
    end
end
close all

%% plot results [OLD]
plot(allConns)
legend(sites)

%% boxplots
subplot(2,1,1)
boxplot(allConns')
ylabel('Connections')
title('Desktop UA')
subplot(2,1,2)
boxplot(allConnsM')
ylabel('Connections')
title('Mobile UA')

%% means
plot((1:250)/2,mean(allConns, 2), 'b')
hold all
plot((1:250)/2,mean(allConnsM, 2), 'b--')
legend('Desktop UA', 'Mobile UA')
ylabel('Mean connections')
xlabel('Time (seconds)')

%% barplot
bar([mean(allConns); mean(allConnsM)]')
ylabel('Mean connections')
xlabel('Site index')

%% histogram
subplot(2,1,1)
hist([mean(allConns)' mean(allConnsM)'], 20)
legend('Desktop UA', 'Mobile UA')
xlabel('Mean connections')
subplot(2,1,2)
hist([max(allConns)' max(allConnsM)'], 20)
legend('Desktop UA', 'Mobile UA')
xlabel('Peak connections')

%% image-style
subplot(2,1,1)
imagesc(allConns, [0 50])
ylabel('Time')
title('Desktop UA')
subplot(2,1,2)
imagesc(allConnsM, [0 50])
ylabel('Time')
title('Mobile UA')
%% single site
plot((1:250)/2, allConns(:,15))
hold all
plot((1:250)/2, allConnsM(:,15),'--')
legend('Desktop UA', 'Mobile UA')
ylabel('Number of Connections')
xlabel('Time (seconds)')

%%
set(gcf,'PaperPositionMode','auto')
print(gcf,'-dpng','-r300', 'out.png')
