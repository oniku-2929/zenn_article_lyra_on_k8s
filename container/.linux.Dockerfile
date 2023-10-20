from ghcr.io/epicgames/unreal-engine:runtime

ARG USERNAME=ue4
ARG GROUPNAME=ue4
ARG UID=1000
ARG GID=1000
ARG PROJECT_NAME="LyraStarterGame"
ARG PACKAGE_DIR="Debug"
ARG TAG="debug"

ENV TAG=${TAG}
ENV PROJECT_NAME=${PROJECT_NAME}

COPY ./${PACKAGE_DIR}/LinuxServer /home/ue4/LinuxServer
COPY ./config /home/ue4/LinuxServer/Config

WORKDIR /home/ue4/LinuxServer
ENTRYPOINT [ "/home/ue4/LinuxServer/LyraServer.sh"]
CMD [ "-log" ]
