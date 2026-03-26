FROM postgres:16-alpine
ENV POSTGRES_DB=ckd
ENV POSTGRES_USER=workshop
ENV POSTGRES_PASSWORD=workshop
COPY database/ckd-database.sql /docker-entrypoint-initdb.d/
