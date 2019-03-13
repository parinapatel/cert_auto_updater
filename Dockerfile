FROM ubuntu:18.04
# RUN rm -rf /etc/yum.repos.d/*
# COPY DRNIcentos7.repo /etc/yum.repos.d/DRNIcentos7.repo
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && apt upgrade -y  && apt install -y software-properties-common \
 && add-apt-repository ppa:certbot/certbot && apt update && apt install -y  certbot python3-certbot-dns-route53 git curl jq \
    && curl https://artifacts.aunalytics.com/toolbelt/Toolbelt-latest/aunsight-toolbelt2-linux -o /usr/bin/au2 \
    && chmod +x /usr/bin/au2 \
    && mkdir -p /home/user/.ssh \
    # && apt-get autoremove -y software-properties-common  \
    && rm -rf /var/lib/apt \
    && apt clean all
WORKDIR /home/user
COPY run.sh /home/user/run.sh
COPY start.sh /home/user/start.sh
CMD [ "/home/user/start.sh" ]
