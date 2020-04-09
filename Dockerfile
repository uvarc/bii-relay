FROM python:alpine
RUN apk add --no-cache git tzdata jq curl openssh-client && \
    pip install --upgrade awscli python-magic

# RUN apk add --no-cache git jq curl tzdata openssh-client
ENV TZ America/New_York

RUN mkdir /root/.ssh && chmod 600 /root/.ssh
COPY run.sh /run.sh

WORKDIR /root

# ENTRYPOINT ["/run.sh"]
