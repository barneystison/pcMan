#!/usr/bin/env bash

printf '\n\tINFO: Checking if files have been modified.\n\n'

if sha256sum -c 'tests/checksums.txt'
then
    printf '\n\tOK: Files have not been modified.\n\n'
else
    printf '\tERROR: One or more files have been modified which you were not allowed to modify.\n'
    exit 1
fi
