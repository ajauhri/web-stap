#!/usr/bin/env python
import sys
from os import listdir, system
from os.path import isfile

def main():
    dir_path = "./output/"

    # script to create syscalls made by firefox only
    #system("./stap-syscalls-pruner-helper")
    files = [dir_path+f for f in listdir(dir_path) if isfile(dir_path+f) and "stap-syscalls.csv.bz2.tmp" in f]
    if len(files) == 0:
        raise Exception('No files found for parsing')
    for fname in files:
        try:
            with open(fname) as f:
                lines = f.readlines()
                d = dict()
                for line in lines:
                    cols = line.split('|')
                    d[cols[1]] = d.get(cols[1], 0) + int(cols[2])
            fname = fname.split('bz2', 1)[0] + 'pruned' 
            
            f = open(fname, 'w')
            for k,v in d.iteritems():
                f.write(k+','+str(v)+',\n')
            f.close()
            
            print fname
            system('bzip2 ' + fname)
            system('rm ' + fname.split('pruned', 1)[0] + 'bz2.tmp')
        except:
            raise Exception('Something went wrong with ' + fname)

main()
