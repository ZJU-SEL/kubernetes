all: push

TAG = 0.1

mt-hostdir: mt-hostdir.go
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-w' ./mt-hostdir.go

image: mt-hostdir
	sudo docker build -t dalanlan/host-dir-mounttest:$(TAG) .

push: image
	sudo docker push dalanlan/host-dir-mounttest:$(TAG)

clean:
	rm -f mt
