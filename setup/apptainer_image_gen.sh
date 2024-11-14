#!/bin/bash
#
# Generates Apptainer images used in pipeline
# 
# Run on a machine which has sufficient permissions for Apptainer building!
# Please cite the images used and retrieve all relevant licenses
# You will need your own Freesurfer license for some containers
#

# check for apptainer and alias singularity to apptainer if apptainer is not found
if ! command -v apptainer &> /dev/null
then
    echo "Apptainer not found, aliasing singularity to apptainer"
    alias apptainer=singularity
fi

mkdir ./apptainer_images
chmod 744 -R ./apptainer_images
cd ./apptainer_images

apptainer build mriqc-v23.0.1.sif docker://nipreps/mriqc:23.0.1
apptainer build heudiconv-v1.0.0.sif docker://nipy/heudiconv:1.0.0
apptainer build fmriprep-v23.2.1.sif docker://nipreps/fmriprep:23.2.1
apptainer build xcp_d-v0.6.0.sif docker://pennbbl/xcp_d:0.6.0
apptainer build bidsphysio.sif docker://cbinyu/bidsphysio
apptainer build qsiprep-v0.19.1.sif docker://pennbbl/qsiprep:0.19.1

# See README.md for more information on the following containers
apptainer build ubuntu-jqjo.sif jqjo.def
apptainer build bidscoin.sif bidscoin.def
apptainer build laynii-2.0.0.sif laynii.def
apptainer build ashs-1.0.0.sif ashs.def
apptainer build pylearn.sif pylearn.def

# The following examples use the CUDA 10.2 toolkit and runtime (loaded via module or native install)
# These are not required for most of the pipeline, but are included for DTI tractography and network-based statistics respectively
apptainer build scfsl_gpu-v0.3.2.sif docker://mrfilbi/scfsl_gpu:0.3.2
apptainer build matlab-R2019a.sif docker://mathworks/matlab:r2019b

