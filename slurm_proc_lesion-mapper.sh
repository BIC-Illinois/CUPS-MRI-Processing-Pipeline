#!/bin/bash
#
#SBATCH --job-name=lesion_mapper_range
#SBATCH --output=lesion_mapper_range.txt
#SBATCH --ntasks-per-node=1
#SBATCH --time=20:00:00


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
echo "${CLEANSESSION}"
export session="${CLEANSESSION}"
echo ${session}
export project=${CLEANPROJECT}

export subject="sub-"${CLEANSUBJECT}
export sesname="ses-"${session}


# if delta_proj is not "local", set the following variables
if [ "${delta_proj}" != "local" ]; then
    export IMAGEDIR=/projects/${delta_proj}/apptainer_images
    export tmpdir=/work/hdd/${delta_proj}/tmp
    export scripts=/project/${delta_proj}/scripts
    export stmpdir=/work/hdd/${delta_proj}/stmp
    export scachedir=/work/hdd/${delta_proj}/scache
    export projDir=/work/hdd/${delta_proj}/BICpipeline/${version}/testing/${project}
    export scripts=/projects/${delta_proj}/BICpipeline/${version}/scripts/cups
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

export proj=${project}
export num_cpus=12
echo "Running QSM with n_cpus = ${SLURM_CPUS_PER_TASK}"
export CACHESING=${scachedir}/${project}_${subject}_${sesname}_lesion-mapper
export TMPSING=${stmpdir}/${project}_${subject}_${sesname}_lesion-mapper
mkdir -p $CACHESING
mkdir -p $TMPSING



if [ ${#SLURM_ARRAY_TASK_ID} == 1 ];
then
    	inputNo="00${SLURM_ARRAY_TASK_ID}"
        echo "$1 started $NOW" > ${scripts}/dyno_$1_test_${inputNo}.txt

	    apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.5 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p5/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p5/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.6 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p6/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p6/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.7 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p7/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p7/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids/derivatives/lesion-mapper:/datain -W /datain ${IMAGEDIR}/ffmpeg.sif ffmpeg -framerate 1 -pattern_type glob -i '/datain/wmthr_p*/*${proj}${inputNo}/ses-${session}/*.png' -c:v libx264 -r 30 -pix_fmt yuv420p -s 1630x906 /datain/${proj}${inputNo}_ses-${session}_lesions.mp4

        NOW=$(date "+%D-%T")
        echo "$1 finished $NOW" >> ${scripts}/dyno_$1_test_${inputNo}.txt
        exit 0
elif [ ${#SLURM_ARRAY_TASK_ID} == 2 ];
then
    	inputNo="0${SLURM_ARRAY_TASK_ID}"
        echo "$1 started $NOW" > ${scripts}/dyno_$1_test_${inputNo}.txt
	
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.5 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p5/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p5/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.6 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p6/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p6/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.7 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p7/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p7/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids/derivatives/lesion-mapper:/datain -W /datain ${IMAGEDIR}/ffmpeg.sif ffmpeg -framerate 1 -pattern_type glob -i '/datain/wmthr_p*/*${proj}${inputNo}/ses-${session}/*.png' -c:v libx264 -r 30 -pix_fmt yuv420p -s 1630x906 /datain/${proj}${inputNo}_ses-${session}_lesions.mp4

        NOW=$(date "+%D-%T")
        echo "$1 finished $NOW" >> ${scripts}/dyno_$1_test_${inputNo}.txt
        exit 0
elif [ ${#SLURM_ARRAY_TASK_ID} == 3 ];
then
    	inputNo="${SLURM_ARRAY_TASK_ID}"
        echo "$1 started $NOW" > ${scripts}/dyno_$1_test_${inputNo}.txt

	apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.5 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p5/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p5/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.6 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p6/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p6/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids:/inputs,${IMAGEDIR}/license.txt:/opt/freesurfer/license.txt ${IMAGEDIR}/lesion-mapper-bids.sif /bin/bash -c "export FSLDIR=/opt/fsl-6.0.3 && lesion-mapper /inputs -v -ses_label ${session} -participant_label ${proj}${inputNo} -fmriprep_dir /inputs/derivatives/fmriprep -no2fast -wmthr 0.7 -png"
        mkdir ${projDir}/bids/derivatives/lesion-mapper/wmthr_p7/sub-${proj}${inputNo}/ses-${session}/ -p
        mv ${projDir}/bids/derivatives/lesion-mapper/sub-${proj}${inputNo}/ses-${session}/* ${projDir}/bids/derivatives/lesion-mapper/wmthr_p7/sub-${proj}${inputNo}/ses-${session}/
        apptainer exec --cleanenv --containall -B ${projDir}/bids/derivatives/lesion-mapper:/datain -W /datain ${IMAGEDIR}/ffmpeg.sif ffmpeg -framerate 1 -pattern_type glob -i '/datain/wmthr_p*/*${proj}${inputNo}/ses-${session}/*.png' -c:v libx264 -r 30 -pix_fmt yuv420p -s 1630x906 /datain/${proj}${inputNo}_ses-${session}_lesions.mp4

        NOW=$(date "+%D-%T")
        echo "$1 finished $NOW" >> ${scripts}/dyno_$1_test_${inputNo}.txt
        exit 0
fi
