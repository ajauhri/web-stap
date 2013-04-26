%% do parsing
clear all; close all;

DURATION = 150; % seconds
BINS = 30;

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
   if ~exist(fname, 'file')
       fprintf('Skipping %s (incomplete) \n', sites{i});
       sites(i) = [];
       continue
   end
   fprintf('[%d of %d] %s\n', length(sites) - i + 1, ...
       length(sites), sites{i})
   
   [status, out] = system(sprintf('bzcat %s', fname));
   assert(status == 0);
   conns = str2num(out);
   
   fname = sprintf('output/%s-m-conns.csv.bz2', sites{i});
   [status, out] = system(sprintf('bzcat %s', fname));
   assert(status == 0);
   connsM = str2num(out);
   
   fname = sprintf('output/%s-loadtime.csv.bz2', sites{i});
   [status, out] = system(sprintf('bzcat %s', fname));
   assert(status == 0);
   loadtime = str2num(out);
   
   fname = sprintf('output/%s-m-loadtime.csv.bz2', sites{i});
   [status, out] = system(sprintf('bzcat %s', fname));
   assert(status == 0);
   loadtimeM = str2num(out);
   
   fname = sprintf('output/%s-stap.csv.bz2', sites{i});
   cmd = sprintf( ...
       ['bash -c "bzcat %s | grep -v ''browser:''' ...
       ' | sed -e ''s/[^0-9~]*//g'' -e ''s/~/,/g''' ...
       ' -e ''s/,,/,-1,/g'' -e ''s/,$//'' > .tmp"'], fname)
   [status, out] = system(cmd);
   assert(status == 0);
   staps = importdata('.tmp');
   
   fname = sprintf('output/%s-m-stap.csv.bz2', sites{i});
   [status, out] = system(sprintf( ...
       ['bash -c "bzcat %s | grep -v ''browser:''' ...
       ' | sed -e ''s/[^0-9~]*//g'' -e ''s/~/,/g''' ...
       ' -e ''s/,,/,-1,/g'' -e ''s/,$//''  > .tmp"'], fname));
   assert(status == 0);
   stapsM = importdata('.tmp');
   
   if length(conns) < 250 || length(connsM) < 250
       fprintf('Skipping %s (not enough timesteps) \n', sites{i});
       sites(i) = [];
      continue 
   end
   
   startTime = conns(1,1);
   conns(:,1) = conns(:,1) - startTime;
   startTime = connsM(1,1);
   connsM(:,1) = connsM(:,1) - startTime;
   
   allConns = [allConns; {conns}];
   allConnsM = [allConnsM; {connsM}];
   allLoadtimes = [allLoadtimes; loadtime];
   allLoadtimesM = [allLoadtimesM; loadtimeM];
   allStaps = [allStaps; {staps}];
   allStapsM = [allStapsM; {stapsM}];
end

%% plot results
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
