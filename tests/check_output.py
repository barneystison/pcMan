#!/usr/bin/env python3
import os, re, sys, string

def check_output(output_path, level_path):
    def find_coordinates(level, chars="PIBYC"):
        for y, line in enumerate(level):
            for x, char in enumerate(line):
                if char in chars:
                    yield (x, y), char

    try:
        with open(level_path) as f:
            level_lines = [line for line in f if line.strip()]
            wall_coordinates = dict(find_coordinates(level_lines, "W"))
    except FileNotFoundError:
        print(f"ERROR: {level_path} not found.")
        sys.exit(1)

    if not wall_coordinates:
        print(f"ERROR: No wall in {level_path}.")
        sys.exit(1)

    y_min = min(y for x, y in wall_coordinates)
    y_max = max(y for x, y in wall_coordinates)
    level_height = y_max - y_min + 1

    def is_level(lines):
        # Checks if lines corresponds to a level by comparing wall coordinates
        return "".join(lines).count("W") == len(wall_coordinates) and all(
            (x, y + y_min) in wall_coordinates
            for (x, y), _ in find_coordinates(lines, "W"))

    neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1), (0, 0)]
    
    try:
        filesize = os.path.getsize(output_path)

        if filesize > 10e6:
            print(f"ERROR: File {output_path} too large ({filesize * 1e-6:.2f} MB)")
            sys.exit(1)

        with open(output_path, "rb") as f:
            data = f.read()

        # Check if file contains funny characters
        try:
            lines = data.decode("utf-8").split("\n")
        except UnicodeDecodeError:
            print(f"ERROR: Output contains non-utf8 characters. Maybe you printed uninitialized memory?")
            sys.exit(1)
        
        for line_number, line in enumerate(lines, 1):
            for c in line:
                if c not in string.printable:
                    print(f"ERROR: Output contains non-printable character with ASCII code {hex(ord(c))} in line {line_number}.")
                    sys.exit(1)
        
        # Remove comments
        lines = [line for line in lines if not line.lstrip().startswith("//")]

        # Parse single steps from output
        i = 0
        levels = []
        not_level = []
        while i < len(lines):
            if is_level(lines[i:i + level_height]):
                levels.append(lines[i:i + level_height])
                i += level_height
            else:
                line = lines[i].rstrip()
                not_level.append(line)
                i += 1

        # Complain if no level could be parsed (probably malformed or no output)
        if not levels:
            print(f"ERROR: Could not find level in {output_path}.")
            sys.exit(1)

        # Complain if too much garbage in output
        if sum(len(line.strip()) > 0 for line in not_level) > 2:
            print(re.sub("\n+", "\n", "\n".join(not_level)))
            print(f"\nERROR: There are many lines in {output_path} which do not match {level_path}. Maybe someone accidentally ate a wall?\n")
            sys.exit(1)
        
        # Check if first output is level
        actual_step0 = "\n".join(line.rstrip() for line in levels[0])
        expected_step0 = "\n".join(line.rstrip() for line in level_lines)
        if actual_step0 != expected_step0:
            print(f"\nFirst step of {output_path}:\n")
            print(actual_step0)
            print(f"\nShould be {level_path}:\n")
            print(expected_step0)
            print(f"\nERROR: First step of {output_path} should be the same as {level_path}.")
            sys.exit(1)

        # Complain if Pac-Man vanishes prematurely
        for step, level in enumerate(levels[:-1]):
            if not any("P" in line for line in level):
                print("\n".join(level))
                print(f"\nERROR: No Pac-Man in output for step {step}.")
                sys.exit(1)

        # Check for teleporting characters which move further than 1 field
        # between steps
        for step, (prev_level, level) in enumerate(zip(levels[:-1], levels[1:])):
            coordinates = dict(find_coordinates(prev_level))

            for (x, y), char in find_coordinates(level):
                if not any((x + dx, y + dy) in coordinates for dx, dy in neighbors):
                    print(f"Step {step}:\n")
                    print("\n".join(prev_level))
                    print(f"\nStep {step + 1}:\n")
                    print("\n".join(level))
                    print(f"\nERROR: There is a {char} in step {step + 1}, but there is no place in the previous step {step} where it could have come from.")
                    sys.exit(1)

        # Check if ghosts vanished
        for step, level in enumerate(levels):
            if not any(set("IBYC") & set(line) for line in level):
                print("\n".join(level))
                print(f"\nERROR: No ghosts in step {step}:\n")
                sys.exit(1)

        if any("P" in line for line in levels[-1]):
            print(f"INFO: Pac-Man has not been eaten in {output_path} for {level_path} (Pac-Man is visible in last output step).")
            return -1
        
        # If Pac-Man has been eaten, there must have been a previous step
        # where Pac-Man has not been eaten yet
        if len(levels) < 2:
            print(f"ERROR: No Pac-Man in first output of {output_path}.")
            sys.exit(1)
        
        # Pac-Man has been eaten. Check if there is a ghost now.
        coordinates = dict(find_coordinates(levels[-1]))
        for (x, y), char in find_coordinates(levels[-2]):
            if char == "P" and not any(
                coordinates.get((x + dx, y + dy), "") in "IBPC"
                for dx, dy in neighbors + [(0, 0)]
            ):
                print(f"Second-to-last step {step}:\n")
                print("\n".join(levels[-2]))
                print(f"\nLast step {step + 1}:\n")
                print("\n".join(levels[-1]))
                print(f"ERROR: No Pac-Man in last step of {output_path} but also no ghost nearby.")
                sys.exit(1)

        print(f"INFO: Pac-Man has been eaten after {len(levels) - 1:3d} step{'s' if len(levels) > 2 else ' '} in {output_path}.")

        # Return number of steps
        return len(levels)

    except FileNotFoundError:
        print(f"ERROR: File {output_path} not found")
        sys.exit(1)

def main():
    if len(sys.argv) == 3:
        output_path, level_path = sys.argv[1:]

        num_steps = check_output(output_path, level_path)
    else:
        steps = []
        total_steps = 0
        for i in range(1, 101):
            output_path = f"output/{i}.txt"
            level_path = f"level/{i}.txt"

            num_steps = check_output(output_path, level_path)
            if num_steps > 0:
                steps.append(num_steps)

        print(f"\nINFO: Pacman has been eaten {len(steps)} times.")
        
        win_threshold = 75

        if len(steps) < win_threshold:
            print(f"ERROR: The ghosts are too stupid. They should eat Pac-Man at least {win_threshold} times.")
            sys.exit(1)
        else:
            print(f"\nOK: Pac-Man has been eaten more than {win_threshold} times.\n")

if __name__ == "__main__":
    main()
