FROM scratch
ARG WASM_BINARY
WORKDIR /
COPY $WASM_BINARY /plugin.wasm
