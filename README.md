# go-web-hello-world

### Task 0: Install a ubuntu 16.04 server 64-bit in a virtual machine

Release:

    virtualbox
    https://www.virtualbox.org/wiki/Downloads

    Ubuntu 16.04 Server
    http://releases.ubuntu.com/16.04/

Installation Guide:

    virtualbox:
    https://www.virtualbox.org/manual/ch03.html

    Ubuntu Server:
    https://help.ubuntu.com/lts/installation-guide/arm64/index.html

Configuring Port Forwarding with NAT:

```
VBoxManage modifyvm "ubuntu-16.04.7-server-amd64" --natpf1 "guestssh,tcp,,2222,,22"
VBoxManage modifyvm "ubuntu-16.04.7-server-amd64" --natpf1 "guestgitlab,tcp,,80,,8080"
VBoxManage modifyvm "ubuntu-16.04.7-server-amd64" --natpf1 "guestgo8081,tcp,,8081,,8081"
VBoxManage modifyvm "ubuntu-16.04.7-server-amd64" --natpf1 "guestgo8082,tcp,,8082,,8082"
VBoxManage modifyvm "ubuntu-16.04.7-server-amd64" --natpf1 "guestgo31080,tcp,,31080,,31080"
VBoxManage modifyvm "ubuntu-16.04.7-server-amd64" --natpf1 "guestgo31081,tcp,,31081,,31081"
```

Known Issue:

1. Setup port forwarding failed, message: The machine 'ubuntu-16.04.7-server-amd64' is already locked for a session (or being unlocked)

    Fixed: 

    To modify the vm configuration, we must shutdown the VM first, or we use `controlvm` instead, for example:
    ```
    VBoxManage controlvm "ubuntu-16.04.7-server-amd64" natpf1 "guestssh,tcp,,2222,,22"
    ```


### Task 1: Update system
https://help.ubuntu.com/16.04/serverguide/apt.html

ssh to guest machine from host machine:
```
ssh user@localhost -p 2222
```

To upgrade your system, first update your package index:
```
sudo apt update
sudo apt upgrade
```


### Task 2: install gitlab-ce version in the host
https://about.gitlab.com/install/#ubuntu?version=ce

```
sudo EXTERNAL_URL="http://127.0.0.1:8080" apt-get install gitlab-ce
```

Known Issue:
1. http://127.0.0.1:8080 return 502 Error

    Fixed: 

    Because the port 8080 has been used by the external url (nginx), so update `gitlab_workhorse['auth_backend']`, `unicorn['port']` and `puma['port']` to use 8099 instead.

### Task 3: create a demo group/project in gitlab
[Hello World](app/hellowrold.go)

### Task 4: build the app and expose the service to 8081 port
Start the service from the VM:
```
cd app
go build hellowrold.go
./hellowrold
```

Service access from the host machine:
```
curl http://127.0.0.1:8081
```

### Task 5: install docker
https://docs.docker.com/install/linux/docker-ce/ubuntu/

After docker installed, add user to docker group:
```
sudo gpasswd -a ${USER} docker
sudo service docker restart
```

### Task 6: run the app in container
[Dockerfile](app/Dockerfile)

Start the service in container:
```
cd app
./build.sh
docker run -p 8082:8081 go-web-hello-world
```

Known Issue:
1. Error starting userland proxy: listen tcp4 0.0.0.0:8082: bind: address already in use
    ```
    $ docker run -p 8082:8081 go-web-hello-world
    docker: Error response from daemon: driver failed programming external connectivity on endpoint vibrant_wright (1e21276b3860d99b779325cf64ca81e9abedc1a08b771ee5f0e615ec3c00d5c6): Error starting userland proxy: listen tcp4 0.0.0.0:8082: bind: address already in use.
    ```

    Fixed: 

    8082 is used by sidekiq, so use port 8083 instead.
    ```
    $ sudo netstat -plnt | grep 8082
    tcp        0      0 127.0.0.1:8082          0.0.0.0:*               LISTEN      2565/sidekiq 5.2.9 

    $ docker run -p 8083:8081 go-web-hello-world

    $ VBoxManage controlvm "ubuntu-16.04.7-server-amd64" natpf1 "guestgo8083,tcp,,8083,,8083"
    ```

    Service access from the host machine:
    ```
    $ curl http://127.0.0.1:8083
    Go Web Hello World!
    ```

### Task 7: push image to dockerhub

```
docker tag go-web-hello-world horacego/go-web-hello-world:v0.1
docker login
docker push horacego/go-web-hello-world:v0.1
```

### Task 8: document the procedure in a MarkDown file

### Task 9: install a single node Kubernetes cluster using kubeadm

Install kubeadm 1.15.4-00:
```
apt-cache madison kubelet kubectl kubeadm | grep '1.15.4-00'

apt install -y kubelet=1.15.4-00 kubectl=1.15.4-00 kubeadm=1.15.4-00
```

Init Kubernetes cluster v1.15.4:
```
kubeadm init   --kubernetes-version=v1.15.4   --image-repository registry.aliyuncs.com/google_containers   --pod-network-cidr=10.24.0.0/16   --ignore-preflight-errors=Swap --v=5
```

Known issues:
1. GFW issue

    Fixed: 
    
    Use mirrors of aliyun.com.

2. kubernetes cluster v1.20.4 init failed

    Fixed (workaround):

    Use v1.15.4 instead.

### Task 10: deploy the hello world container

Deploy service:
```
cd k8s
kubectl apply -f webserver.yaml 
kubectl apply -f webserver-svc.yaml 
```

Check service port:
```
kubectl get service
```

Service access:
```
curl http://127.0.0.1:31080
```

Known issues:
1. Can not schedule pods on the master for security reasons

    ```
    $ kubectl describe pod webserver-55cb786db6-9zq4d 
    Events:
     Type     Reason            Age                From               Message
     ----     ------            ----               ----               -------
     Warning  FailedScheduling  42s (x3 over 52s)  default-scheduler  0/1 nodes are available: 1 node(s) had taints that the pod didn't tolerate.
    ```

    Fixed:

    By default, the cluster will not schedule pods on the master for security reasons. If you want to be able to schedule pods on the master, run:
    ```
    $ kubectl taint nodes --all node-role.kubernetes.io/master-
    node/demoben untainted
    ```

2. Node is NotReady because of kube-proxy is starting
    ```
    $ kubectl get no -o yaml | grep taint -A 5
        taints:
        - effect: NoSchedule
          key: node.kubernetes.io/not-ready
      status:
        addresses:
        - address: 10.0.2.15

    $ kubectl get no
    NAME           STATUS     ROLES    AGE   VERSION
    demoben   NotReady   master   50m   v1.15.4

    Events:
      Type    Reason    Age   From                      Message
      ----    ------    ----  ----                      -------
      Normal  Starting  51m   kube-proxy, demoben  Starting kube-proxy.
    
    $ kubectl get pods -n kube-system
    NAME                                   READY   STATUS     RESTARTS   AGE
    coredns-bccdc95cf-rgwcx                0/1     Pending    0          12m
    coredns-bccdc95cf-zz4gr                0/1     Pending    0          12m
    etcd-demoben                      1/1     Running    0          68m
    kube-apiserver-demoben            1/1     Running    0          68m
    kube-controller-manager-demoben   1/1     Running    0          69m
    kube-proxy-cfq4k                       1/1     Running    0          6m34s
    kube-scheduler-demoben            1/1     Running    0          68m
    ```

    Fixed:

    It's a problem of Flannel v0.9.1 compatibility with Kubernetes cluster v1.12.2. Once you replace URL in master configuration playbook, it should help:
    ```
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    ```

### Task 11: install kubernetes dashboard
https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

### Task 12: generate token for dashboard login in task 11
