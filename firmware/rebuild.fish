#!/usr/bin/env fish

rm parts/*
split -b 4096 -d --numeric-suffixes=1 --additional-suffix=.lua -a 3 main.lua parts/part
