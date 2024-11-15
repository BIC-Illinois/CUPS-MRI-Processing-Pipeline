#!/bin/bash
# This script is used to perform heudiconv conversion from DICOM to BIDS NIFTI.
# It takes various input parameters and sets up the necessary environment variables.
# The script then runs the BIDS App command using Singularity/Apptainer containers.

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
# - scripts - The directory containing scripts
# - stmpdir - The scratch temporary directory
# - scachedir - The scratch cache directory
# - projDir - The project directory
# - ses - The session number
# - sub - The subject number
# - TEMPLATEFLOW_HOST_HOME - The TemplateFlow host home directory
# - SINGULARITYENV_TEMPLATEFLOW_HOME - The TemplateFlow environment variable

# Usage: slurm_hdc.sh -p <project> -s <session> -z <subject> -m <minqc> -f <fieldmaps> -l <longitudinal> -b <base_dir> -t <version> -a <delta_proj>
# Example: sbatch slurm_hdc.sh -p BIC -s ses-01 -z 001 -m no -f yes -l yes -b /scratch/${delta_proj}/BICpipeline -t prisma -a bcgn

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


## setup our variables and change to the session directory


# Read version from JSON file using jq in apptainer container
CONFIG_JSON=${scripts}/conf/${project}_hdc_config.json
# if CONFIG_JSON is not found, exit code 17 for no config file
if [ ! -f "${CONFIG_JSON}" ]; then
    echo "Config file not found"
    exit 17
fi

SLURM_CPUS_PER_TASK=$(singularity exec -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SLURM_CPUS_PER_TASK' /scripts/config.json)
HEUDICONV_VERSION=$(singularity exec -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.HEUDICONV_VERSION' /scripts/config.json)

# Get the number of CPUs from sbatch job details
num_cpus=$SLURM_CPUS_PER_TASK

cd $projDir

# Check Freesurfer directory, only required to exist already if using outputs of freesurfer longitudinal pipeline
if [ "${longitudinal}" == "yes" ]; then
    if [ ! -d "${projDir}/bids/derivatives_${sesname}/sourcedata/freesurfer_${sesname}/${subject}" ]; then
        echo "Freesurfer directory not found for ${subject} ${sesname}"
        exit 79
    else
        fs_dir="${projDir}/bids/derivatives_${sesname}/sourcedata/freesurfer_${sesname}/"
	    SOURCEDATA_DIR="bids/sourcedata_${sesname}"
	    DERIVATIVES_DIR="bids/derivatives_${sesname}"
	    CACHESING=${scachedir}/${project}_${subject}_longitudinal_${sesname}_anat
	    TMPSING=${stmpdir}/${project}_${subject}_longitudinal_${sesname}_anat
    fi
else
    if [ ! -d "${projDir}/bids/derivatives/sourcedata/freesurfer/${subject}" ]; then
        echo "Freesurfer directory not found for ${subject} ${sesname}"
        fs_dir="${projDir}/bids/derivatives/sourcedata/freesurfer/"
        SOURCEDATA_DIR="bids/sourcedata"
        DERIVATIVES_DIR="bids/derivatives"
	    CACHESING=${scachedir}/${project}_${subject}_${sesname}_anat
	    TMPSING=${stmpdir}/${project}_${subject}_${sesname}_anat
    else
        fs_dir="${projDir}/bids/derivatives/sourcedata/freesurfer/"
        SOURCEDATA_DIR="bids/sourcedata"
        DERIVATIVES_DIR="bids/derivatives"
	    CACHESING=${scachedir}/${project}_${subject}_${sesname}_anat
	    TMPSING=${stmpdir}/${project}_${subject}_${sesname}_anat
    fi
fi

mkdir $CACHESING -p
mkdir $TMPSING -p
chmod 730 -R $CACHESING
chmod 730 -R $TMPSING

TEMPLATEFLOW_HOST_HOME=$IMAGEDIR/templateflow
export SINGULARITYENV_TEMPLATEFLOW_HOME="/imgdir/templateflow"

	NOW=$(date +"%m-%d-%Y-%T")
	echo "HeuDiConv started $NOW" >> ${scripts}/fulltimer.txt

	#heudiconv
	echo "Running heudiconv"
	${scripts}/project_doc.sh ${project} ${subject} ${sesname} "heudiconv" "yes"
	ses=${sesname:4}
	sub=${subject:4}

SINGULARITY_CACHEDIR=$CACHESING \
SINGULARITY_TMPDIR=$TMPSING \
singularity exec --cleanenv --bind ${projDir}:/datain ${IMAGEDIR}/heudiconv-v1.0.0.sif \
heudiconv -d /datain/{subject}/{session}/scans/SCANS/*/DICOM/*dcm \
-f /datain/${project}_heuristic.py \
-o /datain/bids/sourcedata --minmeta \
-s ${sub} -ss ${ses} -c dcm2niix -b --overwrite 

NOW=$(date +"%m-%d-%Y-%T")
echo "HeuDiConv finished $NOW" >> ${scripts}/fulltimer.txt

if [ "${fieldmaps}" == "yes" ];
then
    SINGULARITY_CACHEDIR=$CACHESING \
    SINGULARITY_TMPDIR=$TMPSING \
    singularity exec --bind ${projDir}:/data,${scripts}:/scripts ${IMAGEDIR}/ubuntu-jq-0.1.sif \
    /scripts/jsoncrawler.sh /data/bids/sourcedata ${sesname} ${subject}
fi
	
	cd ${projDir}/bids/${subject}/${sesname}/anat/
	echo "`ls *DREAM*`" >> ${projDir}/bids/.bidsignore
	rm ${projDir}/bids/derivatives/${subject}/${sesname}/tmp
	rm ${projDir}/bids/derivatives/${subject}/${sesname}/test.txt
