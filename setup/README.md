# Setup directions

To set up the pipeline from scratch on a new machine, select a base directory (e.g. /data/BICpipeline/) and run the `file_structure_gen.sh` file.

# Pre-requisites

## Containers
Apptainer (or Singularity if Apptainer is unavailable) must be installed. 
[Install Apptainer on Linux](https://apptainer.org/docs/admin/main/installation.html#installation-on-linux)

This should ideally be done by your system administrator. Otherwise, a portable version of Apptainer is available [here](https://apptainer.org/docs/admin/main/installation.html#install-unprivileged-from-pre-built-binaries).


## Licenses
For many portions of this pipeline, you will need a Freesurfer license obtained via registration [here](https://surfer.nmr.mgh.harvard.edu/registration.html).

[License for FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence)

## Common data

### TemplateFlow
Many BIDS-Apps rely on [TemplateFlow](https://www.templateflow.org/), which can be installed via pip on your host machine.
We typically use the version of TemplateFlow bundled with a given BIDS-App container,
so you can save time by downloading a local copy of the TemplateFlow data, either using python or datalad.

You can bind this local directory in an Apptainer `run` or `exec` command so that the data does not need to be fetched to a read-only file system.

```bash
# set the APPTAINERENV_TEMPLATEFLOW_HOME variable to the bind point
export APPTAINERENV_TEMPLATEFLOW_HOME=/templateflow
# bind the local copy when in the apptainer run command for your BIDS-App (replace "..." with your command)
apptainer run -B ../apptainer_images/templateflow:/templateflow ../apptainer_images/qsiprep-v0.19.1.sif ...
```

#### Python:

If you know which specific templates you need, you can save disk space by fetching those templates using
the [TemplateFlow python api](https://www.templateflow.org/python-client/master/notebooks/01_quickstart.html#Accessing-data).

For example, you can get the MNI152NLin6Asym template with 1mm isotropic voxel size using the following:

```python3
import templateflow.api as tflow

print(tflow.get(
    "MNI152NLin6Asym",
    desc=None,
    resolution=1,
    suffix="T1w"
))
```

#### Datalad:

If you have datalad installed on your host machine, you can fetch a local copy of all templateflow data:
```bash
datalad install -r ///templateflow
```

If you cannot install datalad, we provide an Apptainer definition file for building a datalad image.
```bash
# build datalad.sif
apptainer build --fakeroot datalad.sif datalad.def
apptainer exec -B ../:/dataout ../apptainer_images/datalad.sif bash -c "cd /dataout && datalad install -r ///templateflow"
```
