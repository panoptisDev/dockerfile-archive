FROM jetty:9-jre8-openjdk

ENV DATA_DIR /catalogue-data
ENV JAVA_OPTS -Dorg.eclipse.jetty.annotations.AnnotationParser.LEVEL=OFF \
        -Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true \
        -Xms512M -Xss512M -Xmx2G -XX:+UseConcMarkSweepGC \
        -Dgeonetwork.resources.dir=${DATA_DIR}/resources \
        -Dgeonetwork.data.dir=${DATA_DIR} \
        -Dgeonetwork.codeList.dir=/var/lib/jetty/webapps/geonetwork/WEB-INF/data/config/codelist \
        -Dgeonetwork.schema.dir=/var/lib/jetty/webapps/geonetwork/WEB-INF/data/config/schema_plugins 

USER root
RUN apt-get -y update && \
    apt-get -y install curl && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /${DATA_DIR} && \
    chown -R jetty:jetty ${DATA_DIR} && \
    mkdir -p /var/lib/jetty/webapps/geonetwork && \
    chown -R jetty:jetty /var/lib/jetty/webapps/geonetwork

USER jetty
ENV GN_FILE geonetwork.war
ENV GN_VERSION 4.0.6
ENV GN_DOWNLOAD_MD5 793732cb9c723e73857a4da73b78451b

RUN cd /var/lib/jetty/webapps/geonetwork/ && \
     curl -fSL -o geonetwork.war \
     https://sourceforge.net/projects/geonetwork/files/GeoNetwork_opensource/v${GN_VERSION}/${GN_FILE}/download && \
     echo "${GN_DOWNLOAD_MD5} *geonetwork.war" | md5sum -c && \
     unzip -q geonetwork.war && \
     rm geonetwork.war 

COPY ./docker-entrypoint.sh /geonetwork-entrypoint.sh
ENTRYPOINT ["/geonetwork-entrypoint.sh"]
CMD ["java","-jar","/usr/local/jetty/start.jar"]

VOLUME [ "${DATA_DIR}" ]
