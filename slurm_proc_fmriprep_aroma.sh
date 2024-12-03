#!/bin/bash
# This script is used to run fMRIPrep rs-fMRI data.

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

projDir=/scratch/${delta_proj}/BICpipeline/terra/testing/${project}
scripts=/projects/${delta_proj}/BICpipeline/terra/scripts/cups

IMAGEDIR=/projects/bcgn/singularity_images


ses=${sesname:4}
sub=${subject:4}

# Read version from JSON file using jq in apptainer container
CONFIG_JSON=${scripts}/conf/${project}_fMRIPrep_config.json
FMRIPREP_VERSION=$(singularity exec --contain --cleanenv -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.FMRIPREP_VERSION' /scripts/config.json)
SLURM_CPUS_PER_TASK=$(singularity exec --contain --cleanenv -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SLURM_CPUS_PER_TASK' /scripts/config.json)
FMRIPREP_MEMORY_GB=$(singularity exec --contain --cleanenv -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.FMRIPREP_MEMORY_GB' /scripts/config.json)
# CONFOUND_REGRESSION=$(singularity exec --contain --cleanenv -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.CONFOUND_REGRESSION' /scripts/config.json)
# SMOOTHING=$(singularity exec --contain --cleanenv -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SMOOTHING' /scripts/config.json)
# Get the number of CPUs from sbatch job details
num_cpus=$SLURM_CPUS_PER_TASK

CACHESING=${scachedir}/${project}_${subject}_${sesname}_fmriprep
TMPSING=${stmpdir}/${project}_${subject}_${sesname}_fmriprep
mkdir $CACHESING -p
mkdir $TMPSING -p
chmod 730 -R $CACHESING
chmod 730 -R $TMPSING

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
    fi
else
    if [ ! -d "${projDir}/bids/derivatives/fmriprep/sourcedata/freesurfer/${subject}" ]; then
        echo "Freesurfer directory not found for ${subject} ${sesname}"
        fs_dir="${projDir}/bids/derivatives/fmriprep/sourcedata/freesurfer/"
        SOURCEDATA_DIR="bids/sourcedata"
        DERIVATIVES_DIR="bids/derivatives"

#        exit 1
    else
        fs_dir="${projDir}/bids/derivatives/fmriprep/sourcedata/freesurfer/"
        SOURCEDATA_DIR="bids/sourcedata"
        DERIVATIVES_DIR="bids/derivatives"
    fi
fi

chmod 730 -R $CACHESING
chmod 730 -R $TMPSING

TEMPLATEFLOW_HOST_HOME=$IMAGEDIR/templateflow
export APPTAINERENV_TEMPLATEFLOW_HOME="/imgdir/templateflow"
MPLCONFIGDIR="${CACHESING}/mpl"
mkdir ${MPLCONFIGDIR}
export APPTAINERENV_MPLCONFIGDIR="/sing_scratch/mpl"

	cd ${projDir}/bids/sourcedata/${subject}/${sesname}/anat/
	echo "`ls *DREAM*`" >> ${projDir}/bids/.bidsignore
	rm ${projDir}/bids/derivatives/${subject}/${sesname}/tmp
	rm ${projDir}/bids/derivatives/${subject}/${sesname}/test.txt	

if [ -d "${projDir}/${SOURCEDATA_DIR}/${subject}/${sesname}/func" ];
then

NOW=$(date +"%m-%d-%Y-%T")
echo "fmriprep started $NOW" >> ${scripts}/fulltimer.txt

# OMP_NTHREADS_VAL=$[SLURM_CPUS_PER_TASK-4]

mkdir ${projDir}/${DERIVATIVES_DIR}/fmriprep_aroma -p


# version hardcoded to 23.0.2. to maintain ICA-AROMA
APPTAINER_CACHEDIR=${CACHESING} APPTAINER_TMPDIR=${TMPSING} apptainer run \
--contain --cleanenv --no-home --bind ${IMAGEDIR}:/imgdir,${TMPSING}:/sing_scratch,${projDir}:/data \
${IMAGEDIR}/fmriprep-v23.0.2.sif --participant_label ${subject} --nthreads $num_cpus --omp-nthreads $((num_cpus / 2)) \
--level full -w "/sing_scratch" --notrack --use-aroma \
--fs-license-file /imgdir/license.txt /data/${SOURCEDATA_DIR} /data/${DERIVATIVES_DIR}/fmriprep participant

chmod 740 -R ${projDir}/bids/derivatives/fmriprep/${subject}/${sesname}

# note: change memory to variable from config json

else
echo "No rsfMRI data for ${subject} ${sesname}" >> ${scripts}/fulltimer.txt
fi
