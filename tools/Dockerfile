# A toolchain of the vintage all five tools were written against.
#
# The host (Fedora 44: GCC 16, CMake 4.3, Python 3.14, protobuf 3.19 headers
# against a 7.x python package) is newer than CACTI, NVSim, Ramulator 2.0a and
# gem5 have ever been tested on. Nothing here is a Python problem, so a venv
# does not help; it is C++ compiler and CMake vintage. This pins all of it.
#
# Built and driven by tools/container.sh.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential g++-13 gcc-13 \
        git m4 scons cmake pkg-config \
        zlib1g-dev libprotobuf-dev protobuf-compiler libprotoc-dev \
        libgoogle-perftools-dev libboost-all-dev libhdf5-serial-dev \
        libpng-dev libelf-dev libcapstone-dev \
        python3 python3-dev python3-pip python3-venv \
        ngspice ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# GCC 13: new enough for Ramulator's C++20, old enough for gem5 and for the
# <cstdint> assumptions in the vendored yaml-cpp.
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100

# protobuf: keep the python package on the 3.x line so it matches the protoc
# that generates gem5's bindings. Avoids "Descriptors cannot not be created
# directly" in decode_packet_trace.py.
RUN pip3 install --break-system-packages --no-cache-dir \
        numpy matplotlib "protobuf<4"

# Run as the invoking user so files written to the mounted repo are owned by
# them, not by root. tools/container.sh passes --user.
WORKDIR /work
