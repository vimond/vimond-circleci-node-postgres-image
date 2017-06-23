FROM node:6

# make Apt non-interactive
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90circleci \
  && echo 'APT::Get::force-Yes "true";' >> /etc/apt/apt.conf.d/90circleci \
  && echo 'DPkg::Options "--force-confnew";' >> /etc/apt/apt.conf.d/90circleci

ENV DEBIAN_FRONTEND=noninteractive

RUN wget -q -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64 && echo "21693dc9c4c9511fb2bffd024470a77e34c114a7 */usr/local/bin/dumb-init" | shasum -c - && chmod +x /usr/local/bin/dumb-init

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]

RUN apt-get update \
  && apt-get install -y \
    git mercurial xvfb \
    locales sudo openssh-client ca-certificates tar gzip parallel \
    net-tools netcat unzip zip

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8

# install jq
RUN JQ_URL=$(curl -sSL https://api.github.com/repos/stedolan/jq/releases/latest  |grep browser_download_url |grep '/jq-linux64"' | grep -o -e 'https.*jq-linux64') \
  && curl -sSL --fail -o /usr/bin/jq $JQ_URL \
  && chmod +x /usr/bin/jq

# install docker
RUN set -ex && DOCKER_VERSION=$(curl -sSL https://api.github.com/repos/docker/docker/releases/latest | jq -r '.tag_name' | sed 's|^v||g' ) \
  && DOCKER_URL="https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" \
  && curl -sSL -o /tmp/docker.tgz "${DOCKER_URL}" \
  && echo $DOCKER_URL \
  && ls -lha /tmp/docker.tgz \
  && tar -xz -C /tmp -f /tmp/docker.tgz \
  && mv /tmp/docker/* /usr/bin \
  && rm -rf /tmp/docker /tmp/docker.tgz

# docker compose
RUN COMPOSE_URL=$(curl -sSL https://api.github.com/repos/docker/compose/releases/latest | jq -r '.assets[] | select(.name == "docker-compose-Linux-x86_64") | .browser_download_url') \
  && curl -sSL -o /usr/bin/docker-compose $COMPOSE_URL \
  && chmod +x /usr/bin/docker-compose

# install dockerize
RUN DOCKERIZE_URL=$(curl -sSL https://api.github.com/repos/jwilder/dockerize/releases/latest | jq -r '.assets[] | select(.name | startswith("dockerize-linux-amd64")) | .browser_download_url') \
  && curl -sSL -o /tmp/dockerize-linux-amd64.tar.gz $DOCKERIZE_URL \
  && tar -C /usr/local/bin -xzvf /tmp/dockerize-linux-amd64.tar.gz \
  && rm -rf /tmp/dockerize-linux-amd64.tar.gz


RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# install postgres
ENV PG_MAJOR 9.5
ENV PG_VERSION 9.5.7-1.pgdg80+1

RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main' $PG_MAJOR > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update \
	&& apt-get install -y postgresql-common \
	&& sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
	&& apt-get install -y \
		postgresql-$PG_MAJOR=$PG_VERSION \
		postgresql-contrib-$PG_MAJOR=$PG_VERSION \
	&& rm -rf /var/lib/apt/lists/*

RUN wget -q -O flyway.tar.gz https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/4.0.3/flyway-commandline-4.0.3-linux-x64.tar.gz && tar xvfz ./flyway.tar.gz -C ./ && rm -rf flyway.tar.gz


# RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" >> /etc/apt/sources.list.d/pgdg.list

# RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
#   sudo apt-key add - sudo apt-get update

# RUN apt-get update \
#   && apt-get install -y postgresql postgresql-contrib \
#   && apt-get install sudo \
#   && apt-get clean \
#   && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



# make the sample config easier to munge (and "correct by default")
RUN mv -v /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample /usr/share/postgresql/ \
	&& ln -sv ../postgresql.conf.sample /usr/share/postgresql/$PG_MAJOR/ \
	&& sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample 
#   && mkdir -p /var/lib/postgresql/data/ && chown -R postgres:postgres /var/lib/postgresql && chmod -R 0700 /var/lib/postgresql \
#  && cp /usr/share/postgresql/postgresql.conf.sample /var/lib/postgresql/data/postgresql.conf

RUN ls -l /var/lib/postgresql

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA" # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
# VOLUME /var/lib/postgresql/data





# RUN apt-get install postgresql -y
# RUN apt-get install postgres-contrib -y

# 
# COPY start.sh .
# CMD ["/etc/init.d/postgresql start"]

# # ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
# CMD ["su postgres sh -c 'createuser postgres & createdb postgres'"]
# CMD ["sudo -u postgres psql -c 'ALTER ROLE postgres WITH password \'postgres\''"]
# RUN su postgres sh -c 'createuser postgres & createdb postgres'
# RUN su postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

# RUN groupadd --gid 3434 circleci \
#   && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
#   && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
#   && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# BEGIN IMAGE CUSTOMIZATIONS
# END IMAGE CUSTOMIZATIONS

# flyway-4.0.3/flyway -url=jdbc:postgresql://localhost:5432/postgres -locations=filesystem:./src/migration/sql -schemas=cms -user=postgres -password=postgres migrate


USER postgres
RUN initdb --user=postgres 
CMD ["postgres"]



