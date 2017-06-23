#!/bin/sh

echo "Im running start"; /etc/init.d/postgresql start; su postgres sh -c 'createuser postgres & createdb postgres'; sudo -u postgres psql -c "ALTER ROLE postgres WITH password 'postgres'"; /etc/init.d/postgresql restart;
