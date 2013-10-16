#!/bin/bash
# stap_output_sanitize
for i in ./output/*
do
    if (echo $i | grep stap.csv.bz2); then
        bzcat $i | awk -F'~' -v OFS='~' '{for(i=NF;i<=8;i++) {$i="0"} print $0}' > $i.corrected
        bzip2 $i.corrected
        rm $i
    fi
done

#---------------------------------#
# stap_syscalls_pruner_helper
#!/bin/bash
for i in ./output/*
do
    if (echo $i | grep stap.csv.bz2); then
        bzcat $i | awk -F'~' -v OFS='~' '{for(i=NF;i<=8;i++) {$i="0"} print $0}' > $i.corrected
        bzcat $i.corrected
        rm $i
    fi
done


