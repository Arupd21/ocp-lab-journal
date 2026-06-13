FROM docker.io/kennethreitz/httpbin:latest

LABEL maintainer="arupd.jsr@gmail.com"
LABEL version="1.0"
LABEL description="httpbin HTTP testing service - OCP lab"

EXPOSE 80

CMD ["gunicorn", "-b", "0.0.0.0:80", "httpbin:app", "-k", "gevent"]
