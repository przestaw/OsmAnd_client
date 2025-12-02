# Docker Build Environment

A Docker build environment intended to make a local build easier.
Dockerfile based loosely on F-Droid runner setup.

Caveat: these are rough instructions, not intended to be robust, but to help guide a build. You may have to inspect and edit some of the scripts.

For a build that includes all flavours (`fat`), you need approximately 75 GB of free disk space.
If you are building only a single flavour (for example `arm64`), about 28 GB should be sufficient.

## Setup

Install docker, then build the image from the directory containing the Dockerfile:

    $ docker build -t local/osmand .

Then run a shell in the container. Create an external volume with `-v` so that the build results are available outside of the container.
Replace `/local/path/to/volume` with whichever directory you want.

    $ docker run -it --rm \
        --name osmand \
        -v /local/path/to/volume:/mnt/volume local/osmand \
        /bin/bash

Make sure that the user `vagrant` (UID `1000`) from the Docker image has the appropriate access rights to this directory, in case the local user has a different UID. For example, you can use:

    $ chown 1000:1000 /local/path/to/volume

or

    $ setfacl -m u:1000:rwx,g:1000:rwx /local/path/to/volume

Once inside the container, you can use the `setup-volume.sh` script to initialise the build directory. This will download the basic source code.

    % cd /mnt/volume
    % setup-volume.sh

Next, in the OsmAnd-submodules directory, run the prebuild script with the OsmAnd version you're building. E.g.

    % ./prebuild.sh "5.2.13" "5213" arm64

The final argument can be one of `armv7`, `x86`, `arm64` or empty for all flavours.

## Build

Then build the external deps with the arch parameter if you used one for the prebuild (be consistent, else the OpenGL renderer probably won't work).

    % ./build.sh arm64

Finally, to build OsmAnd, cd to the app directory and compile.

    % cd android/OsmAnd
    % gradle assembleAndroidFullOpenglArm64Release

Change `Arm64` for `Armv7` or `X86` or `Fat` (all flavours) as required.

In total, the process takes about 2.5 hours on my machine.

You can find the APK in `build/ouputs/...../Osmand-...-release.apk`.
