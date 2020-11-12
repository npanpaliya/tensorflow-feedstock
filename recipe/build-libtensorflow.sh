# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2018, 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************
#!/bin/bash

set -vex

# Build Tensorflow from source
SCRIPT_DIR=$RECIPE_DIR/../buildscripts

# expand PREFIX in BUILD file - PREFIX is from conda build environment
sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

echo "CUDA_HOME: $CUDA_HOME"
exit 1

# Pick up additional variables defined from the conda build environment
$SCRIPT_DIR/set_python_path_for_bazelrc.sh $SRC_DIR/tensorflow
if [[ $build_type == "cuda" ]]
then
  # Pick up the CUDA and CUDNN environment
  $SCRIPT_DIR/set_tensorflow_nvidia_bazelrc.sh $SRC_DIR/tensorflow
fi
# Build the bazelrc
$SCRIPT_DIR/set_tensorflow_bazelrc.sh $SRC_DIR/tensorflow

#Clean up old bazel cache to avoid problems building TF
bazel clean --expunge
bazel shutdown

bazel --bazelrc=$SRC_DIR/tensorflow/tensorflow.bazelrc build \
    --config=opt \
    --config=numa \
    --curses=no \
    //tensorflow/tools/lib_package:libtensorflow \
    //tensorflow:install_headers \


# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
tar -C ${SP_DIR}/tensorflow -xzf bazel-bin/tensorflow/tools/lib_package/libtensorflow.tar.gz

echo "PREFIX: $PREFIX"
echo "RECIPE_DIR: $RECIPE_DIR"

#
# Include libtensorflow shared libraries
#
# Copy complete headers for libtensorflow C/C++ API
mkdir -p "${SP_DIR}/tensorflow/include/tensorflow/cc"
mkdir -p "${SP_DIR}/tensorflow/include/tensorflow/c"
mkdir -p "${SP_DIR}/tensorflow/include/tensorflow/cc/ops"

cd ./tensorflow/cc
cp --parents `find -name \*.h*` "${SP_DIR}/tensorflow/include/tensorflow/cc"

cd ../c
cp --parents `find -name \*.h*` "${SP_DIR}/tensorflow/include/tensorflow/c"

cd ../../
cp -R "bazel-bin/tensorflow/cc/ops/"*.h  "${SP_DIR}/tensorflow/include/tensorflow/cc/ops"

TF_MAJOR_VERSION=${PKG_VERSION:0:1}
echo "TF_MAJOR_VERSION: $TF_MAJOR_VERSION"

#Create sym link for libtensorflow_framework
ln -s ${SP_DIR}/tensorflow/libtensorflow_framework.so.[0-9] "${SP_DIR}/tensorflow/libtensorflow_framework.so"
ln -s ${SP_DIR}/tensorflow/libtensorflow.so "${SP_DIR}/tensorflow/libtensorflow.so.${TF_MAJOR_VERSION}"
ln -s ${SP_DIR}/tensorflow/libtensorflow_cc.so "${SP_DIR}/tensorflow/libtensorflow_cc.so.${TF_MAJOR_VERSION}"

# Install the activate / deactivate scripts that set environment variables
mkdir -p "${PREFIX}"/etc/conda/activate.d
mkdir -p "${PREFIX}"/etc/conda/deactivate.d
cp "${RECIPE_DIR}"/../scripts/activate.sh "${PREFIX}"/etc/conda/activate.d/activate-${PKG_NAME}.sh
cp "${RECIPE_DIR}"/../scripts/deactivate.sh "${PREFIX}"/etc/conda/deactivate.d/deactivate-${PKG_NAME}.sh

bazel clean --expunge
bazel shutdown
