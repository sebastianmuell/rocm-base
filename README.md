# ROCm docker base-container with pytorch

Pytorch with ROCm support for accelerating inference on amd gpu.

## Build
docker build -t rocm-base .

## Usage
docker run -it --rm \
 -v /opt/llm-dl:/opt/llm-dl \
 --network=host \
 --device=/dev/kfd \
 --device=/dev/dri \
 --group-add=video \
 --group-add=render \
 --ipc=host \
 --security-opt seccomp=unconfined \
 rocm-base

## Contributing
Always welcome.

## Acknowledgment
ROCm Team - for maintaining rocm/dev-ubuntu-24.04 on docker hub

## License
This repository contains **custom configurations** (Dockerfile and GitLab CI files) licensed under **GPLv3**.

As with all Docker images, this image is built on top of other software that may be under different licenses:

- The **base Ubuntu image** includes software under various licenses (e.g., GPL, BSD, MIT).
- The **ROCm libraries** are included and subject to their own licenses (check `/opt/rocm/share/doc/<component-name>` for details).
- Various **Python pip packages** are included and subject to their own licenses (check each package's repository for details).

**As with any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with all relevant licenses for the software contained within.**

## Project status
Not actively maintained.
