#
# Copyright 2022 Apollo Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Dockerfile for apollo-portal
# 1. ./scripts/build.sh
# 2. Build with: mvn docker:build -pl apollo-portal
# 3. Run with: docker run -p 8070:8070 -e SPRING_DATASOURCE_URL="jdbc:mysql://fill-in-the-correct-server:3306/ApolloPortalDB?characterEncoding=utf8" -e SPRING_DATASOURCE_USERNAME=FillInCorrectUser -e SPRING_DATASOURCE_PASSWORD=FillInCorrectPassword -e APOLLO_PORTAL_ENVS=dev,pro -e DEV_META=http://fill-in-dev-meta-server:8080 -e PRO_META=http://fill-in-pro-meta-server:8080 -d -v /tmp/logs:/opt/logs --name apollo-portal apolloconfig/apollo-portal

FROM openjdk:8-jre-alpine
LABEL maintainer="finchcn@gmail.com;ameizi<sxyx2008@163.com>"

RUN echo "http://mirrors.aliyun.com/alpine/v3.8/main" > /etc/apk/repositories \
    && echo "http://mirrors.aliyun.com/alpine/v3.8/community" >> /etc/apk/repositories \
    && apk update upgrade \
    && apk add --no-cache unzip

ARG VERSION
ENV VERSION $VERSION

COPY apollo-portal-${VERSION}-github.zip /apollo-portal/apollo-portal-${VERSION}-github.zip

RUN unzip /apollo-portal/apollo-portal-${VERSION}-github.zip -d /apollo-portal \
    && rm -rf /apollo-portal/apollo-portal-${VERSION}-github.zip \
    && chmod +x /apollo-portal/scripts/startup.sh

FROM openjdk:8-jre-alpine
LABEL maintainer="finchcn@gmail.com;ameizi<sxyx2008@163.com>"

ENV APOLLO_RUN_MODE "Docker"
ENV SERVER_PORT 8070

RUN echo "http://mirrors.aliyun.com/alpine/v3.8/main" > /etc/apk/repositories \
    && echo "http://mirrors.aliyun.com/alpine/v3.8/community" >> /etc/apk/repositories \
    && apk update upgrade \
    && apk add --no-cache procps curl bash tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

COPY --from=0 /apollo-portal /apollo-portal

EXPOSE $SERVER_PORT

CMD ["/apollo-portal/scripts/startup.sh"]
