#!/usr/bin/env python

import subprocess
import sys
import time

def main():
    # Start the agent process
    print("🚀 Starting OGemini agent...")
    
    # Change to toy project directory and run agent
    cmd = ["bash", "-c", "cd toy_projects/ocaml_2048 && source ../../.env && ../../_build/default/bin/main.exe"]
    
    process = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        universal_newlines=True
    )
    
    # Wait for agent to start
    time.sleep(2)
    
    # Send the request
    request = """Use write_file to create dune-project file with content "(lang dune 3.0)". Then write_file to create hello.ml with "let () = print_endline \\"Hello OCaml!\\"". Then write_file to create dune file with "(executable (name hello))". Then use dune_build."""
    
    print(f"📤 Sending request: {request}")
    process.stdin.write(request + "\n")
    process.stdin.flush()
    
    # Read output for a while
    for i in range(30):  # Read for ~30 iterations
        try:
            line = process.stdout.readline()
            if line:
                print(line.rstrip())
                if "Tool Execution Confirmation" in line:
                    print("✅ Sending 'y' for confirmation...")
                    process.stdin.write("y\n")
                    process.stdin.flush()
                    time.sleep(0.5)
            else:
                break
        except:
            break
        time.sleep(0.1)
    
    process.terminate()
    print("🏁 Done!")

if __name__ == "__main__":
    main()