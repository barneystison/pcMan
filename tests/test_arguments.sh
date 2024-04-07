#!/usr/bin/env bash

mode="$1"

if [ "$mode" = 'fsanitize' ]; then
    printf 'INFO: Testing with %s.\n' "$mode"
elif [ "$mode" = 'valgrind' ]; then
    printf 'INFO: Testing with %s.\n' "$mode"
else
    printf 'ERROR: Must either test with fsanitize or valgrind, but not with "%s".\n' "$mode"
    exit 1
fi

if ! rm -rf output testlevel testinput
then
    printf 'ERROR: Could not clean up output and testlevel directories.\n'
    exit 1
fi

mkdir -p output testlevel testinput

function test_args(){
    expected_error_code="$1"
    input="$2"
    output="$3"
    levels="${@:4}"
    error='output/error.txt'
    logfile='output/valgrind.txt'
    
    if [ "$mode" = 'fsanitize' ]
    then
        # Limit stack size to make incorrect stack usage more obvious
        if ! ulimit -Ss 32
        then
            printf 'ERROR: The program "ulimit" does not appear to work on your computer..\n'
            exit 1
        fi

        printf '\nRunning command:\n\n'
        echo "    cat $input | ./pacman_fsanitize $levels > $output 2> $error"
        printf '\n'
        
        cat "$input" | ./pacman_fsanitize $levels > "$output" 2> "$error"
        return_value=$?
        
        # Reset stack size limit to default (probably 8192k)
        ulimit -Ss unlimited
    else
        # mode = valgrind
        rm -f "$logfile"
        
        printf '\nRunning command:\n\n'
        echo "    cat $input | valgrind --error-exitcode=50 --leak-check=full --show-leak-kinds=all --track-origins=yes --log-file=$logfile ./pacman_valgrind $levels > $output 2> $error"
        printf '\n'
        
        cat "$input" | valgrind --error-exitcode=50 --leak-check=full --show-leak-kinds=all --track-origins=yes --log-file="$logfile" ./pacman_valgrind $levels > "$output" 2> "$error"
        
        return_value=$?
        
        if [ $return_value -eq 50 ]
        then
            printf 'ERROR: valgrind has detected a problem:\n\n'
            cat "$logfile"
            exit 1
        fi
    fi
        
    errorsize=$(cat output/error.txt | wc -c)

    if [ $errorsize -ne 0 ]
    then
        printf 'INFO: Something has been printed to stderr:\n\n'
        cat "$error"
    fi

    if [ $return_value -eq "$expected_error_code" ]
    then
        printf '\tOK: Return value is %s as expected.\n' "$expected_error_code"
    else
        printf '\tERROR: Return value is not %s, but %s.\n\n' "$expected_error_code" "$return_value"
        exit 1
    fi
    
    if [ $return_value -eq 0 ]
    then
        if [ $errorsize -ne 0 ]
        then
            printf 'ERROR: Something has been printed to stderr, which indicates an error, but the return value was 0, which indicates no error.\n'
            exit 1
        fi
    else
        if [ $errorsize -eq 0 ]
        then
            printf 'ERROR: The correct error code has been returned, but no error message has been printed to stderr.\n'
            exit 1
        fi

        if [ $errorsize -lt 20 ]
        then
            printf 'ERROR: The correct error code has been returned, but the error message is too short. Remember that error messages should be meaningful.\n'
            exit 1
        fi
    fi
}

test_args '0' 'input/quit.txt' 'output/test1.txt' 'level/2.txt'
outputsize=$(cat output/test1.txt | wc -c)
levelsize=$(cat level/2.txt | wc -c)
if [ "$levelsize" -ge "$outputsize" ]
then
    printf '\tERROR: The initial level should always be printed to standard output, but the output is smaller than the level file.\n'
    exit 1
fi


test_args '0' 'input/wasdquit.txt' 'output/test2.txt' 'level/2.txt'
test_args '0' 'input/w_a_s_d_quit.txt' 'output/test3.txt' 'level/2.txt'
if diff -q 'output/test2.txt' 'output/test3.txt'
then
    printf '\tOK: Output is the same when entered character by character or line by line.\n\n'
else
    printf '\tERROR: Output is different when commands are entered character by character instead of line by line ("wasdq\\n" vs "w\\na\\s\\n\\d\\nq\\n").\n'
    exit 1
fi

printf 'INFO: Testing large levels which are easy to win (remember to end the game when all points have been consumed).\n'

test_args '0' 'input/ddddd.txt' 'output/wide.txt' 'level/wide.txt'
test_args '0' 'input/aaaaa.txt' 'output/full.txt' 'level/full.txt'
test_args '0' 'input/ww.txt' 'output/tall.txt' 'level/tall.txt'

printf 'INFO: Testing levels with too many or too few Pac-Mans.\n'

test_args '41' 'input/quit.txt' 'output/nopacman.txt' 'level/nopacman.txt'
test_args '41' 'input/quit.txt' 'output/2pacman.txt' 'level/2pacman.txt'

printf '\nINFO: Testing long level name\n\n'

level="testlevel/This_is_a_relatively_long_level_name.Please_note_that_level_paths_could_be_very_long_and_could_contain_funny_characters"

cp 'level/easy.txt' "$level"

test_args '0' 'input/ddddd.txt' 'output/long_level_name.txt' "$level"

level="testlevel/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"

printf '\nINFO: Testing level which does not exist.\n\n'

test_args '39' 'input/quit.txt' 'output/leveldoesnotexist.txt' "$level"

printf '\nINFO: Testing level which can not be read (fopen should succeed, but functions to read that file should fail).\n\n'

level="testlevel/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
mkdir -p "$level"

test_args '40' 'input/quit.txt' 'output/levelcannotberead.txt' "$level"

printf '\nINFO: Testing level which can not be read (fopen should succeed, but functions to read that file should fail).\n\n'

test_args '40' 'input/quit.txt' 'output/levelcannotberead_proc_self_mem.txt' '/proc/self/mem'

printf '\nINFO: Testing level without read permissions (fopen should fail). This test will not work if you are using WSL (incorrectly) or if you messed up your file permissions in a different way.\n\n'

level="testlevel/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
cp 'level/1.txt' "$level"
chmod a-r "$level"

test_args '39' 'input/quit.txt' 'output/levelcannotbeopenedforreading.txt' "$level"

printf '\nINFO: Testing level which can not be written to (this is fine).\n\n'

level="testlevel/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
cp 'level/1.txt' "$level"
chmod a-w "$level"

test_args '0' 'input/quit.txt' 'output/levelcannotbewritten.txt' "$level"

printf '\nINFO: Testing input from different directory.\n\n'

input="testinput/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
cp 'input/quit.txt' "$input"

test_args '0' "$input" 'output/inputfromdifferentdir.txt' 'level/2.txt'

printf '\nINFO: Testing empty level\n\n'

level="testlevel/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
touch "$level"

test_args '41' 'input/quit.txt' 'output/emptylevel.txt' "$level"

printf '\nINFO: Testing input which is too short to win this level.\n\n'

test_args '41' 'input/empty.txt' 'output/inputtooshort.txt' "level/2.txt"

printf '\nINFO: Testing input which is too short to win this level.\n\n'

test_args '41' 'input/w.txt' 'output/inputtooshort.txt' "level/2.txt"

printf '\nINFO: Testing input which can not be read.\n\n'

printf 'Running command:\n\n'

input="testinput/$(hexdump -n 10 -e '"%02x"' /dev/urandom).txt"
mkdir -p "$input"

printf '    ./pacman_fsanitize level/2.txt < %s > output/cantreadinput.txt\n\n' "$input"

expected_error_code=40

./pacman_fsanitize level/2.txt < "$input" > output/cantreadinput.txt

return_value=$?

if [ $return_value -eq "$expected_error_code" ]
then
    printf '\tOK: Return value is %s as expected.\n' "$expected_error_code"
else
    printf '\tERROR: Return value is not %s, but %s.\n\n' "$expected_error_code" "$return_value"
    exit 1
fi

input='input/ddddd.txt'
level='level/easy.txt'

test_args '0' "$input" 'output/easy1.txt' "$level"
test_args '0' "$input" 'output/easy2.txt' "$level" "$level"

size_easy1=$(cat output/easy1.txt | wc -c)
size_easy2=$(cat output/easy2.txt | wc -c)
if [ "$size_easy1" -ge "$size_easy2" ]
then
    printf '\tERROR: Output for playing %s with %s twice in a row should be larger than when playing the level just once.\n' "$level" "$input"
    exit 1
else
    printf '\tOK: Output for playing %s with %s twice in a row is larger than when playing the level just once.\n' "$level" "$input"
fi

printf '\nINFO: Cleanup (removing output and testlevel directories)\n'

rm -rf output testlevel testinput
