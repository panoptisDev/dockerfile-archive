FROM ubuntu:16.04 as base

ENV USER user
ENV HOME /home/$USER
ENV GOPATH $HOME/work

RUN apt-get -qq update && apt-get --no-install-recommends -qq -y install ca-certificates curl git
RUN GO=go1.11.2.linux-amd64.tar.gz && curl -sL --retry 10 --retry-delay 60 -O https://dl.google.com/go/$GO && tar -xzf $GO -C /usr/local
RUN /usr/local/go/bin/go get -tags=no_env github.com/peterq/pan-light/qt/cmd/...

RUN apt-get -qq update && apt-get --no-install-recommends -qq -y install dbus fontconfig libx11-6 libx11-xcb1
RUN QT=qt-unified-linux-x64-online.run && curl -sL --retry 10 --retry-delay 60 -O https://download.qt.io/official_releases/online_installers/$QT && chmod +x $QT && QT_QPA_PLATFORM=minimal ./$QT --script $GOPATH/src/github.com/peterq/pan-light/qt/internal/ci/iscript.qs LINUX=true
RUN find /opt/Qt/5.12.0 -type f -name "*.debug" -delete
RUN find /opt/Qt/Docs -type f ! -name "*.index" -delete
RUN find /opt/Qt/5.12.0/gcc_64 -type f ! -name "*.a" -name "lib*" -exec strip -s {} \;


FROM ubuntu:16.04
LABEL maintainer therecipe

ENV USER user
ENV HOME /home/$USER
ENV GOPATH $HOME/work
ENV PATH /usr/local/go/bin:$PATH
ENV QT_DIR /opt/Qt
ENV QT_DOCKER true


COPY --from=base /usr/local/go /usr/local/go
COPY --from=base $GOPATH/bin $GOPATH/bin
COPY --from=base $GOPATH/src/github.com/peterq/pan-light/qt $GOPATH/src/github.com/peterq/pan-light/qt
COPY --from=base /opt/Qt/5.12.0 /opt/Qt/5.12.0
COPY --from=base /opt/Qt/Docs /opt/Qt/Docs
COPY --from=base /opt/Qt/Licenses /opt/Qt/Licenses

RUN apt-get -qq update && apt-get --no-install-recommends -qq -y install build-essential libglib2.0-dev libglu1-mesa-dev libpulse-dev \
 && apt-get --no-install-recommends -qq -y install fontconfig libasound2 libegl1-mesa libnss3 libpci3 libxcomposite1 libxcursor1 libxi6 libxrandr2 libxtst6 && apt-get -qq clean

RUN $GOPATH/bin/qtsetup prep
RUN $GOPATH/bin/qtsetup check
RUN $GOPATH/bin/qtsetup generate
RUN cd $GOPATH/src/github.com/peterq/pan-light/qt/internal/examples/widgets/line_edits && $GOPATH/bin/qtdeploy build linux && rm -rf ./deploy
