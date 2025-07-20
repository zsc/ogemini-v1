#!/bin/bash
cd toy_projects/ocaml_2048
echo "Create OCaml hello world project: write_file dune-project, write_file hello.ml, write_file dune, then dune_build" | source ../../.env && ../../_build/default/bin/main.exe
cd -