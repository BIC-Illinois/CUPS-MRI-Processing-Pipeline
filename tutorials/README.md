# Tutorials and other resources for setting up, running, and using outputs of BIC MRI Procesing Pipelines



### Specific BIDS-Apps

# Usage for Apptainer Images

## Freesurfer

Use the freesurfer license.txt file located in this directory. 

If you need to run freesurfer on an existing BIDS directory, bind it to /data and run the bids-freesurfer.sif image.

To run commandline tools:
```
apptainer exec -B ./data:/data,/path/to/license.txt:/opt/freesurfer/license.txt bids-freesurfer.sif <fs_command>

```

To run recon-all longitudinal pipeline:

```
# projDir is the path to the project parent directory that contains the bids folder
# IMAGEDIR is the location of the apptainer images and the freesurfer license.txt file
# sub is the participant ID (does not need to include the "sub-" prefix)

apptainer run -B ${projDir}/bids/sourcedata:/bids_dataset,${projDir}/bids/derivatives/sourcedata/freesurfer:/outputs,${IMAGEDIR}/license.txt:/license.txt \
${IMAGEDIR}/bids-freesurfer.sif \
/bids_dataset /outputs participant --participant_label ${sub} \
--license_file "/license.txt" --stages all \
--multiple_sessions longitudinal --skip_bids_validator --n_cpus 8

```

To run freeview:

```
APPTAINER_ENVDISPLAY=${DISPLAY} apptainer exec -B ./data:/data,/tmp/.X11-unix:/tmp/.X11-unix,/path/to/license.txt:/opt/freesurfer/license.txt freeview-v7.1.1.sif freeview
```

## Lesion-Mapper-BIDS

UPDATE!
```
apptainer exec -B ./data:/data,/path/to/license.txt:/opt/freesurfer/license.txt lesion-mapper-bids.sif <example_command>
```

## MATLAB UBO Detector

Run the following container from the terminal and go through the steps shown in help_videos/Opening_UBO_Detector.mp4 to access the UBO Detector GUI

```
APPTAINER_ENVDISPLAY=$DISPLAY apptainer exec -B ./data:/data,/tmp/.X11-unix:/tmp/.X11-unix matlab-UBO.sif matlab
```

## To run FSLeyes:

```
APPTAINER_ENVDISPLAY=${DISPLAY} apptainer exec -B ./data:/data,/tmp/.X11-unix:/tmp/.X11-unix fsl-v6.0.1.sif fsleyes
```

## To run ITKsnap:

```
APPTAINER_ENVDISPLAY=${DISPLAY} apptainer run -B ./data:/data,/tmp/.X11-unix:/tmp/.X11-unix itksnap-4.0.1.sif
```

## To run DSI Studio:

```
APPTAINER_ENVDISPLAY=${DISPLAY} apptainer run -B ./data:/data,/tmp/.X11-unix:/tmp/.X11-unix dsi_studio-chen-2024-04-19.sif
```


### Other resources

* [Quick extraction of FreeSurfer stats to group-level .csv files](https://github.com/pcamach2/fs-data-utils)
* [QSM visual reports](https://github.com/pcamach2/qsm_method_comparison_report)
* [Python-based QC report HTML generator](https://github.com/mrfil/quality-control-reports)
