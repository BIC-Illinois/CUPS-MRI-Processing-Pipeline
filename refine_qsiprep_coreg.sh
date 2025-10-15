#!/bin/bash
#
# Refines QSIPrep DWI-T1w coregistration using antsRegistration rigid transform
#
# Usage: bash refine_qsiprep_coreg.sh -b <bids_dir> -z <subject_id>
#
# Example: bash refine_qsiprep_coreg.sh -b /data/bids_dataset -z sub-01

# Parse command line arguments
while getopts :b:z: option; do
    case ${option} in
        b) export BIDS_DIR=$OPTARG ;;
        z) export SUBJECT_ID=$OPTARG ;;
    esac
done

cd ${BIDS_DIR}/qsiprep/${SUBJECT_ID}

# Loop through each directory that matches the pattern "ses-*"
for session in `ls ${BIDS_DIR}/qsiprep/${SUBJECT_ID}/ | grep ses`; do
cd $session
mkdir coreg_refine
mkdir -p ${BIDS_DIR}/qsiprep_coreg_refine/${SUBJECT_ID}/${session}

# Perform rigid registration of DWI reference to T1w image, with brain masks for both
antsRegistration -d 3 \
    -r [ ../anat/${SUBJECT_ID}_space-ACPC_desc-preproc_T1w.nii.gz, \
         ./dwi/${SUBJECT_ID}_${session}_space-ACPC_dwiref.nii.gz,1 ] \
    -m Mattes[ ../anat/${SUBJECT_ID}_space-ACPC_desc-preproc_T1w.nii.gz, \
               ./dwi/${SUBJECT_ID}_${session}_space-ACPC_dwiref.nii.gz,1,32,Random,0.25 ] \
    -t Rigid[0.2] \
    -c [10000x1000x10000x10000,1e-6,10] \
    -s 7x3x1x0vox \
    -f 8x4x2x1 \
    -o [ ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_from-dwiref_to-t1w_mode-image_xfm, ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_desc-masked_dwiref.nii.gz, ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_desc-maskedInverseWarped_T1w.nii.gz ] \
    -x [ ../anat/${SUBJECT_ID}_space-ACPC_desc-brain_mask.nii.gz, \
         ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-brain_mask.nii.gz ]

# Rename transform file
mv ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_from-dwiref_to-t1w_mode-image_xfm0GenericAffine.mat ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_from-dwiref_to-t1w_mode-image_xfm.mat

# Apply the resulting rigid transform to the DWI series
antsApplyTransforms -d 3 \
    -e 3 \
    -i ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-preproc_dwi.nii.gz \
    -o ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPCaligned_desc-preproc_dwi.nii.gz \
    -r ../anat/${SUBJECT_ID}_space-ACPC_desc-preproc_T1w.nii.gz \
    -t ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_from-dwiref_to-t1w_mode-image_xfm.mat \
    --float

# Apply the resulting rigid transform to the brain mask
antsApplyTransforms -d 3 \
    -e 3 \
    -i ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-brain_mask.nii.gz \
    -o ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPCaligned_desc-brain_mask.nii.gz \
    -r ../anat/${SUBJECT_ID}_space-ACPC_desc-preproc_T1w.nii.gz \
    -t ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_from-dwiref_to-t1w_mode-image_xfm.mat \
    --float

# Apply the resulting rigid transform to the Eddy CNR map
antsApplyTransforms -d 3 \
    -e 3 \
    -i ./dwi/${SUBJECT_ID}_${session}_space-ACPC_model-eddy_stat-cnr_dwimap.nii.gz \
    -o ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPCaligned_model-eddy_stat-cnr_dwimap.nii.gz \
    -r ../anat/${SUBJECT_ID}_space-ACPC_desc-preproc_T1w.nii.gz \
    -t ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_from-dwiref_to-t1w_mode-image_xfm.mat \
    --float

# Move old files to an original backup folder
mkdir -p orig
mv ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-preproc_dwi.nii.gz ./orig/
mv ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-brain_mask.nii.gz ./orig/
mv ./dwi/${SUBJECT_ID}_${session}_space-ACPC_dwiref.nii.gz ./orig/
mv ./dwi/${SUBJECT_ID}_${session}_space-ACPC_model-eddy_stat-cnr_dwimap.nii.gz ./orig/

# Move new files to the dwi folder, matching QSIPrep naming conventions for subsequent QSIRecon processing
mv ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPCaligned_desc-preproc_dwi.nii.gz ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-preproc_dwi.nii.gz
mv ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPCaligned_desc-brain_mask.nii.gz ./dwi/${SUBJECT_ID}_${session}_space-ACPC_desc-brain_mask.nii.gz
mv ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPCaligned_model-eddy_stat-cnr_dwimap.nii.gz ./dwi/${SUBJECT_ID}_${session}_space-ACPC_model-eddy_stat-cnr_dwimap.nii.gz
mv ./coreg_refine/${SUBJECT_ID}_${session}_space-ACPC_desc-masked_dwiref.nii.gz ./dwi/${SUBJECT_ID}_${session}_space-ACPC_dwiref.nii.gz

mv ./coreg_refine ${BIDS_DIR}/qsiprep_coreg_refine/${SUBJECT_ID}/${session}/
mv ./orig ${BIDS_DIR}/qsiprep_coreg_refine/${SUBJECT_ID}/${session}/

cd -
done