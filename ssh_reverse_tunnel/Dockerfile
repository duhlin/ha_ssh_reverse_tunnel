ARG BUILD_FROM
FROM $BUILD_FROM

# Use ash with pipefail for safer scripting
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    AUTOSSH_GATETIME=0 \
    AUTOSSH_LOGLEVEL=0 \
    AUTOSSH_FIRST_POLL=30 \
    AUTOSSH_POLL=60

# Install only needed tools
RUN apk add --no-cache \
      openssh-client \
      autossh \
      jq && \
    mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Copy runtime script
COPY run.sh /run.sh
RUN chmod 755 /run.sh

# Minimal health check (optional: verify autossh binary exists)
HEALTHCHECK CMD [ -x /usr/bin/autossh ] || exit 1

# Run under s6 if provided by base, else just execute
CMD ["/run.sh"]
