#!/bin/bash

## A poor man's dependency installer for a big script which shouldn't be installed as a system module

DEPS=( \
  "Carp::Always" \
  "Try::Tiny" \
  "Modern::Perl" \
  "Git" \
  "IPC::Cmd" \
  "Log::Log4perl" \
  "Params::Validate" \
  "Pootle::Client" \
)

TESTDEPS=( \
  Test::Exception \
  Test::More::Color \
)

for dep in "${DEPS[@]}"
do
  cpanm $dep
done

