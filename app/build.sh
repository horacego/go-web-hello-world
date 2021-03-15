set -e

go build -o hellowrold hellowrold.go

docker build -t go-web-hello-world .
docker tag go-web-hello-world horacego/go-web-hello-world:v0.1

docker images | grep go-web-hello-world
