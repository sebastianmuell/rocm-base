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
GPLv3

## Project status
Not actively maintained.
