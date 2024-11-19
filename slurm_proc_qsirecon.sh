#!/bin/bash
# This script is used to run QSIPrep reconstruction on dMRI data.
# It takes various input parameters and sets up the necessary environment variables.
# The script then runs the QSIPrep reconstruction command using Apptainer/Apptainer containers.

# Input parameters:
# -p: CLEANPROJECT - The project name
# -s: CLEANSESSION - The session name
# -z: CLEANSUBJECT - The subject name
# -m: MINQC - The minimum quality control threshold
# -f: fieldmaps - The fieldmaps directory
# -l: longitudinal - The longitudinal directory
# -b: base_dir - The base directory
# -t: version - The scanner version (prisma, terra)
# -a: delta_proj - The delta project name

# Environment variables:
# - IMAGEDIR - The directory containing Apptainer images
# - tmpdir - The temporary directory
# - scripts - The directory containing scripts
# - stmpdir - The scratch temporary directory
# - scachedir - The scratch cache directory
# - projDir - The project directory
# - ses - The session number
# - sub - The subject number
# - TEMPLATEFLOW_HOST_HOME - The TemplateFlow host home directory
# - APPTAINERENV_TEMPLATEFLOW_HOME - The TemplateFlow environment variable

# Usage: slurm_proc_qsirecon.sh -p <project> -s <session> -z <subject> -m <minqc> -f <fieldmaps> -l <longitudinal> -b <base_dir> -t <version> -a <delta_proj>
# Example: sbatch slurm_proc_qsirecon.sh -p BIC -s ses-01 -z 001 -m 0.5 -f fieldmaps -l longitudinal -b /scratch/${delta_proj}/BICpipeline -t prisma -a bcgn

while getopts :p:s:z:m:f:l:b:t:a: option; do
    case ${option} in
    	p) export CLEANPROJECT=$OPTARG ;;
    	s) export CLEANSESSION=$OPTARG ;;
    	z) export CLEANSUBJECT=$OPTARG ;;
        m) export MINQC=$OPTARG ;;
        f) export fieldmaps=$OPTARG ;;
        l) export longitudinal=$OPTARG ;;
        b) export base_dir=$OPTARG ;;
        t) export version=$OPTARG ;;
        a) export delta_proj=$OPTARG ;;
    esac
done

stmpdir=/scratch/${delta_proj}/stmp
scachedir=/scratch/${delta_proj}/scache

## setup our variables and change to the session directory

echo ${CLEANPROJECT}
echo ${CLEANSUBJECT}
echo ${CLEANSESSION}
pwd

#translating naming conventions
echo "${CLEANSESSION: -1}"
session="${CLEANSESSION: -1}"
echo ${session}
project=${CLEANPROJECT}

subject="sub-"${CLEANSUBJECT}
sesname="ses-"${session}

# if delta_proj is not "local", set the following variables
if [ "${delta_proj}" != "local" ]; then
    IMAGEDIR=/projects/bcgn/apptainer_images
    tmpdir=/work/hdd/${delta_proj}/tmp
    scripts=/work/hdd/${delta_proj}/scripts
    stmpdir=/work/hdd/${delta_proj}/stmp
    scachedir=/work/hdd/${delta_proj}/scache
    projDir=/work/hdd/${delta_proj}/BICpipeline/${version}/testing/${project}
    scripts=/projects/${delta_proj}/BICpipeline/${version}/scripts/cups
# /projects/bdpf/BICpipeline/terra/scripts/cups
# other wise paths start with ${base_dir}
else
    IMAGEDIR=${base_dir}/apptainer_images
    tmpdir=${base_dir}/${version}/tmp
    scripts=${base_dir}/${version}/scripts
    stmpdir=${base_dir}/${version}/scratch/stmp
    scachedir=${base_dir}/${version}/scratch/scache
    projDir=${base_dir}/${version}/testing/${project}
    scripts=${base_dir}/${version}/scripts
fi

projDir=/scratch/${delta_proj}/BICpipeline/prisma/testing/${project}
scripts=/projects/${delta_proj}/scripts

IMAGEDIR=/projects/${delta_proj}/apptainer_images


ses=${sesname:4}
sub=${subject:4}

echo "reading configuration from  ${CONFIG_JSON}"
# Read version from JSON file using jq in apptainer container
CONFIG_JSON=${scripts}/conf/${project}_qsi_config.json
echo "reading configuration from  ${CONFIG_JSON}"
QSIPREP_VERSION=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.QSIPREP_VERSION' /scripts/config.json)
SLURM_CPUS_PER_TASK=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SLURM_CPUS_PER_TASK' /scripts/config.json)
QSIPREP_MEMORY_GB=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.QSIPREP_MEMORY_GB' /scripts/config.json)
OUTPUT_RESOLUTION=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.OUTPUT_RESOLUTION' /scripts/config.json)
RECON_SPEC=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.RECON_SPEC' /scripts/config.json)
# Get the number of CPUs from sbatch job details
num_cpus=${SLURM_CPUS_PER_TASK}
echo "${QSIPREP_VERSION} ${RECON_SPEC} ${SLURM_CPUS_PER_TASK}"

cd $projDir

# Check Freesurfer directory
if [ "${longitudinal}" == "yes" ]; then
    if [ ! -d "${projDir}/bids/derivatives_${sesname}/sourcedata/freesurfer_${sesname}/${subject}" ]; then
        echo "Freesurfer directory not found for ${subject} ${sesname}"
        exit 1
    else
        fs_dir="${projDir}/bids/derivatives_${sesname}/sourcedata/freesurfer_${sesname}/"
	SOURCEDATA_DIR="bids/sourcedata_${sesname}"
	DERIVATIVES_DIR="bids/derivatives_${sesname}"
	CACHESING=${scachedir}/${project}_${subject}_longitudinal_${sesname}_${RECON_SPEC}
	TMPSING=${stmpdir}/${project}_${subject}_longitudinal_${sesname}_${RECON_SPEC}
    fi
else
    if [ ! -d "${projDir}/bids/derivatives/sourcedata/freesurfer/${subject}" ]; then
        echo "Freesurfer directory not found for ${subject} ${sesname}"
        exit 1
    else
        fs_dir="${projDir}/bids/derivatives/sourcedata/freesurfer/"
        SOURCEDATA_DIR="bids/sourcedata"
        DERIVATIVES_DIR="bids/derivatives"
	CACHESING=${scachedir}/${project}_${subject}_${sesname}_${RECON_SPEC}
	TMPSING=${stmpdir}/${project}_${subject}_${sesname}_${RECON_SPEC}
    fi
fi

mkdir $CACHESING -p
mkdir $TMPSING -p
chmod 730 -R $CACHESING
chmod 730 -R $TMPSING

TEMPLATEFLOW_HOST_HOME=$IMAGEDIR/templateflow
export APPTAINERENV_TEMPLATEFLOW_HOME="/imgdir/templateflow"
MPLCONFIGDIR="${CACHESING}/mpl"
mkdir ${MPLCONFIGDIR}
export APPTAINERENV_MPLCONFIGDIR="/sing_scratch/mpl"

if [ -d "${projDir}/bids/sourcedata_${sesname}/${subject}/${sesname}/dwi" ];
then

NOW=$(date +"%m-%d-%Y-%T")
echo "QSIprep started $NOW" >> ${scripts}/fulltimer.txt

APPTAINERENV_MPLCONFIGDIR=/sing_scratch/mpl APPTAINER_CACHEDIR=${CACHESING} APPTAINER_TMPDIR=${TMPSING} apptainer run \
--no-home --cleanenv --bind ${IMAGEDIR}:/imgdir,${CACHESING}:/sing_scratch,${projDir}:/data \
${IMAGEDIR}/qsiprep-v${QSIPREP_VERSION}.sif \
--fs-license-file /imgdir/license.txt /data/${SOURCEDATA_DIR} /data/${DERIVATIVES_DIR} \
--output-resolution ${OUTPUT_RESOLUTION} -w /sing_scratch \
--nthreads ${num_cpus} --omp-nthreads $((num_cpus / 2)) --mem_mb $((QSIPREP_MEMORY_GB * 1000)) \
-vvv --notrack --recon_input /data/${DERIVATIVES_DIR}/qsiprep \
--freesurfer-input ${fs_dir} \
--recon_spec ${RECON_SPEC} \
participant --participant-label ${subject}

# --bids-filter-file /data/${DERIVATIVES_DIR}/qsiprep/${project}_${ses}_bids_filter.json \
 
chmod 730 -R ${projDir}/${DERIVATIVES_DIR}/qsirecon/${subject}/${sesname}
NOW=$(date +"%m-%d-%Y-%T")
echo "QSIprep finished $NOW" >> ${scripts}/fulltimer.txt

rm -rf ${CACHESING}
rm -rf ${TMPSING}

else
echo "No dwi data for ${subject} ${sesname}" >> ${scripts}/fulltimer.txt
fi

