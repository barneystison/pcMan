# 你可以向这个文件添加规则，但你不能删除它们。
CFLAGS_FSANITIZE := -g -std=c99 -Wall -Wextra -Werror -Werror=vla -Og -Wmissing-prototypes -fsanitize=address -fsanitize=undefined
CFLAGS_VALGRIND  := -g -std=c99 -Wall -Wextra -Werror -Werror=vla -Og -Wmissing-prototypes

# 其他文件可以添加到这里，例如
# SOURCES := pacman.c ghost.c 或 HEADERS := pacman.h ghost.h
SOURCES := pacman.c
HEADERS := pacman.h

run: test_output test_arguments codestyle checksums misc mytests

pacman_fsanitize: $(SOURCES) $(HEADERS)
	gcc $(CFLAGS_FSANITIZE) $(SOURCES) -o pacman_fsanitize

pacman_valgrind: $(SOURCES) $(HEADERS)
	gcc $(CFLAGS_VALGRIND) $(SOURCES) -o pacman_valgrind

test_output: pacman_fsanitize
	tests/test_output.sh

test: tests/test.sh
	tests/test.sh

test_arguments_fsanitize: pacman_fsanitize
	tests/test_arguments.sh fsanitize

test_arguments_valgrind: pacman_valgrind
	tests/test_arguments.sh valgrind

test_arguments: test_arguments_fsanitize test_arguments_valgrind

misc:
	tests/check_misc.py

codestyle:
	tests/codestyle.py

checksums:
	tests/check_checksums.sh

mytests:
	# 你必须创建你自己的测试。你必须至少测试2个或
	# 测试更多的 "东西"，你可以自己选择。
	# 创建编译和运行测试的规则。
	# 简要描述一下你在这里测试的内容。
	# 测试1。
	#（例子）我在测试吃豆人是否不能穿墙。
	# 测试2。
	# ...
	./error 你还没有做自己的测试
