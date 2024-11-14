#!/bin/bash 

# Freeview version 7.1.1
apptainer build freeview-v7.1.1.sif docker://fnndsc/freesurfer:freeview

# DSI Studio
apptainer build dsi_studio-chen-2024-04-19.sif docker://dsistudio/dsistudio:chen-2024-04-19

# ITK-snap
apptainer build itksnap-4.0.1.sif itksnap.def
