db_get_log_running_query(){
    psql -h $DB_HOST \
         -d $DB_NAME \
         -U ${DB_USER:-postgres} \
         -c "SELECT
  pid,
  usename,
  pg_stat_activity.query_start,
  now() - pg_stat_activity.query_start AS query_time,
  query,
  state,
  wait_event_type,
  wait_event
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '${TIME}' and state != 'idle';"
}

# expression(){
#     psql -h $DB_HOST \
#          -d $DB_NAME \
#          -U ${DB_USER:-postgres} -W
# }

# ref: https://stackoverflow.com/a/42044878
db_pg_read_only_user_syntax(){
    db_name=${DB_NAME:-my_db}
    db_user=${DB_USER:-readonly_user}
    schema=${DB_SCHEMA:-public}
    db_passwd=${DB_PASSWD:-test1234}

   echo "
   CREATE ROLE $db_user WITH LOGIN PASSWORD '$db_passwd' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION VALID UNTIL 'infinity';
   GRANT CONNECT ON DATABASE $db_name TO $db_user;
   GRANT USAGE ON SCHEMA $schema TO $db_user;
   GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO $db_user;
   GRANT SELECT ON ALL SEQUENCES IN SCHEMA $schema TO $db_user;
   " 
   # https://stackoverflow.com/a/42044878
   #ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $db_user;
}
