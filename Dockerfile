# Use rocm dev image
FROM rocm/dev-ubuntu-24.04

# Set env vars
ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++
ENV PYVENV=/usr/local/venv-pytorch
ENV PATH="/opt/rocm/llvm/bin:/opt/rocm/bin:$PYVENV/bin:$PATH"

# Set GPU specific env vars, preset RDNA 3.5 gfx1150 / gfx1151
# adjust as needed, list of GPUs supported by rocblas: https://github.com/ROCm/rocBLAS/blob/develop/library/src/handle.cpp#L81
ENV PYTORCH_ROCM_ARCH=gfx1151
ENV AMDGPU_TARGETS=gfx1151
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
    espeak-ng \
    ffmpeg \
    git \
    half \
    hip-dev \
    hip-doc \
    hip-samples \
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
    libomp-dev \
    libopenblas-dev \
    libopenmpi-dev \
    libprotobuf-dev \
    libsm6 \
    libsndfile1-dev \
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
    software-properties-common \
    subversion \
    sudo \
    tesseract-ocr \
    wget \
    && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Set up venv & pytorch
RUN mkdir -p $PYVENV && python3 -m venv $PYVENV && echo "/usr/local/venv-pytorch/lib" > /etc/ld.so.conf.d/11-python-venv.conf && ldconfig && \
    python3 -m pip install -U pip wheel setuptools --no-cache-dir && \
    python3 -m pip install -U ninja transformers onnx asyncio numpy==1.* pybind11[global] tabulate --no-cache-dir && \
    # Install nightly pytorch \
    python3 -m pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm"$(cat /opt/rocm/.info/version-dev | cut -d. -f1-2)" --no-cache-dir && \
    cp /opt/rocm/lib/rocblas/library/*$AMDGPU_TARGETS* $PYVENV/lib/python3*/site-packages/torch/lib/rocblas/library/ && \
    # Install onnxruntime-rocm \
    python3 -m pip install onnxruntime-rocm -f https://repo.radeon.com/rocm/manylinux/rocm-rel-"$(cat /opt/rocm/.info/version-dev | cut -d- -f1)"/ --no-cache-dir && \
    bash -c "rm -rf /tmp/* /var/tmp/* /root/* /root/.[^.]*"

# Install torch_migraphx
RUN git clone https://github.com/ROCmSoftwarePlatform/torch_migraphx.git && \
    cd ./torch_migraphx/py && \
    TORCH_CMAKE_PATH="$(python -c 'import torch; print(torch.utils.cmake_prefix_path)')" python3 -m pip install -v . && \
    cd ../../ && \
    bash -c "rm -rf torch_migraphx/ /tmp/* /var/tmp/* /root/* /root/.[^.]*"

# Install rocm flash attention v2
RUN git clone https://github.com/ROCm/flash-attention.git flash-attention-v2 && \
    cd flash-attention-v2 && git submodule update --init --recursive && \
    # pin to 2.7 to avoid compile issues for version 3.0 concerning undefined CK_TILE_BUFFER_RESOURCE_3RD_DWORD \
    git checkout v2.7.3-cktile && \
    sed -i "s#versionstr\.decode(\*SUBPROCESS_DECODE_ARGS)\.strip()\.split(\x27\.\x27)#versionstr\.decode(\*SUBPROCESS_DECODE_ARGS)\.strip()\.split(\x27\.\x27)\n            version = re\.sub(\x27git\x27,\x27\x27, version)#g" /usr/local/venv-pytorch/lib/python3.12/site-packages/torch/utils/cpp_extension.py && \
    sed -i "s#\"gfx942\"\]#\"gfx942\", \"$AMDGPU_TARGETS\"\]#g" setup.py && \
    FORCE_BUILD=true GPU_ARCHS=$AMDGPU_TARGETS python3 -m pip install -v . && \
    cd .. && \
    bash -c "rm -rf flash-attention-v2 /tmp/* /var/tmp/* /root/* /root/.[^.]*"

CMD ["/bin/bash"]
