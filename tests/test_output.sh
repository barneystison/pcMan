#!/usr/bin/env bash

rm -rf output testlevel
mkdir -p output testlevel

printf 'INFO: Testing ghosts on 100 levels.\n\n'

for i in {1..100}
do
    input="input/$i.txt"
    output="output/$i.txt"
    
    # Generating random level name to dissuade testing of filenames instead of doing things correctly
    level="testlevel/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
    cp "level/$i.txt" "$level"

    printf 'INFO: Computing %s for %s with %s\n' "$output" "$level" "$input"

    # Limit stack size to make incorrect stack usage more obvious
    if ! ulimit -Ss 32
    then
        printf 'ERROR: The program "ulimit" does not appear to work on your computer..\n'
        exit 1
    fi

    cat "$input" | ./pacman_fsanitize "$level" > "$output"

    return_value="$?"

    # Reset stack size limit to default (probably 8192k)
    ulimit -Ss unlimited

    if [ "$return_value" -ne 0 ]
    then
        printf 'ERROR: Program failed. The return value was %s instead of 0.\n' "$return_value"
        exit 1
    fi

    if ! tests/check_output.py "$output" "$level"
    then
        exit 1
    fi
done

if ! tests/check_output.py
then
    exit 1
fi

printf 'INFO: Cleanup (removing output and testlevel directories)\n'

rm -rf output testlevel
