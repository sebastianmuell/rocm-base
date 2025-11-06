# Use rocm dev image
FROM rocm/dev-ubuntu-24.04:latest

# Set env vars
ENV DEBIAN_FRONTEND=noninteractive
ENV CC=amdclang
ENV CXX=amdclang++
ENV PYVENV=/usr/local/venv-pytorch
ENV PATH="/opt/rocm/llvm/bin:/opt/rocm/bin:$PYVENV/bin:$PATH"
ARG PARALLEL=8

# Set GPU specific env vars, preset RDNA 3.5 gfx1150
# adjust as needed, list of GPUs supported by rocblas: https://github.com/ROCm/rocBLAS/blob/develop/library/src/handle.cpp#L81
ENV ROCM_ARCH=gfx1150
ENV PYTORCH_ROCM_ARCH=gfx1150
ENV HSA_OVERRIDE_GFX_VERSION=11.5.0
ENV FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
ENV FLASH_ATTENTION_TRITON_AMD_AUTOTUNE=TRUE
ENV TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# Set workdir
WORKDIR /root

# Install and update tools - are all of these really necessary?
RUN apt-get update -qqy && apt-get dist-upgrade -qqy && apt-get install -qqy \    
    amd-smi-lib \
    apt-utils \
    bzip2 \
    ca-certificates \
    cmake \
    cmake-curses-gui \
    ffmpeg \
    git \
    golang \
    half \
    hip-dev \
    hipblas-dev \
    hipblaslt-dev \
    hipcc \
    hipcub-dev \
    hipfft-dev \
    hipfort-dev \
    hipify-clang \
    hiprand-dev \
    hipsolver-dev \
    hipsparse-dev \
    hiptensor-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libglib2.0-0 \
    libhsakmt-dev \
    libhsa-runtime-dev \
    libjpeg-dev \
    libmsgpack-dev \
    libomp-dev \
    libopenblas-dev \
    libopenmpi-dev \
    libpng-dev \
    libprotobuf-dev \
    libsm6 \
    libsndfile1-dev \
    libtbb-dev \
    libxext6 \
    libxrender1 \
    llvm \
    mercurial \
    mesa-common-dev \
    migraphx \
    miopen-hip-dev \
    patchelf \
    protobuf-compiler \
    python3 \
    python3-argcomplete \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-yaml \
    rccl-dev \
    rocblas-dev \
    rocm-cmake \
    rocm-dbgapi \
    rocm-debug-agent \
    rocm-developer-tools \
    rocm-gdb \
    rocm-hip-runtime \
    rocm-hip-runtime-dev \
    rocm-hip-sdk \
    rocm-llvm-dev \
    rocm-opencl \
    rocm-opencl-dev \
    rocm-opencl-runtime \
    rocm-opencl-sdk \
    rocm-openmp-sdk \
    rocm-utils \
    rocprofiler \
    rocprofiler-dev \
    rocprofiler-plugins \
    rocprofiler-sdk \
    rocrand-dev \
    rocsparse-dev \
    rocthrust-dev \
    roctracer-dev \
    rocwmma-dev \
    rpp \
    rpp-dev \
    rsync \
    software-properties-common \
    subversion \
    wget \
    && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    test -d /opt/rocm || ln -s /opt/rocm-* /opt/rocm && \
    git config --global user.email "gitlab@gitlab.local" && \
    git config --global user.name "gitlab bot"

# Install rocblas from source
RUN <<'EOD'
set -eux
git clone --single-branch --depth=1 https://github.com/ROCm/rocm-libraries.git -b "release/rocm-rel-$(cat /opt/rocm/.info/version | cut -d. -f1-2)" /tmp/rocmlibs
cd /tmp/rocmlibs/projects/rocblas/
# Rewrite version to match installed, avoiding apt dependency issues
INSTALLED=$(apt-cache policy rocblas | awk '/Installed:/ {print $2}')
VERSION_BASE=$(echo $INSTALLED | cut -d- -f1)
VERSION_PATCH=$(echo $VERSION_BASE | cut -d. -f3-4)
VERSION_TWEAK=$(echo $INSTALLED | cut -d- -f2)
cat > update_version.sed << EOF
/^set ( VERSION_STRING "\(.*\)" )/ {
    c\\
set ( VERSION_STRING "$VERSION_BASE" )\\
rocm_setup_version( VERSION \\\${VERSION_STRING} NO_GIT_TAG_VERSION )\\
set (PROJECT_VERSION_PATCH "$VERSION_PATCH")\\
set (\\\${PROJECT_NAME}_VERSION_PATCH "$VERSION_PATCH")\\
set (PROJECT_VERSION_TWEAK "$VERSION_TWEAK")\\
set (\\\${PROJECT_NAME}_VERSION_TWEAK "$VERSION_TWEAK")
}
/^rocm_setup_version( VERSION \\\${VERSION_STRING} )\$/d
EOF
sed -i -f update_version.sed CMakeLists.txt
# Compile and install rocblas
./install.sh -ida ${ROCM_ARCH} -j ${PARALLEL}
# Mark rocblas as hold to avoid apt updates
apt-mark hold rocblas rocblas-dev
rm -rf /tmp/* /var/tmp/*
EOD

# Set up python venv
RUN mkdir -p $PYVENV && python3 -m venv $PYVENV && \
    # Install prerequisites
    python3 -m pip install -U pip wheel setuptools --no-cache-dir && \
    python3 -m pip install -U asyncio coloredlogs einops flatbuffers jinja2 networkx ninja numpy==1.* numba onnx packaging pillow pybind11[global] pytest scipy sympy tabulate transformers --no-cache-dir && \
    # Install packages \
    python3 -m pip install -U --pre onnxruntime-migraphx torch torchvision torchaudio triton numpy==1.* -f https://repo.radeon.com/rocm/manylinux/rocm-rel-"$(cat /opt/rocm/.info/version | cut -d- -f1)"/ --index-url https://download.pytorch.org/whl/rocm"$(cat /opt/rocm/.info/version | cut -d. -f1-2)"/ --no-cache-dir \
    ||  python3 -m pip install -U --pre onnxruntime-migraphx torch torchvision torchaudio triton numpy==1.* -f https://repo.radeon.com/rocm/manylinux/rocm-rel-"$(cat /opt/rocm/.info/version | cut -d- -f1)"/ --index-url https://download.pytorch.org/whl/nightly/rocm"$(cat /opt/rocm/.info/version | cut -d. -f1-2)"/ --no-cache-dir \
    ||  python3 -m pip install -U --pre onnxruntime-migraphx torch torchvision torchaudio triton numpy==1.* -f https://repo.radeon.com/rocm/manylinux/rocm-rel-"$(cat /opt/rocm/.info/version | cut -d. -f1-2)"/ --index-url https://download.pytorch.org/whl/nightly/rocm"$(cat /opt/rocm/.info/version | cut -d. -f1-2)"/ --no-cache-dir && \
    ( test -d $PYVENV/lib/python3*/site-packages/torch/lib/rocblas/library/ && cp --update=none /opt/rocm/lib/rocblas/library/*$ROCM_ARCH* $PYVENV/lib/python3*/site-packages/torch/lib/rocblas/library/ ) || true && \
    rm -rf /tmp/* /var/tmp/*

# Install rocm flash attention
RUN git clone --single-branch --depth=1 https://github.com/ROCm/flash-attention.git -b main_perf flash-attention && \
    cd flash-attention && \
    sed -i "s#\"gfx942\"\]#\"gfx942\", \"$ROCM_ARCH\"\]#g" setup.py && \
    GPU_ARCHS=$ROCM_ARCH FLASH_ATTENTION_SKIP_CUDA_BUILD=TRUE python3 setup.py install && \
    cd .. && \
    rm -rf flash-attention /tmp/* /var/tmp/*

CMD ["/bin/bash"]
