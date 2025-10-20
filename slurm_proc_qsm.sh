#!/bin/bash
#
# Quanitative Susceptibility Mapping


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

ses=${sesname:4}
sub=${subject:4}

echo "reading configuration from  ${CONFIG_JSON}"
# Read version from JSON file using jq in apptainer container
CONFIG_JSON=${scripts}/conf/${project}_qsm_config.json
echo "reading configuration from  ${CONFIG_JSON}"
SLURM_CPUS_PER_TASK=$(apptainer exec --contain --no-home -B ${CONFIG_JSON}:/scripts/config.json ${IMAGEDIR}/jq.sif jq -r '.SLURM_CPUS_PER_TASK' /scripts/config.json)
# Get the number of CPUs from sbatch job details
num_cpus=${SLURM_CPUS_PER_TASK}
echo "Running QSM with n_cpus = ${SLURM_CPUS_PER_TASK}"

cd $projDir

qsmxt $projDir/bids/sourcedata --premade 'gre' --do_qsm --do_swi --do_t2starmap --do_r2starmap --do_segmentation --do_analysis --do_template --auto_yes
