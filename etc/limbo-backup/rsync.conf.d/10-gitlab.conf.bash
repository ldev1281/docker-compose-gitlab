CMD_BEFORE_BACKUP="docker compose --project-directory /docker/gitlab down"
CMD_AFTER_BACKUP="docker compose --project-directory /docker/gitlab up -d"

CMD_BEFORE_RESTORE="docker compose --project-directory /docker/gitlab down || true"
CMD_AFTER_RESTORE=(
  "docker network create --driver bridge --internal proxy-client-gitlab || true"
  "docker compose --project-directory /docker/gitlab up -d"
)

INCLUDE_PATHS=(
  "/docker/gitlab"
)