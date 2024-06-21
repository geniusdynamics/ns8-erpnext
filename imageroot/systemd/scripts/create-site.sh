#!/bin/bash
wait-for-it -t 120 db:3306;
wait-for-it -t 120 redis-cache:6379; # not sure is redis cache is running
wait-for-it -t 120 redis-queue:6379;
export start=`date +%s`;
until [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".db_host // empty"` ]] && \
  [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty"` ]] && \
  [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty"` ]];
do
  echo "Waiting for sites/common_site_config.json to be created";
  sleep 5;
  if (( `date +%s`-start > 120 )); then
    echo "could not find sites/common_site_config.json with required keys";
    exit 1
  fi
done;
echo "sites/common_site_config.json found";
bench new-site --no-mariadb-socket --admin-password=erpnext --db-root-password=erpnext --install-app erpnext --set-default frontend;