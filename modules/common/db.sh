# @module db
# @summary PostgreSQL and Redis helpers.
#
# The `db_pg_gen_*` functions PRINT SQL to stdout for you to read and paste; they
# never connect to anything and never execute what they emit. That is deliberate:
# they mint roles and passwords, and a statement you can review before running is
# worth more than one convenience.

# Recorded for `doctor`, but the module still loads without them: the SQL
# generators need nothing installed.
require psql redis-cli || true

# Quote characters held in variables on purpose. `${var//\'/\'\'}` looks like it
# doubles a quote but zsh keeps the backslash, so it emits \'\' and produces
# invalid SQL; substituting through variables behaves identically in both shells.
_DB_SQ="'"
_DB_DQ='"'

# --------------------------------------------------------------- postgres ----

# @describe Show queries that have been running longer than an interval, with the
#           pid, user, wait event and state of each. Connection details come from
#           DB_HOST, DB_NAME and DB_USER unless overridden.
# @usage    db_get_long_running_query [interval] [database] [host] [user]
# @example  db_get_long_running_query
# @example  db_get_long_running_query '30 seconds'
# @example  db_get_long_running_query '1 hour' analytics db.internal readonly
# @requires psql
# @os       any
db_get_long_running_query() {
    local interval="${1:-5 minutes}"
    local database="${2:-${DB_NAME:-postgres}}"
    local host="${3:-${DB_HOST:-localhost}}"
    local user="${4:-${DB_USER:-postgres}}"
    local sql=""

    has psql || { log_error "db_get_long_running_query: psql is not installed"; return 1; }

    # Double any single quote so the interval cannot break out of the literal.
    interval="${interval//$_DB_SQ/$_DB_SQ$_DB_SQ}"

    sql="SELECT
  pid,
  usename,
  pg_stat_activity.query_start,
  now() - pg_stat_activity.query_start AS query_time,
  query,
  state,
  wait_event_type,
  wait_event
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '$interval'
  AND state <> 'idle'
ORDER BY query_time DESC;"

    psql -h "$host" -d "$database" -U "$user" -c "$sql"
}

# @describe Emit the SQL that creates a read-only role and grants it SELECT across
#           a schema. Prints only — review it, then run it yourself. The password
#           must be supplied; there is no default.
# @usage    db_pg_gen_read_only_user_sql <user> <password> [database] [schema]
# @example  db_pg_gen_read_only_user_sql reporting "$(openssl rand -base64 24)" analytics
# @see      db_pg_gen_user_sql
# @os       any
db_pg_gen_read_only_user_sql() {
    local user="${1:-$DB_USER}"
    local password="${2:-$DB_PASSWD}"
    local database="${3:-${DB_NAME:-my_db}}"
    local schema="${4:-${DB_SCHEMA:-public}}"

    if [ -z "$user" ] || [ -z "$password" ]; then
        log_error "usage: db_pg_gen_read_only_user_sql <user> <password> [database] [schema]"
        return 1
    fi

    password="${password//$_DB_SQ/$_DB_SQ$_DB_SQ}"
    user="${user//$_DB_DQ/$_DB_DQ$_DB_DQ}"
    database="${database//$_DB_DQ/$_DB_DQ$_DB_DQ}"
    schema="${schema//$_DB_DQ/$_DB_DQ$_DB_DQ}"

    printf '%s\n' \
        "-- read-only role: review before running. ref: https://stackoverflow.com/a/42044878" \
        "CREATE ROLE \"$user\" WITH LOGIN PASSWORD '$password'" \
        "    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION VALID UNTIL 'infinity';" \
        "GRANT CONNECT ON DATABASE \"$database\" TO \"$user\";" \
        "GRANT USAGE ON SCHEMA \"$schema\" TO \"$user\";" \
        "GRANT SELECT ON ALL TABLES IN SCHEMA \"$schema\" TO \"$user\";" \
        "GRANT SELECT ON ALL SEQUENCES IN SCHEMA \"$schema\" TO \"$user\";" \
        "-- also grant on tables created later:" \
        "-- ALTER DEFAULT PRIVILEGES IN SCHEMA \"$schema\" GRANT SELECT ON TABLES TO \"$user\";"
}

# @describe Emit the SQL that creates a database, its owning role, and full
#           privileges on it. Prints only — review it, then run it yourself.
# @usage    db_pg_gen_user_sql <database> <user> <password>
# @example  db_pg_gen_user_sql myapp myapp_user "$(openssl rand -base64 24)"
# @see      db_pg_gen_read_only_user_sql
# @os       any
db_pg_gen_user_sql() {
    local database="$1" user="$2" password="$3"

    if [ -z "$database" ] || [ -z "$user" ] || [ -z "$password" ]; then
        log_error "usage: db_pg_gen_user_sql <database> <user> <password>"
        return 1
    fi

    password="${password//$_DB_SQ/$_DB_SQ$_DB_SQ}"
    user="${user//$_DB_DQ/$_DB_DQ$_DB_DQ}"
    database="${database//$_DB_DQ/$_DB_DQ$_DB_DQ}"

    printf '%s\n' \
        "-- review before running" \
        "CREATE ROLE \"$user\" WITH LOGIN PASSWORD '$password';" \
        "CREATE DATABASE \"$database\" OWNER \"$user\";" \
        "GRANT ALL PRIVILEGES ON DATABASE \"$database\" TO \"$user\";"
}

# ------------------------------------------------------------------ redis ----

# @describe Show the keyspace section of `redis-cli info`: key counts and TTLs
#           per database.
# @usage    redis_get_keyspace [redis-cli-argument]...
# @example  redis_get_keyspace
# @example  redis_get_keyspace -h cache.internal -p 6380
# @requires redis-cli
# @os       any
redis_get_keyspace() {
    has redis-cli || { log_error "redis_get_keyspace: redis-cli is not installed"; return 1; }
    redis-cli "$@" info keyspace
}

# @describe Show the replication section of `redis-cli info`: role, linked
#           replicas, and replication offsets.
# @usage    redis_get_replication [redis-cli-argument]...
# @example  redis_get_replication
# @requires redis-cli
# @os       any
redis_get_replication() {
    has redis-cli || { log_error "redis_get_replication: redis-cli is not installed"; return 1; }
    redis-cli "$@" info replication
}

# @describe Open a redis-cli session against the Sentinel port (26379 by default).
# @usage    redis_sentinel_cli [redis-cli-argument]...
# @example  redis_sentinel_cli sentinel masters
# @requires redis-cli
# @os       any
redis_sentinel_cli() {
    has redis-cli || { log_error "redis_sentinel_cli: redis-cli is not installed"; return 1; }
    redis-cli -p "${REDIS_SENTINEL_PORT:-26379}" "$@"
}

# @describe Block the redis server for N seconds using DEBUG SLEEP, to test how
#           clients behave when redis stops answering. Prompts first.
# @usage    redis_debug_sleep [seconds]
# @example  redis_debug_sleep 5
# @requires redis-cli
# @danger   The server serves NO requests for the whole duration. Never point
#           this at production.
# @os       any
redis_debug_sleep() {
    local seconds="${1:-30}"

    has redis-cli || { log_error "redis_debug_sleep: redis-cli is not installed"; return 1; }

    case "$seconds" in
        '' | *[!0-9]*) log_error "redis_debug_sleep: seconds must be a whole number"; return 1 ;;
    esac

    confirm "Block this redis server for ${seconds}s (it will answer nothing)?" || return 0
    redis-cli debug sleep "$seconds"
}

# ------------------------------------------------------------ back-compat ----
# Old names from shellrc.d/{db,redis}.sh. Note db_get_log_running_query was a
# typo for "long".

alias db_get_log_running_query='db_get_long_running_query'
alias db_pg_read_only_user_syntax='db_pg_gen_read_only_user_sql'
alias gen_pg_syntax='db_pg_gen_user_sql'
alias redis_keys='redis_get_keyspace'
alias redis_replication='redis_get_replication'
alias redis_sleep_30='redis_debug_sleep'
alias sentinel-cli='redis_sentinel_cli'
