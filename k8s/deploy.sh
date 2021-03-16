set -e

echo ""
echo "Generate SSL certificate"
mkdir certs
cd certs
# Generate private key and certificate signing request
openssl genrsa -des3 -passout pass:over4chars -out dashboard.pass.key 2048
openssl rsa -passin pass:over4chars -in dashboard.pass.key -out dashboard.key
rm dashboard.pass.key
openssl req -new -key dashboard.key -out dashboard.csr

# Generate SSL certificate
openssl x509 -req -sha256 -days 365 -in dashboard.csr -signkey dashboard.key -out dashboard.crt
cd -

echo ""
echo "Create kubernetes secret"
# Create secret
kubectl get secret -A | grep kubernetes-dashboard-certs > /dev/null
if [ $? -ne 0 ];then
  echo "First delete the old secret"
  kubectl delete secret kubernetes-dashboard-certs -n kubernetes-dashboard
fi
kubectl create secret generic kubernetes-dashboard-certs --from-file=certs -n kubernetes-dashboard

echo ""
echo "Deploy dashboard"
# Deploy dashboard, under Deployment section, add arguments (--tls-cert-file=/dashboard.crt and --tls-key-file=/dashboard.key) to pod definition
kubectl create --edit -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
