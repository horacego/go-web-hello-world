set -e

kubectl get serviceaccount -n kube-system | grep admin-user > /dev/null
if [ $? -ne 0 ];then
  echo "First add admin user"
  kubectl create -f admin-user.yaml
  kubectl create -f  admin-user-role-binding.yaml
fi

echo ""
echo "Generate token"
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
echo ""
