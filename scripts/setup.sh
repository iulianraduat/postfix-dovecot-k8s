#!/bin/bash

DOMAIN=${POSTFIX_MYDOMAIN:-<YOUR_DOMAIN>}
POSTMASTER=${POSTFIX_POSTMASTER:-postmaster}

# Create virtual domain
cp -f /etc/postfix/main.dist.cf /etc/postfix/main.cf
echo "virtual_mailbox_domains = $DOMAIN" >> /etc/postfix/main.cf
echo "virtual_uid_maps = static:mail" >> /etc/postfix/main.cf
echo "virtual_gid_maps = static:mail" >> /etc/postfix/main.cf
echo "debug_peer_list = $DOMAIN" >> /etc/postfix/main.cf

# Updating the postfix services
cp -f /etc/postfix/master.dist.cf /etc/postfix/master.cf
echo 'submission inet n       -       -       -       -       smtpd' >> /etc/postfix/master.cf
echo 'dovecot   unix  -       n       n       -       -       pipe
  flags=DRhu user=mail:mail argv=/usr/lib/dovecot/deliver -f ${sender} -d ${recipient}' >> /etc/postfix/master.cf

# Authentication
if [ ! -f /etc/postfix/sender_login_maps ]; then
  cat /opt/postfix-dovecot/dovecot_passwd | while read LINE; do
    EMAIL=${LINE%%:*}
    echo "$EMAIL $EMAIL" >> /etc/postfix/sender_login_maps
  done
fi

if [ ! -f /opt/postfix-dovecot/sasl_passwd ]; then
  cat /opt/postfix-dovecot/dovecot_passwd | while read LINE; do
    echo ${LINE/:\{PLAIN\}/ } >> /opt/postfix-dovecot/sasl_passwd
  done
fi

# Prepare the vhosts folder
mkdir -p /var/mail/vhosts
chown -R mail:mail /var/mail/vhosts
chmod -R 755 /var/mail/vhosts

# Update Postfix database
postmap /etc/postfix/sender_login_maps
postmap /opt/postfix-dovecot/sasl_passwd
postmap /opt/postfix-dovecot/virtual_alias_maps
postmap /opt/postfix-dovecot/virtual_mailbox_maps
chmod 600 /opt/postfix-dovecot/sasl_passwd /opt/postfix-dovecot/sasl_passwd.db


# Dovecot
cp -f /etc/dovecot/dovecot.dist.conf /etc/dovecot/dovecot.conf
if [ -n "$POSTMASTER" ]; then
cat<<EOF >> /etc/dovecot/dovecot.conf
protocol lda {
  postmaster_address = $POSTMASTER@${$DOMAIN%% *}
}
EOF
fi

# Fixes
mkdir -p /var/log/postfix-dovecot
touch /var/log/postfix-dovecot/dovecot.log
chown mail:mail /var/log/postfix-dovecot/dovecot.log
chmod 0644 /var/log/postfix-dovecot/dovecot.log
touch /var/log/postfix-dovecot/postfix.log
chown mail:mail /var/log/postfix-dovecot/postfix.log
chmod 0644 /var/log/postfix-dovecot/postfix.log
