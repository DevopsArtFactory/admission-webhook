#!/bin/bash

openssl genrsa -out ca.key 2048

openssl req -new -x509 -days 365 -key ca.key \
  -subj "/C=AU/CN=custom-admission-webhook"\
  -out ca.crt

openssl req -newkey rsa:2048 -nodes -keyout server.key \
  -subj "/C=AU/CN=custom-admission-webhook" \
  -out server.csr

echo "subjectAltName=DNS:custom-admission-webhook.kube-system.svc" > san.txt
openssl x509 -req \
  -extfile san.txt \
  -days 365 \
  -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt

echo
echo ">> Generating kube secrets..."
kubectl create secret tls custom-admission-webhook-tls \
  --namespace=kube-system \
  --cert=server.crt \
  --key=server.key \
  --dry-run=client -o yaml | kubectl apply -f -\

echo
echo ">> ValidationWebhookConfiguration caBundle:"
CA_BUNDLE=$(cat ca.crt | base64)

sed "s|\${CA_BUNDLE}|${CA_BUNDLE}|g" hack/manifests/cluster-config/validatingwebhook.yaml.template | kubectl apply -f -

rm ca.crt ca.key ca.srl server.crt server.csr server.key
