# Use rocm dev image
FROM rocm/dev-ubuntu-24.04:latest

# Set env vars
ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++
ENV PYVENV=/usr/local/venv-pytorch
ENV PATH="/opt/rocm/llvm/bin:/opt/rocm/bin:$PYVENV/bin:$PATH"

# Set GPU specific env vars, preset RDNA 3.5 gfx1150 / gfx1151
# adjust as needed, list of GPUs supported by rocblas: https://github.com/ROCm/rocBLAS/blob/develop/library/src/handle.cpp#L81
ENV ROCM_ARCH=gfx1151
ENV HSA_OVERRIDE_GFX_VERSION=11.5.1
ENV FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
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
    libjpeg-dev \
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
    miopen-hip-gfx1*kdb \
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
    sudo \
    wget \
    && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /opt/rocm-*/ /opt/rocm && \
    git config --global user.email "gitlab@gitlab.local" && \
    git config --global user.name "gitlab bot"

# Set up venv & pytorch
RUN mkdir -p $PYVENV && python3 -m venv $PYVENV && \
    python3 -m pip install -U pip wheel setuptools --no-cache-dir && \
    python3 -m pip install -U asyncio ninja numpy==1.* numba onnx pybind11[global] pytest scipy tabulate transformers triton --no-cache-dir && \
    # Install nightly pytorch \
    python3 -m pip install -U --pre torch torchvision torchaudio numpy==1.* --index-url https://download.pytorch.org/whl/nightly/rocm"$(cat /opt/rocm/.info/version-dev | cut -d. -f1-2)"/ --no-cache-dir && \
    cp -n /opt/rocm/lib/rocblas/library/*$ROCM_ARCH* $PYVENV/lib/python3*/site-packages/torch/lib/rocblas/library/ && \
    # Install onnxruntime-rocm \
    python3 -m pip install -U onnxruntime-rocm triton numpy==1.* -f https://repo.radeon.com/rocm/manylinux/rocm-rel-"$(cat /opt/rocm/.info/version-dev | cut -d- -f1)"/ --no-cache-dir \
    || python3 -m pip install -U onnxruntime-rocm triton numpy==1.* -f https://repo.radeon.com/rocm/manylinux/rocm-rel-"$(cat /opt/rocm/.info/version-dev | cut -d. -f1-2)"/ --no-cache-dir && \
    bash -c "rm -rf /tmp/* /var/tmp/* /root/* /root/.[^.]*"

# Install rocm flash attention v2
RUN git clone https://github.com/ROCm/flash-attention.git flash-attention-v2 && \
    cd flash-attention-v2 && git checkout main_perf && git submodule update --init --recursive && \
    sed -i "s#versionstr\.decode(\*SUBPROCESS_DECODE_ARGS)\.strip()\.split(\x27\.\x27)#versionstr\.decode(\*SUBPROCESS_DECODE_ARGS)\.strip()\.split(\x27\.\x27)\n            version = re\.sub(\x27git\x27,\x27\x27, version)#g" /usr/local/venv-pytorch/lib/python3.12/site-packages/torch/utils/cpp_extension.py && \
    sed -i "s#\"gfx942\"\]#\"gfx942\", \"$ROCM_ARCH\"\]#g" setup.py && \
    FORCE_BUILD=true GPU_ARCHS=$ROCM_ARCH python3 -m pip install -v . && \
    cd .. && \
    bash -c "rm -rf flash-attention-v2 /tmp/* /var/tmp/* /root/* /root/.[^.]*"

CMD ["/bin/bash"]
