bzcat $1 | grep -v 'browser:' | \
    sed  -e 's/JS Sour~ Thread/Sour Thread/g' \
    -e 's/Proxy R~olution/Proxy Rolution/g' \
    -e 's/[^0-9~]*//g' -e 's/~/,/g' -e 's/,,/,-1,/g' -e 's/,$//' \
    > .tmp