import os


def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes


def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """

    mp2rage_inv1 = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-mp2rageinv_run-1_T1w') 
    mp2rage_inv2 = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-mp2rageinv_run-2_T1w')
    mp2rage_uni = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-mp2rageuni_run-3_T1w')
    FLAIR = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_FLAIR') 
    dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_run-{item:01d}_dwi')
    rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-{dir}_run-{item:01d}_bold')
    fmap_fmri = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-fMRIrest_dir-{dir}_run-{item:01d}_epi')
    fmap_dwi = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-dwi_dir-{dir}_run-{item:01d}_epi')
    #fmap_tfmri = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-{acq}_dir-{dir}_run-{item:01d}_epi')
    highreship = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-highreshippocampus_run-{item:01d}_T2w')
    highreshipt2star = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-highreshippocampus_run-{item:01d}_T2starw')
    rest_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-PA_run-1_sbref')
    tfunc = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-{task}_dir-PA_run-{item:01d}_bold')
    #swi = create_key('derivatives/sub-{subject}/{session}/swi/sub-{subject}_{session}_dir-PA_run-{item:01d}_t2star')
    b1dream = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-DREAM_run-1_RB1map')
    
    info = {mp2rage_inv1: [], mp2rage_inv2: [], mp2rage_uni: [], dwi: [], FLAIR: [], rest: [], rest_sbref: [], fmap_fmri: [], highreship: [], highreshipt2star: [], fmap_dwi: [], tfunc: [], b1dream: []} 
   
    for s in seqinfo:
        if ('t1_mp2rage' or '7Tmp2rage' in s.series_id) and not(s.is_derived) and ('_INV1' in s.series_description) and ('COLLECTION' not in s.protocol_name) and ('flair' not in s.series_id):
            info[mp2rage_inv1] = [s.series_id]
        if ('t1_mp2rage' or '7Tmp2rage' in s.series_id) and not(s.is_derived) and ('_INV2' in s.series_description) and ('COLLECTION' not in s.protocol_name) and ('flair' not in s.series_id):
            info[mp2rage_inv2] = [s.series_id]
        if ('t1_mp2rage' or '7Tmp2rage' in s.series_id) and ('_UNI_' in s.series_description) and (s.is_derived) and ('COLLECTION' not in s.protocol_name) and ('flair' not in s.series_id):
            info[mp2rage_uni] = [s.series_id]
        if (('dwi_acq' in s.series_description) or ('dwi' in s.protocol_name)) and not(s.is_derived) and ('DREAM' not in s.series_id) and ('func' not in s.series_id) and (s.dim4 > 60):
            info[dwi].append({'item': s.series_id}) # append if multiple series meet criteria
        if ('DTI' in s.series_description) and ('fmap' in s.series_id) and ('rest' not in s.series_description) and ('fMRI' not in s.series_description):
            if ('-AP' in s.protocol_name):
                info[fmap_dwi].append({'item': s.series_id, 'dir': 'AP'})
            else:
                info[fmap_dwi].append({'item': s.series_id, 'dir': 'PA'})
        if ('flair' in s.protocol_name) and ('cmrr' and 'mp2rage' and 'b1' and 'tse' not in s.protocol_name):
            info[FLAIR] = [s.series_id]
        if (s.dim4 > 10) and ('rest' or 'REST_PA' in s.protocol_name) and ('diff' not in s.protocol_name) and ('DTI' not in s.protocol_name) and ('SBRef' not in s.series_description) and (s.dim4 > 300):
            if ('-AP' in s.protocol_name):
                info[rest].append({'item': s.series_id, 'dir': 'AP'})
            else:
                info[rest].append({'item': s.series_id, 'dir': 'PA'})
        if ('SBRef' in s.series_id) and ('rest' or 'REST_PA' in s.protocol_name) and ('fmap' not in s.series_description) and ('cmrr' not in s.series_id):
            info[rest_sbref] = [s.series_id]
        if ('fmap' in s.protocol_name) and ('rest' in s.protocol_name) and ('DTI' not in s.protocol_name):
            if ('AP' in s.protocol_name):
                info[fmap_fmri].append({'item': s.series_id, 'dir': 'AP'})
            else:
                info[fmap_fmri].append({'item': s.series_id, 'dir': 'PA'})
        if ('t2' or 'T2' in s.protocol_name) and ('anat-T2w_acq-7Thighreshippocampus' in s.protocol_name):
            info[highreship].append({'item': s.series_id})
        if ('anat-T2starw_acq-7ThighreshippocampusNew' in s.protocol_name) and (s.image_type==('ORIGINAL', 'PRIMARY', 'M', 'DIS2D')):
            info[highreshipt2star].append({'item': s.series_id})
        if ('Dream' or 'DREAM' in s.protocol_name) and ('flair' or 'FLAIR' not in s.protocol_name) and ('highreshippo' not in s.protocol_name) and ('7Tmp2ragep75iso' not in s.protocol_name) and (s.dim4 == 1) and ('TB1map' in s.protocol_name):
            info[b1dream].append({'item': s.series_id})
    return info

