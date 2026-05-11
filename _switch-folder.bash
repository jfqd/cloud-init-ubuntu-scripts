#!/usr/bin/bash

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"
