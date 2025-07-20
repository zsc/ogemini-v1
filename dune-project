(lang dune 3.0)

(name ogemini)

(package
 (name ogemini)
 (depends 
  ocaml 
  dune
  lwt
  cohttp-lwt-unix
  yojson
  re
  logs
  fmt))

(authors "OGemini Team")

(maintainers "OGemini Team")

(license MIT)

(documentation https://github.com/yourorg/ogemini)

(homepage https://github.com/yourorg/ogemini)

(bug_reports https://github.com/yourorg/ogemini/issues)

(source (github yourorg/ogemini))