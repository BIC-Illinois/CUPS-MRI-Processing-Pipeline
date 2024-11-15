#!/bin/bash
# 
# This script queues individual pieces of the pipeline via slurm, after heudiconv has run
#
# Usage: ./main_cc.sh -s A -z CUPS0000 -a local
# get options from the command line arguments

while getopts :s:z:a: option; do
    case ${option} in
        s) export session=$OPTARG ;;
        z) export participant=$OPTARG ;;
        a) export delta_proj=$OPTARG ;;
        \?) echo "Invalid option: -${OPTARG}" ;;
        :) echo "Option -${OPTARG} requires an argument." ;;
    esac
done

project="CUPS"
if [ "${delta_proj}" == "local" ];
then
  partition="bic7t"
  account="traceyws"
  base_dir="/projects/illinois/las/neuro/traceyws/BICpipeline"
else
  partition="cpu"
  account="bdpf-delta-cpu"
  base_dir="/scratch/bdpf/BICpipeline"
fi


sbatch -a 1 --partition=bic7t --account=${account}--time=8:00:00 --mincpus=12 --mem=192G \
--mail-type=begin --mail-type=end --mail-type=fail --mail-user=pcamach2@illinois.edu \
/projects/illinois/las/neuro/traceyws/BICpipeline/terra/scripts/slurm_proc_fmriprep.sh \
-p ${project} -s ${session} -z ${participant} -b ${base_dir} -t terra -a ${delta_proj}

sbatch -a 1 --begin=now+4hours --partition=bic7t --account=${account} \
--time=36:00:00 --mincpus=24 --mem=256G --mail-type=begin --mail-type=end \
--mail-type=fail --mail-user=pcamach2@illinois.edu \
/projects/illinois/las/neuro/traceyws/BICpipeline/terra/scripts/.sh \
-p ${project} -s ${session} -z ${participant} -b ${base_dir} -t terra -a ${delta_proj}

sbatch -a 1 --begin=now+4hours --partition=bic7t --account=${account} --time=8:00:00 \
--mincpus=24 --mem=256G --mail-type=begin --mail-type=end --mail-type=fail --mail-user=pcamach2@illinois.edu \
/projects/illinois/las/neuro/traceyws/BICpipeline/terra/scripts/.sh \
-p ${project} -s ${session} -z ${participant} -b ${base_dir} -t terra -a ${delta_proj}

sbatch -a 1 --begin=now+24hours --partition=bic7t --account=${account} --time=16:00:00 \
--mincpus=24 --mem=256G --mail-type=begin --mail-type=end --mail-type=fail --mail-user=pcamach2@illinois.edu \
/projects/illinois/las/neuro/traceyws/BICpipeline/terra/scripts/.sh \
-p ${project} -s ${session} -z ${participant} -b ${base_dir} -t terra -a ${delta_proj}

