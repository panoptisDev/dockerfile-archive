FROM golang:1.18
WORKDIR /actorload/
COPY . .
RUN make build

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=0 /actorload/dist/ .
CMD ["./stateactor"]
