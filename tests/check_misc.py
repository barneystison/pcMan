#!/usr/bin/env python3
import os, re, sys, glob, random
from codestyle import remove_comments_and_strings

def check_source_files():
    identifiers = []
    for pattern in "**/*.c", "**/*.h":
        for path in glob.glob(pattern, recursive=True):
            with open(path, encoding="utf-8") as f:
                code = f.read()

            code = remove_comments_and_strings(code)

            identifiers.extend(re.findall("[a-zA-Z_][a-zA-Z_0-9]*", code))

    if "struct" in identifiers:
        print('\tOK: The word "struct" was found. Hopefully it has been used in a sensible way.')
    else:
        print('\tERROR: No struct was used.')
        sys.exit(1)

    if "enum" in identifiers:
        print('\tOK: The word "enum" was found. Hopefully it has been used in a sensible way.')
    else:
        print('\tERROR: No enum was used.')
        sys.exit(1)

def check_tests():
    with open("Makefile", "r", encoding="utf-8") as f:
        lines = f.read().split("\n")

    if not any(line.startswith("mytests") for line in lines):
        print('\tERROR: "mytests:" missing from Makefile.')
        sys.exit(1)

    original_lines = list(lines)

    # Check missing comments
    for expected in ["# Test 2:", "# Test 1:"]:
        if not any(expected in line for line in lines):
            print(f'\tWARNING: "{expected}" missing from Makefile. Line has been inserted automatically. Please double-check if you have described (briefely) what you are testing.')
            for i, line in enumerate(lines):
                if line.startswith("mytests"):
                    lines.insert(i + 1, "\t" + expected)

    # Only check once
    lines = [line + "".join(random.choice(" \t") for _ in range(80))
        if line.lstrip()[:1] == "#" and line.rstrip() == line else line
        for line in lines]

    if lines != original_lines:
        with open("Makefile", "w", encoding="utf-8") as f:
            f.write("\n".join(lines))

def main():
    print("INFO: Testing various things.\n")

    check_source_files()
    check_tests()

    print()

if __name__ == "__main__":
    main()

