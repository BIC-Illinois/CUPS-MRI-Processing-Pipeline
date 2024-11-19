#!/bin/bash
# This script is used to run MRIQC and fMRIPrep anat only preprocessing on anatomical data.
# It takes various input parameters and sets up the necessary environment variables.
# The script then runs the BIDS App command using Apptainer/Apptainer containers.

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

# Usage: slurm_proc_anat.sh -p <project> -s <session> -z <subject> -m <minqc> -f <fieldmaps> -l <longitudinal> -b <base_dir> -t <version> -a <delta_proj>
# Example: sbatch slurm_proc_anat.sh -p BIC -s ses-01 -z 001 -m no -f yes -l yes -b /scratch/${delta_proj}/BICpipeline -t prisma -a bcgn

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

# if apptainer is not found and apptainer is not found in the path, exit code 20 for lacking apptainer or apptainer
if which apptainer; then
    echo `apptainer --version`
elif which apptainer; then
    echo `apptainer --version`
else
    echo "apptainer and apptainer not in path"
    # try to load apptainer or apptainer module, if neither works exit code 20 for lacking apptainer or apptainer
    if module load apptainer; then
        echo `apptainer --version`
    elif module load apptainer; then
        echo `apptainer --version`
    else
        echo "apptainer and apptainer not in path"
        exit 20
    fi
fi


# Read version from JSON file using jq in apptainer container
CONFIG_JSON=${scripts}/conf/${project}_anat_config.json
echo ${CONFIG_JSON}
# if CONFIG_JSON is not found, exit code 17 for no config file
if [ ! -f "${CONFIG_JSON}" ]; then
    echo "Config file not found"
    exit 17
fi
FMRIPREP_VERSION=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.FMRIPREP_VERSION' /scripts/config.json)
SLURM_CPUS_PER_TASK=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SLURM_CPUS_PER_TASK' /scripts/config.json)
FMRIPREP_MEMORY_GB=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.FMRIPREP_MEMORY_GB' /scripts/config.json)
MRIQC_VERSION=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.MRIQC_VERSION' /scripts/config.json)
ANAT_ONLY=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.ANAT_ONLY' /scripts/config.json)
LAYNII_VERSION=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.LAYNII_VERSION' /scripts/config.json)
LAYNII_DENOISE_BETA=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.LAYNII_DENOISE_BETA' /scripts/config.json)
# if ANAT_ONLY "null", exit code 42 for wrong script
if [ "${ANAT_ONLY}" == "null" ]; then
    echo "ANAT_ONLY is null, please use the correct script"
    exit 42
fi
# Get the number of CPUs from sbatch job details
num_cpus=$SLURM_CPUS_PER_TASK

cd $projDir

anat_dir="${projDir}/bids/sourcedata/sub-${sub}/ses-${ses}/anat"
mkdir -p ${projDir}/bids/derivatives/sourcedata/

# if version is terra and mp2rage files exist in ${anat_dir}, then we denoise the MP2RAGE UNI image using LAYNII
if [ "${version}" == "terra" ] && [ -f "${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageinv_run-1_T1w.nii.gz" ] && [ -f "${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageinv_run-2_T1w.nii.gz" ] && [ -f "${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageuni_run-3_T1w.nii.gz" ]; then
    echo "Denoising MP2RAGE with LAYNII"
	APPTAINER_CACHEDIR=$CACHESING APPTAINER_TMPDIR=$TMPSING apptainer exec --cleanenv --bind ${anat_dir}:/datain $IMAGEDIR/laynii-v2.1.1.sif \
        /opt/laynii2/laynii/LN_MP2RAGE_DNOISE -INV1 /datain/sub-${sub}_ses-${ses}_acq-mp2rageinv_run-1_T1w.nii.gz \
        -INV2 /datain/sub-${sub}_ses-${ses}_acq-mp2rageinv_run-2_T1w.nii.gz -UNI /datain/sub-${sub}_ses-${ses}_acq-mp2rageuni_run-3_T1w.nii.gz -beta ${LAYNII_DENOISE_BETA}
	mv ${anat_dir}/*inv* ${projDir}/bids/derivatives/sourcedata/
	mv ${anat_dir}/*uni_run-*_T1w.nii.gz ${projDir}/bids/derivatives/sourcedata
	mv ${anat_dir}/*uni_run-*_T1w.json ${projDir}/bids/derivatives/sourcedata
	mv ${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageuni_run-3_T1w*border*.nii.gz ${projDir}/bids/derivatives/sourcedata
    mv ${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageuni_run-3_T1w_denoised.nii.gz ${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageunidenoised_T1w.nii.gz 
    cp ${projDir}/bids/sourcedata/${subject}/${sesname}/${subject}_${sesname}_scans.tsv ${projDir}/bids/derivatives/sourcedata/
    cd ${projDir}/bids/sourcedata/${subject}/${sesname}/
    sed -i '/DREAM/d' ./infile ${subject}_${sesname}_scans.tsv
    sed -i '/acq-mp2rageinv_run-1_T1w/d' ${subject}_${sesname}_scans.tsv
    sed -i '/acq-mp2rageinv_run-2_T1w/d' ${subject}_${sesname}_scans.tsv
    sed -i 's/acq-mp2rageuni_run-3_T1w/acq-mp2rageunidenoised_T1w/g' ${subject}_${sesname}_scans.tsv
    cd -
# else if the version is terra and the three MP2RAGE files are not found, then we look for the denoised MP2RAGE file
elif [ "${version}" == "terra" ] && [ -f "${anat_dir}/sub-${sub}_ses-${ses}_acq-mp2rageunidenoised_T1w.nii.gz" ]; then
    echo "Denoised MP2RAGE file found"
    cp ${projDir}/bids/sourcedata/${subject}/${sesname}/${subject}_${sesname}_scans.tsv ${projDir}/bids/derivatives/sourcedata/
    cd ${projDir}/bids/sourcedata/${subject}/${sesname}/
    sed -i '/DREAM/d' ./infile ${subject}_${sesname}_scans.tsv
    sed -i '/acq-mp2rageinv_run-1_T1w/d' ${subject}_${sesname}_scans.tsv
    sed -i '/acq-mp2rageinv_run-2_T1w/d' ${subject}_${sesname}_scans.tsv
    sed -i 's/acq-mp2rageuni_run-3_T1w/acq-mp2rageunidenoised_T1w/g' ${subject}_${sesname}_scans.tsv
    cd -
# else if the version is terra and no MP2RAGE files are found, then we echo a message
elif [ "${version}" == "terra" ]; then
    echo "No MP2RAGE files found for denoising, ensure this is a Terra session and that the MP2RAGE files are properly labeled"
fi



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
export APPTAINERENV_TEMPLATEFLOW_HOME="/imgdir/templateflow"
MPLCONFIG=${TMPSING}/mpl
mkdir ${MPLCONFIG}
export APPTAINERENV_MPLCONFIGDIR=/sing_scratch/mpl

	cd ${projDir}/bids/sourcedata/${subject}/${sesname}/anat/
	echo "`ls *DREAM*`" >> ${projDir}/bids/sourcedata/.bidsignore
	rm ${projDir}/bids/derivatives/${subject}/${sesname}/tmp
	rm ${projDir}/bids/derivatives/${subject}/${sesname}/test.txt
	cd -

if [ -d "${projDir}/${SOURCEDATA_DIR}/${subject}/${sesname}/anat" ];
then

mkdir -p ${projDir}/${DERIVATIVES_DIR}/mriqc

echo "Running MRIQC"
APPTAINER_CACHEDIR=$CACHESING APPTAINER_TMPDIR=$TMPSING apptainer run --contain --no-home --cleanenv \
--bind ${TEMPLATEFLOW_HOST_HOME}:${APPTAINERENV_TEMPLATEFLOW_HOME} \
--bind ${projDir}/${SOURCEDATA_DIR}:/data,${projDir}/${DERIVATIVES_DIR}/mriqc:/out \
$IMAGEDIR/mriqc-v${MRIQC_VERSION}.sif /data /out participant \
--participant-label ${sub} \
--session-id ${ses} \
-v --no-sub

chmod 730 -R ${projDir}/${DERIVATIVES_DIR}/mriqc/${subject}/${sesname}

if [ "${MINQC}" == "yes" ]; then
echo "Minimum QC done, exiting"
exit 0
fi

NOW=$(date +"%m-%d-%Y-%T")
echo "fMRIPrep started $NOW" >> ${scripts}/fulltimer.txt

# OMP_NTHREADS_VAL=$[SLURM_CPUS_PER_TASK-4]

APPTAINER_CACHEDIR=${CACHESING} APPTAINER_TMPDIR=${TMPSING} apptainer run \
--contain --no-home --cleanenv --bind ${IMAGEDIR}:/imgdir,${TMPSING}:/sing_scratch,${projDir}:/data \
${IMAGEDIR}/fmriprep-v${FMRIPREP_VERSION}.sif \
--fs-license-file /imgdir/license.txt /data/${SOURCEDATA_DIR} /data/${DERIVATIVES_DIR}/fmriprep \
-w /sing_scratch \
--nthreads ${num_cpus} --omp-nthreads $((num_cpus / 2)) --mem_mb $((FMRIPREP_MEMORY_GB * 1000)) \
-vv --notrack --anat-only \
participant --participant-label ${subject}

chmod 744 -R ${projDir}/${DERIVATIVES_DIR}/fmriprep/${subject}/${sesname}
NOW=$(date +"%m-%d-%Y-%T")
echo "fMRIPrep finished $NOW" >> ${scripts}/fulltimer.txt

rm -rf ${CACHESING}
rm -rf ${TMPSING}

else
echo "No anat data for ${subject} ${sesname}" >> ${scripts}/fulltimer.txt
fi
