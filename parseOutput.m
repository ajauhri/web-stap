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
   
   % get syscall types:
   % bzcat output/google.com-stap-syscalls.csv.bz2 | grep -i firefox  | sed -e 's/
% \s\+/ /g' | cut -d' ' -f5 | sort | uniq
   
%    bzcat output/google.com-stap-packets.csv.bz2 | sed -e 's/\s\+/ /g' | sed 's/[
% ^0-9][a-zA-Z] [a-zA-Z]//g' | sed 's/ #//g' | cut -d' ' -f7,8,10
   % for parsing syscalls
   % bzcat output/google.com-stap-syscalls.csv.bz2 | grep -i firefox | grep
   % futex | sed -e 's/\s\+/ /g' | cut -d' ' -f 4,6
   
   allConns = [allConns conns(1:250)];
   allConnsM = [allConnsM connsM(1:250)];
   allLoadtimes = [allLoadtimes; loadtime];
   allLoadtimesM = [allLoadtimesM; loadtimeM];
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
