FROM ubuntu:20.04

COPY scripts/cross-apt-packages.sh /scripts/
RUN sh /scripts/cross-apt-packages.sh

COPY scripts/crosstool-ng-1.24.sh /scripts/
RUN sh /scripts/crosstool-ng-1.24.sh

COPY scripts/rustbuild-setup.sh /scripts/
RUN sh /scripts/rustbuild-setup.sh
USER rustbuild
WORKDIR /tmp

COPY host-x86_64/dist-s390x-linux/patches/ /tmp/patches/
COPY host-x86_64/dist-s390x-linux/s390x-linux-gnu.config host-x86_64/dist-s390x-linux/build-s390x-toolchain.sh /tmp/
RUN ./build-s390x-toolchain.sh

USER root

COPY scripts/sccache.sh /scripts/
RUN sh /scripts/sccache.sh

COPY scripts/cmake.sh /scripts/
RUN /scripts/cmake.sh

ENV PATH=$PATH:/x-tools/s390x-ibm-linux-gnu/bin

ENV \
    CC_s390x_unknown_linux_gnu=s390x-ibm-linux-gnu-gcc \
    AR_s390x_unknown_linux_gnu=s390x-ibm-linux-gnu-ar \
    CXX_s390x_unknown_linux_gnu=s390x-ibm-linux-gnu-g++

ENV HOSTS=s390x-unknown-linux-gnu

ENV RUST_CONFIGURE_ARGS --enable-extended --enable-lld --disable-docs
ENV SCRIPT python3 ../x.py dist --host $HOSTS --target $HOSTS
