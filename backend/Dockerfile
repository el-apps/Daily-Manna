FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./
COPY . ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /daily-manna-api .

FROM gcr.io/distroless/static-debian12
COPY --from=build /daily-manna-api /daily-manna-api
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/daily-manna-api"]
