FROM yuhaoding/agna:latest
ENV SCIPOPTDIR=/tools/scipoptsuite-8.0.3
ARG HOST_UID
ARG HOST_GID
RUN groupadd -g ${HOST_GID} user && \
    useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash user
USER user
RUN /opt/anaconda3/bin/conda init
WORKDIR /home/user/workspace