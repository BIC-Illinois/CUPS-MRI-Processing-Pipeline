#!/bin/bash
# Run from the setup folder
# Usage: file_structure_gen.sh {base directory} {version}

base_dir=$1
version=$2
mkdir ${base_dir}/${version}

#Create directories for the following: 
# 1. Processing directory
mkdir ${base_dir}/${version}/testing

# 2. Scripts directory for current version
mkdir ${base_dir}/${version}/scripts
cp -R ../* ${base_dir}/${version}/scripts

# 3. Scratch directory for tmp and cache
mkdir ${base_dir}/${version}/scratch
mkdir ${base_dir}/${version}/scratch/stmp
mkdir ${base_dir}/${version}/scratch/scache

# 4. Singularity/Apptainer images location
mkdir ${base_dir}/apptainer_images
cd ${base_dir}
./apptainer_image_gen.sh

# change file permissions
chmod 2755 -R mkdir ${base_dir}/${version}
