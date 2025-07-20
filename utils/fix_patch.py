#!/usr/bin/env python3.11
import sys
import re

def fix_patch_file(file_path):
    """
    Reads a patch file containing one or more file diffs, recounts lines in
    each hunk, and prints the corrected patch.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: File not found at {file_path}", file=sys.stderr)
        return

    hunk_header_re = re.compile(r'^@@ -(\d+)(,\d+)? \+(\d+)(,\d+)? @@.*')
    hunk_lines = []
    current_hunk_header = None

    def process_hunk():
        """Processes the currently buffered hunk, prints it, and resets."""
        nonlocal current_hunk_header, hunk_lines
        if not current_hunk_header:
            return

        # Recount lines
        original_len = sum(1 for line in hunk_lines if line.startswith((' ', '-')))
        modified_len = sum(1 for line in hunk_lines if line.startswith((' ', '+')))

        # Get start lines from the original header
        match = hunk_header_re.match(current_hunk_header)
        start_orig = match.group(1)
        start_mod = match.group(3)

        # Format new header
        # Handle cases where count is 1 (e.g., @@ -1 +1,2 @@)
        # A line count of 0 is also possible for empty files or full deletions
        orig_count_str = f",{original_len}" if original_len != 1 else ""
        mod_count_str = f",{modified_len}" if modified_len != 1 else ""
        
        # Special case: if a file is completely empty after changes, its line count is 0.
        if original_len == 0:
            orig_count_str = ",0"
        if modified_len == 0:
            mod_count_str = ",0"

        new_header = f"@@ -{start_orig}{orig_count_str} +{start_mod}{mod_count_str} @@"
        # Preserve any trailing comments on the hunk header line
        original_header_rest = current_hunk_header.split('@@', 2)[-1]
        new_header += original_header_rest

        # Print the corrected hunk
        sys.stdout.write(new_header)
        sys.stdout.writelines(hunk_lines)

        # Reset for the next hunk
        current_hunk_header = None
        hunk_lines = []

    for line in lines:
        # A '---' line marks the beginning of a diff for a new file.
        # This is our key to handling multi-file patches.
        if line.startswith('--- ') and "/" in line:
            # Process any pending hunk from the *previous* file before starting a new one.
            process_hunk()
            # Print the file header line itself
            sys.stdout.write(line)
        elif line.startswith('@@'):
            # Process the previous hunk within the same file.
            process_hunk()
            # Start a new hunk
            current_hunk_header = line
            # hunk_lines is already empty from the process_hunk call
        elif current_hunk_header:
            # This line is part of the current hunk's body.
            hunk_lines.append(line)
        else:
            # This is a header line before the first hunk (e.g., 'diff --git', 'index', '+++').
            sys.stdout.write(line)

    # Process the very last hunk in the file after the loop finishes.
    process_hunk()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path_to_patch_file>")
        sys.exit(1)

    fix_patch_file(sys.argv[1])
