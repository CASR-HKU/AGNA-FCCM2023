# AGNA-FCCM2023

Model-Platform Optimized Deep Neural Network Accelerator Generation through Mixed-integer Geometric Programming

## Introduction

AGNA is an open-source hardware generator for Deep Neural Network(DNN). Given the specifications of target DNN model and FPGA platform, AGNA can produce FPGA accelerator that is optimized for target model-platform combination. AGNA can be generally separated into software and hardware parts:

- Software: AGNA analyzes the specifications of each layer and solves mixed-integer geometric programming. AGNA first generates a high-efficiency accelerator based on a general PE array architecture. Then based on the generated accelerator, AGNA generates the schedule and instruction of each layer.
- Hardware: AGNA provides the synthesizable source code of each hardware component. The target accelerator can be built by substituting the parameter with the generated one from the software. A template project for zcu102 is also provided.

## Verified environment

- [SCIP](https://www.scipopt.org/) 8.0.3 with `TPI=omp` and [Ipopt](https://github.com/coin-or/Ipopt) 3.14.10
- Python 3.9
- Vivado 2021.2

## Usage

- Run in docker(Optional):
    
    We also provide a docker image that contains the necessary environment(except for Vivado). The image can be built by:

    ```bash
    docker build --build-arg HOST_UID=`id -u` --build-arg HOST_GID=`id -g` -t agna-local .
    ```

    Run docker image:

    ```bash
    docker run -it -v `pwd`:/home/user/workspace agna-local
    ```

    Current directory will be mounted to `/home/user/workspace` in the container.

- Run software:

    ```bash
    cd software
    export SCIPOPTDIR=<SCIPOPT_PATH>  # not required in docker
    conda env create --file environment.yml
    conda activate agna
    make all PLATFORM=<TARGET_PLATFORM> MODEL=<TARGET_MODEL>
    ```
    Make sure `<SCIPOPT_PATH>/bin/scip` is executable and specification files are available at `software/spec/platforms/<TARGET_PLATFORM>.json` and `software/spec/models/<TARGET_MODEL>.json`.
    
    Generated architecture and schedule are in `software/results/<TARGET_PLATFORM>-<TARGET_MODEL>`.

- Build hardware:

    ```bash
    cd hardware
    make all
    ```
    Generated project and bitstream are in `hardware/prj`.

## Build software environment from scratch

1. Prerequisite:

    ```bash
    sudo apt update
    sudo apt install -y wget cmake g++ m4 xz-utils libgmp-dev unzip zlib1g-dev libboost-program-options-dev libboost-serialization-dev libboost-regex-dev libboost-iostreams-dev libtbb-dev libreadline-dev pkg-config git liblapack-dev libgsl-dev flex bison libcliquer-dev gfortran file dpkg-dev libopenblas-dev rpm
    sudo apt install -y libopenmpi-dev libomp-dev
    ```

1. Build `Ipopt`:

    ```bash
    mkdir coinbrew && cd coinbrew
    wget https://raw.githubusercontent.com/coin-or/coinbrew/master/coinbrew
    chmod +x coinbrew
    ./coinbrew fetch Ipopt@3.14.10
    export IPOPT_DIR=/tools/Ipopt  # install directory of Ipopt, could be other places
    mkdir -p ${IPOPT_DIR}
    ./coinbrew build Ipopt --prefix=${IPOPT_DIR} --test --no-prompt --verbosity=3
    sudo ./coinbrew install Ipopt --no-prompt
    ```

1. Build `SCIPOpt`:

    - Download [scipoptsuite-8.0.3.tgz](https://scipopt.org/download.php?fname=scipoptsuite-8.0.3.tgz).

    - Install:

    ```bash
    tar xzf scipoptsuite-8.0.3.tgz
    cd scipoptsuite-8.0.3
    mkdir build && cd build
    export SCIPOPT_PATH=/tools/scipoptsuite-8.0.3 # install directory of SCIPOPT, could be other places
    cmake .. -DCMAKE_INSTALL_PREFIX=${SCIPOPT_PATH} -DIPOPT_DIR=${IPOPT_DIR} -DTPI=omp
    make
    make check
    make install
    ```
