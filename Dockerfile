FROM postgres:9.6

RUN chown root:postgres /usr/local/bin/gosu && chmod +s /usr/local/bin/gosu

RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-transport-https inetutils-ping iproute && \
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
