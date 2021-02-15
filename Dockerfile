FROM curlimages/curl AS curl

USER root

RUN curl -fsLo /tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-amd64 && \
  chmod +x /tini

FROM redis:6

COPY --from=curl /tini /usr/local/bin/

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["redis-server"]
