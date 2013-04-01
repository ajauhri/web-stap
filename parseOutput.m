%% do parsing
clear all; close all;
files = dir('output');
sites = [];

for i=3:length(files)
    sites = [sites {strtok(files(i).name,'-')}];
end

sites = unique(sites);
allConns = [];
allConnsM = [];
allLoadtimes = [];
allLoadtimesM = [];

for i=1:length(sites)
   fname = sprintf('output/%s-conns.csv.bz2', sites{i});
   if ~exist(fname, 'file')
       fprintf('Skipping %s\n', sites{i});
       continue
   end
   fprintf('[%d of %d] %s\n', i, length(sites), sites{i})
   
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
   
   if length(conns) < 250 || length(connsM) < 250
       fprintf('Skipping %s\n', sites{i});
      continue 
   end
   allConns = [allConns conns(1:250)];
   allConnsM = [allConnsM connsM(1:250)];
   allLoadtimes = [allLoadtimes; loadtime];
   allLoadtimesM = [allLoadtimesM; loadtimeM];
end

%% plot results
plot(allConns)
legend(sites)

%%
subplot(2,1,1)
boxplot(allConns')
ylabel('Connections')
title('Desktop UA')
subplot(2,1,2)
boxplot(allConnsM')
ylabel('Connections')
title('Mobile UA')

%% means
plot(mean(allConns, 2), 'b')
hold all
plot(mean(allConnsM, 2), 'b--')
legend('Desktop UA', 'Mobile UA')

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
imagesc(allConns)
ylabel('Time')
title('Desktop UA')
subplot(2,1,2)
imagesc(allConnsM)
ylabel('Time')
title('Mobile UA')

%%
set(gcf,'PaperPositionMode','auto')
print(gcf,'-dpng','-r300', 'out.png')
