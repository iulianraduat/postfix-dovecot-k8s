#!/bin/bash -x

DOMAIN=${POSTFIX_DOMAIN:-<YOUR_DOMAIN>}
MAIL_HOSTNAME=${POSTFIX_HOSTNAME:-mail.$DOMAIN}
POSTMASTER=${POSTFIX_POSTMASTER:-postmaster}
FIRST_DOMAIN=${DOMAIN%%,*}

# Create virtual domain
sed -e "s|\$DOMAIN|${DOMAIN}|g" \
  -e "s|\$MAIL_HOSTNAME|${MAIL_HOSTNAME}|g" \
  -e "s|\$FIRST_DOMAIN|${FIRST_DOMAIN}|g" \
  /etc/postfix/main.dist.cf > /etc/postfix/main.cf

# Updating the postfix services
cp -f /etc/postfix/master.dist.cf /etc/postfix/master.cf
sed -i '/^smtp\s\+inet.*smtpd/ s/^/#/' /etc/postfix/master.cf
echo 'submission inet n       -       -       -       -       smtpd' >> /etc/postfix/master.cf
echo 'dovecot   unix  -       n       n       -       -       pipe
  flags=DRhu user=mail:mail argv=/usr/lib/dovecot/deliver -f ${sender} -d ${recipient}' >> /etc/postfix/master.cf
echo 'smtp   inet  n       -       y       -       1       postscreen' >> /etc/postfix/master.cf
echo 'dnsblog   unix  -       -       y       -       0       dnsblog' >> /etc/postfix/master.cf

# Authentication
if [ ! -f /etc/postfix/sender_login_maps ]; then
  cat /opt/postfix-dovecot/dovecot_passwd | while read LINE; do
    EMAIL=${LINE%%:*}
    echo "$EMAIL $EMAIL" >> /etc/postfix/sender_login_maps
  done
fi

cat /opt/postfix-dovecot/dovecot_passwd | while read LINE; do
  if [[ "$LINE" == *":{PLAIN}"* ]]; then
    IFS=":" read -r ACCOUNT PASSWORD REST <<< "$LINE"
    echo -n $ACCOUNT: >> /opt/postfix-dovecot/dovecot_passwd.tmp
    PWD=${PASSWORD/\{PLAIN\}/}
    doveadm pw -s SHA512-CRYPT -p $PWD | tr -d '\n' >> /opt/postfix-dovecot/dovecot_passwd.tmp
    if [[ -z "$REST" ]]; then
      IFS="@" read -r U D <<< "${ACCOUNT/:/}"
      echo :8:8::/var/mail/vhosts/$D/$U:: >> /opt/postfix-dovecot/dovecot_passwd.tmp
    else
      echo ":$REST" >> /opt/postfix-dovecot/dovecot_passwd.tmp
    fi
  else
    echo "$LINE" >> /opt/postfix-dovecot/dovecot_passwd.tmp
  fi
done
mv -f /opt/postfix-dovecot/dovecot_passwd.tmp /opt/postfix-dovecot/dovecot_passwd

# Prepare the vhosts folder
mkdir -p /var/mail/vhosts
chown -R mail:mail /var/mail/vhosts
chmod -R 750 /var/mail/vhosts

# Update Postfix database
postmap /etc/postfix/sender_login_maps
postmap /opt/postfix-dovecot/virtual_alias_maps
postmap /opt/postfix-dovecot/virtual_mailbox_maps
chmod 600 /opt/postfix-dovecot/dovecot_passwd
chown dovecot:root /opt/postfix-dovecot/*

# Dovecot
cp -f /etc/dovecot/dovecot.dist.conf /etc/dovecot/dovecot.conf
if [ -n "$POSTMASTER" ]; then
cat<<EOF >> /etc/dovecot/dovecot.conf
protocol lda {
  postmaster_address = $POSTMASTER@$FIRST_DOMAIN
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

if [ -n "$SSL_SUBJ" ]; then
  openssl genpkey -algorithm RSA -out /etc/ssl/private/mailserver.key
  openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout /etc/ssl/private/mailserver.key \
    -out /etc/ssl/certs/mailserver.pem \
    -days 365 \
    -subj "$SSL_SUBJ"
  chmod 600 /etc/ssl/private/mailserver.key
  chown root:root /etc/ssl/private/mailserver.key

  echo "verbose_ssl = yes" >> /etc/dovecot/dovecot.conf
  echo "ssl = yes" >> /etc/dovecot/dovecot.conf
  echo "ssl_cert = </etc/ssl/certs/mailserver.pem" >> /etc/dovecot/dovecot.conf
  echo "ssl_key  = </etc/ssl/private/mailserver.key" >> /etc/dovecot/dovecot.conf
fi

service postfix start
service dovecot start
tail -f /dev/null
