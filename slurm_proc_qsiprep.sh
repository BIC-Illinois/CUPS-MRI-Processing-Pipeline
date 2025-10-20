#!/bin/bash
# This script is used to run QSIPrep preprocessing on dMRI data.
# It takes various input parameters and sets up the necessary environment variables.
# The script then runs the QSIPrep command using Singularity/Apptainer containers.

# Input parameters:
# -p: CLEANPROJECT - The project name
# -s: CLEANSESSION - The session name
# -z: CLEANSUBJECT - The subject name
# -m: MINQC - The minimum quality control threshold
# -f: fieldmaps - The fieldmaps directory
# -l: longitudinal - USE IF SIGNIFICANT MORPHOLOGY CHANGES ARE EXPECTED - COMPUTATIONALLY EXPENSIVE, REQUIRES SESSION-LEVEL FREESURFER OUTPUT
# -b: base_dir - The base directory
# -t: version - The scanner version (prisma, terra)
# -a: delta_proj - The delta project name

# Environment variables:
# - IMAGEDIR - The directory containing Singularity images
# - tmpdir - The temporary directory
# - scripts - The directory containing scripts
# - stmpdir - The scratch temporary directory
# - scachedir - The scratch cache directory
# - projDir - The project directory
# - ses - The session number
# - sub - The subject number
# - TEMPLATEFLOW_HOST_HOME - The TemplateFlow host home directory
# - SINGULARITYENV_TEMPLATEFLOW_HOME - The TemplateFlow environment variable

# Usage: slurm_proc_qsirecon.sh -p <project> -s <session> -z <subject> -m <minqc> -f <fieldmaps> -l <longitudinal> -b <base_dir> -t <version> -a <delta_proj>
# Example: sbatch slurm_proc_qsiprep_dev.sh -p BIC -s ses-01 -z 001 -m 0.5 -f fieldmaps -l longitudinal -b /scratch/${delta_proj}/BICpipeline -t prisma -a bcgn

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

ses=${sesname:4}
sub=${subject:4}
# if delta_proj is not "local", set the following variables
if [ "${delta_proj}" != "local" ]; then
    IMAGEDIR=/projects/bcgn/singularity_images
    scripts=/projects/${delta_proj}/scripts
    stmpdir=/work/hdd/${delta_proj}/stmp
    scachedir=/work/hdd/${delta_proj}/scache
    projDir=/work/hdd/${delta_proj}/BICpipeline/${version}/testing/${project}
    scripts=/projects/${delta_proj}/BICpipeline/${version}/scripts/cups
# other wise paths start with ${base_dir}
else
    IMAGEDIR=${base_dir}/singularity_images
    tmpdir=${base_dir}/${version}/tmp
    scripts=${base_dir}/${version}/scripts
    stmpdir=${base_dir}/${version}/scratch/stmp
    scachedir=${base_dir}/${version}/scratch/scache
    projDir=${base_dir}/${version}/testing/${project}
    scripts=${base_dir}/${version}/scripts
fi


# Read version from JSON file using jq in apptainer container
CONFIG_JSON=${scripts}/conf/${project}_qsi_config_GQI.json
QSIPREP_VERSION=$(singularity exec --contain -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.QSIPREP_VERSION' /scripts/config.json)
SLURM_CPUS_PER_TASK=$(singularity exec --contain -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SLURM_CPUS_PER_TASK' /scripts/config.json)
QSIPREP_MEMORY_GB=$(singularity exec --contain -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.QSIPREP_MEMORY_GB' /scripts/config.json)
OUTPUT_RESOLUTION=$(singularity exec --contain -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.OUTPUT_RESOLUTION' /scripts/config.json)
RECON_SPEC=$(singularity exec --contain -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.RECON_SPEC' /scripts/config.json)
# Get the number of CPUs from sbatch job details
num_cpus=$SLURM_CPUS_PER_TASK

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
	CACHESING=${scachedir}/${project}_${subject}_longitudinal_${sesname}_qsiprep
	TMPSING=${stmpdir}/${project}_${subject}_longitudinal_${sesname}_qsiprep
    fi
else
    if [ ! -d "${projDir}/bids/derivatives/fmriprep/sourcedata/freesurfer/${subject}" ]; then
        echo "Freesurfer directory not found for ${subject} ${sesname}"
        exit 1
    else
        fs_dir="${projDir}/bids/derivatives/fmriprep/sourcedata/freesurfer/"
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
export SINGULARITYENV_TEMPLATEFLOW_HOME="/imgdir/templateflow"

MPLCONFIGDIR="${CACHESING}/mpl"
mkdir ${MPLCONFIGDIR}
export SINGULARITYENV_MPLCONFIGDIR="/sing_scratch/mpl"

if [ -d "${projDir}/${SOURCEDATA_DIR}/${subject}/${sesname}/dwi" ];
then

NOW=$(date +"%m-%d-%Y-%T")
echo "QSIprep started $NOW" >> ${scripts}/fulltimer.txt

# OMP_NTHREADS_VAL=$[SLURM_CPUS_PER_TASK-4]

SINGULARITY_CACHEDIR=${CACHESING} SINGULARITY_TMPDIR=${TMPSING} singularity run \
--no-home --cleanenv --bind ${IMAGEDIR}:/imgdir,${CACHESING}:/sing_scratch,${projDir}:/data \
${IMAGEDIR}/qsiprep-v${QSIPREP_VERSION}.sif \
--fs-license-file /imgdir/license.txt /data/${SOURCEDATA_DIR} /data/${DERIVATIVES_DIR}/qsiprep \
--output-resolution ${OUTPUT_RESOLUTION} -w /sing_scratch --denoise-method patch2self \
--nthreads ${num_cpus} --omp-nthreads $((num_cpus / 2)) --mem $((QSIPREP_MEMORY_GB * 1000)) \
-vv --notrack \
participant --participant-label ${subject}

chmod 730 -R ${projDir}/${DERIVATIVES_DIR}/qsiprep/${subject}/${sesname}
NOW=$(date +"%m-%d-%Y-%T")
echo "QSIprep finished $NOW" >> ${scripts}/fulltimer.txt


ANTS_VERSION="v2.6.3"
SINGULARITY_CACHEDIR=${CACHESING} SINGULARITY_TMPDIR=${TMPSING} singularity run \
--no-home --cleanenv --bind ${scripts}:${scripts},${CACHESING}:/sing_scratch,${projDir}:/data \
${IMAGEDIR}/ants-${ANTS_VERSION}.sif ${scripts}/refine_qsiprep_coreg.sh -b ${projDir}/${DERIVATIVES_DIR} -z ${subject}

rm -rf ${CACHESING}
rm -rf ${TMPSING}

else
echo "No dwi data for ${subject} ${sesname}" >> ${scripts}/fulltimer.txt
fi
