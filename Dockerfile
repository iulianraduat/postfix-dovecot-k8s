# Use an official Ubuntu base image
FROM ubuntu:20.04

# Set environment variables to avoid interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# Update and install necessary packages
RUN apt-get update && \
    apt-get install -y dos2unix postfix dovecot-imapd && \
    apt-get clean
RUN cp -f /etc/postfix/master.cf /etc/postfix/master.dist.cf

# Copy configuration files
COPY postfix/main.cf /etc/postfix/main.dist.cf
COPY dovecot/dovecot.conf /etc/dovecot/dovecot.dist.conf

# Setup the setup (needed by setup.sh)
RUN mkdir -p /opt/postfix-dovecot
COPY postfix/virtual_mailbox_maps /opt/postfix-dovecot/virtual_mailbox_maps
COPY postfix/virtual_alias_maps /opt/postfix-dovecot/virtual_alias_maps
COPY dovecot/dovecot_passwd /opt/postfix-dovecot/dovecot_passwd

# Copy setup file
COPY scripts/setup.sh /setup.sh
# Make the script executable
RUN dos2unix /setup.sh && chmod +x /setup.sh

# Expose necessary ports SMTP IMAP SMTP IMAP
EXPOSE 25 143 587 993

# Start the services
CMD ["/bin/bash", "/setup.sh"]
