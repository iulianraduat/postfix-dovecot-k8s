# postfix-dovecot-k8s

Postfix (SMTP) and Dovecot (IMAP) as k8s deployment

## Install

In the folder were you have all .yaml files run the following command:

```
kubectl apply -k .
```

If it does not work for minikube then try:

```
minikube kubectl apply -k .
```

If it does not work for microk8s then try:

```
microk8s kubectl apply -k .
```

You should see in the `default` namespace defined for kubernetes all the new objects.
The corresponding service is called `postfix-dovecot`.

If you want to use it in a different namespace then just add "-n &lt;namespace&gt;" as argument to kubectl call.

You need to use a proxy in front of it (like nginx) to redirect to the exposed port on k8s node.
To find the mapped ports just check the "Internal Endpoints" of the service "postfix-dovecot"
or run `kubectl get svc` from the shell of the server running the cluster.

## Customization

You must customize some values in the `configMapGenerator` section of `kustomization.yaml` and in the following files:

- dovecot/dovecot-passwd
- postfix/virtual_alias_maps
- postfix/virtual_mailbox_maps

Afterwards you need to copy these 3 files in `postfix-dovecot-config` PVC.

## Accessign the smtp and imap

You need to access the corresponding ports.

## Troubleshooting

If you get the following error when sending a message:

- `Client host rejected: cannot find your hostname`: remove `reject_unknown_client_hostname` from `smtpd_recipient_restrictions` in `main.cf` and try again.

If you need to authenticate to your repo:

- kubectl create secret docker-registry registry-credentials --docker-server=<your_registry_server> --docker-username=<your_username> --docker-password=<your_password> --docker-email=<your_email>

## Know Bugs

- SSL is not supported by SMTP and IMAP
- SMTP allows sending messages without authentication
