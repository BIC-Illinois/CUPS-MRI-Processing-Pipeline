#!/bin/bash
#SBATCH --job-name=FSQC
#SBATCH --output=fsqc_%j.out
#SBATCH --error=fsqc_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=128G
#SBATCH --cpus-per-task=12
# Input parameters:
# -p: CLEANPROJECT - The project name
# -b: base_dir - The base directory
# -t: version - The scanner version (prisma, terra)
# -a: delta_proj - The delta project name

# Environment variables:
# - IMAGEDIR - The directory containing Singularity images
# - scripts - The directory containing scripts
# - stmpdir - The scratch temporary directory
# - scachedir - The scratch cache directory
# - projDir - The project directory
# - ses - The session number
# - sub - The subject number
# - TEMPLATEFLOW_HOST_HOME - The TemplateFlow host home directory
# - SINGULARITYENV_TEMPLATEFLOW_HOME - The TemplateFlow environment variable

# Usage: slurm_proc_fsqc.sh -p <project> -b <base_dir> -t <version> -a <delta_proj>
# Example: sbatch slurm_proc_fsqc.sh -p BIC -b /scratch/${delta_proj}/BICpipeline -t prisma -a bcgn

while getopts :p::m:f:l:b:t:a: option; do
    case ${option} in
    	p) export CLEANPROJECT=$OPTARG ;;
        b) export base_dir=$OPTARG ;;
        t) export version=$OPTARG ;;
        a) export delta_proj=$OPTARG ;;
    esac
done

# if delta_proj is not "local", set the following variables
if [ "${delta_proj}" != "local" ]; then
    IMAGEDIR=/projects/${delta_proj}/singularity_images
    scripts=/projects/${delta_proj}/scripts
    stmpdir=/scratch/${delta_proj}/stmp
    scachedir=/scratch/${delta_proj}/scache
    projDir=/scratch/${delta_proj}/BICpipeline/prisma/testing/${project}
    scripts=/projects/${delta_proj}/scripts
# other wise paths start with ${base_dir}
else
    IMAGEDIR=${base_dir}/singularity_images
    scripts=${base_dir}/${version}/scripts
    stmpdir=${base_dir}/${version}/scratch/stmp
    scachedir=${base_dir}/${version}/scratch/scache
    projDir=${base_dir}/${version}/testing/${project}
    scripts=${base_dir}/${version}/scripts
fi

# if singularity is not found and apptainer is not found in the path, exit code 20 for lacking singularity or apptainer
if which singularity; then
    echo `singularity --version`
elif which apptainer; then
    echo `apptainer --version`
else
    echo "singularity and apptainer not in path"
    # try to load singularity or apptainer module, if neither works exit code 20 for lacking singularity or apptainer
    if module load singularity; then
        echo `singularity --version`
    elif module load apptainer; then
        echo `apptainer --version`
    else
        echo "singularity and apptainer not in path"
        exit 20
    fi
fi

FSQC_IMAGE=${IMAGEDIR}/fsqc-v2.1.1.sif
FS_DIR=${projDir}/bids/derivatives/sourcedata/freesurfer
FSQC_DIR=${projDir}/bids/derivatives/fsqc

if [ ! -d "$FSQC_DIR" ]; then
echo "No FSQC output detected in derivatives, making new directory"
mkdir -p ${FSQC_DIR}
fi

# Run FSQC via Apptainer
apptainer exec --cleanenv --contain --no-home $FSQC_IMAGE run_fsqc --subjects_dir ${FS_DIR} \
--output_dir ${FSQC_DIR} --outlier --screenshots --fornix --shape
