#!/usr/bin/env bash

git_is_inside() {
  git rev-parse --is-inside-work-tree 2>&1
}

git_root() {
  if [[ $(git_is_inside) != "true" ]]; then
    pwd
    return
  fi

  git rev-parse --show-toplevel
}

head_sync() {
  if [[ ${#} -ne 2 ]]; then
    printf "%bUsage: head_sync [REMOTE_SERVER] [REMOTE_PATH]%b\n" "${RED}" "${RESET}"
    return 1
  fi

  local branch
  branch="$(git symbolic-ref -q HEAD | sed -e 's|^refs/heads/||')"
  ssh -A "${1}" "cd '${2}' && git reset HEAD . && git clean -f && git status -u -s | awk '{print \$2}' | xargs rm -rf && git checkout -- . && git fetch && git checkout '${branch}' && git pull"
}

git_sync() {
  if [[ ${#} -lt 2 ]]; then
    printf "%bUsage: git_sync [REMOTE_SERVER] [REMOTE_PATH] [DRY]?%b\n" "${RED}" "${RESET}"
    return 1
  fi

  git_root
  isGit=$?
  if [[ ${isGit} -ne 0 ]]; then
    return ${isGit}
  fi

  local REMOTE_PATH_PREFIX="~/${2}"
  if [[ ${2:0:1} == "/" ]]; then
    REMOTE_PATH_PREFIX="${2}"
  fi

  local dry=false
  if [[ $(echo "${3}" | tr "[:upper:]" "[:lower:]") == "dry" ]]; then
    dry=true
  fi

  if [[ ${dry} == true ]]; then
    printf "%bDry run of syncing files...%b\n" "${BLUE}" "${RESET}"
  else
    printf "%bSyncing files at %s...%b\n" "${BLUE}" "$(date +'%H:%M:%S')" "${RESET}"
  fi

  declare -a toSync
  declare -a toDelete

  local IFS=$'\n'
  for gitFile in $(git status --porcelain); do
    local prefix="${gitFile:0:2}"
    local trimmedPrefix="${prefix#[[:space:]]}"

    case "${trimmedPrefix:0:1}" in
      "M" | "A" | "?")
        toSync+=("${gitFile:3}")
        ;;

      "D")
        toDelete+=("${REMOTE_PATH_PREFIX}/${gitFile:3}")
        ;;

      "R")
        local originFile
        originFile="$(echo "${gitFile}" | awk '{print $2}')"
        local destinationFile
        destinationFile="$(echo "${gitFile}" | awk '{print $4}')"

        toDelete+=("${REMOTE_PATH_PREFIX}/${originFile}")
        toSync+=("${destinationFile}")
        ;;

      *)
        printf "%b¯\_(ツ)_/¯ Don't know how to handle ${gitFile}%b\n" "${BLUE}" "${RESET}"
    esac
  done

  if ! ${dry}; then
    printf "%bCleaning remote%b\n" "${YELLOW}" "${RESET}"
    ssh "${1}" "cd ${REMOTE_PATH_PREFIX} && git clean -f && git checkout -- ."
  fi

  if [[ ${#toDelete[@]} -ne 0 ]]; then
    ! ${dry} && ssh "${1}" "rm -rf ${toDelete[*]}"
    printf "%b- Deleted\n%s%b\n" "${RED}" "${toDelete[*]}" "${RESET}"
  fi

  if [[ ${#toSync[@]} -ne 0 ]]; then
    ! ${dry} && rsync -raR "${toSync[@]}" "${1}:${REMOTE_PATH_PREFIX}/"
    printf "%b+ Copied\n%s%b\n" "${GREEN}" "${toSync[*]}" "${RESET}"
  fi

  printf "%bDone at %s!%b\n\n" "${BLUE}" "$(date +'%H:%M:%S')" "${RESET}"
}

watch_sync() {
  # if [[ -z ${NO_HEAD_SYNC:-} ]]; then
  #   head_sync "${@}"
  # fi

  git_sync "${@}"

  fswatch -0 -o --exclude=.git/ . | while read -r -d ""
  do
    git_sync "${@}"
  done
}

