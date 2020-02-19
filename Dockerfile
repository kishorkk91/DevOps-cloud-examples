FROM debian:9-slim

LABEL maintainer = kishor.kotule@team.com

# In order to call https core service
RUN apt-get update
RUN apt-get install -y ca-certificates

# add a new user to run the application.
RUN adduser --home /home/app --uid 1000 --disabled-password --shell /bin/bash app
WORKDIR /home/app

# copy data to container.
ADD MyApplication ./
ADD version ./
ADD vendor/gitlab.team.de/go-utils/appdynamics/sdk_lib/lib/libappdynamics.so ./
ADD vendor/gitlab.team.de/go-utils/appdynamics/ca-bundle.crt ./
ENV APPDYNAMICS_CONTROLLER_CERTIFICATE_DIR=/home/app
ENV APPDYNAMICS_CONTROLLER_CERTIFICATE_FILE=ca-bundle.crt
ENV APPDYNAMICS_AGENT_LOG_DIR=/home/app
ENV LD_LIBRARY_PATH=/home/app

RUN chown -R app:app /home/app

# expose service port.
EXPOSE 8080

# run application with user "app".
USER app
ENTRYPOINT ["./MyApplication"]