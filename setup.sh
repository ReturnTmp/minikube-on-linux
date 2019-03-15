#!/bin/bash
#


set -e


# define the home directory of minikube
# default value is current directory if not set
MINIKUBE_HOME=/opt/minikube

BASE_DIR=$(cd $(dirname "$BASH_SOURCE[0]"); pwd)

RED=$(tput setaf 1)
GREEN=$(tput setaf 76)
RESET=$(tput sgr0)

function logger_error() {
    local time=$(date +'%F %T')
    printf "${RED}${time} - ERROR - %s${RESET}\n" "$@"
    echo "${time} - ERROR - $@" >> ${BASE_DIR}/logs/setup.log
}

function logger_info() {
    local time=$(date +'%F %T')
    printf "${GREEN}${time} - INFO - %s${RESET}\n" "$@"
    echo "${time} - INFO - $@" >> ${BASE_DIR}/logs/setup.log
}

# check docker is started or not
function check_requirement() {
    docker info &>/dev/null
    if [ $? -ne 0 ] 
    then 
        logger_error "docker is not running, please start it first."
        exit 1
    fi
}

function mkdir_dirs() {
    [[ -d "${BASE_DIR}/.bin" ]] || mkdir -p "${BASE_DIR}/.bin"
    [[ -d "${BASE_DIR}/.images" ]] || mkdir -p "${BASE_DIR}/.images"
    [[ -d "${BASE_DIR}/logs" ]] || mkdir -p "${BASE_DIR}/logs"
}

function get_host_os() {
    local host_os=""
    case "$(uname -s)" in
        Darwin)
            host_os=darwin
            ;;
        Linux)
            host_os=linux
            ;;
        *)
            logger_error "Unsupported host OS. Must be Linux or Mac OS X."
            exit 1
            ;;
    esac
    echo "${host_os}"
}

function get_host_arch() {
    local host_arch=""
    case "$(uname -m)" in
        x86_64*|i?86_64*|amd64*|aarch64*|arm64*)
            host_arch=amd64
            ;;
        arm*)
            host_arch=arm
            ;;
        i?86*)
            host_arch=x86
            ;;
        s390x*)
            host_arch=s390x
            ;;
        ppc64le*)
            host_arch=ppc64le
            ;;
        *)
            logger_error "Unsupported host arch. Must be x86_64, 386, arm, arm64, s390x or ppc64le."
            exit 1
            ;;
    esac
    echo "${host_arch}"

}

# download minikube and kubelet
function download_binaries() {
    local host_os=$(get_host_os)
    local host_arch=$(get_host_arch)
    STORAGE_HOST="${STORAGE_HOST:-https://storage.googleapis.com}"
    cd "${BASE_DIR}/.bin" &>/dev/null
    if [ ! -f minikube ] 
    then 
        logger_info "start to download minikube."
        download "${STORAGE_HOST}/minikube/releases/latest/minikube-${host_os}-${host_arch}" minikube
        logger_info "end to download minikube"
    fi 
    if [ ! -f kubelet ] 
    then 
        logger_info "start to download kubelet."
        download "https://storage.googleapis.com/kubernetes-release/release/stable.txt" stable.txt
        local kube_version=$(cat stable.txt | awk 'NR == 1 { print }')
        download "${STORAGE_HOST}/kubernetes-release/release/${kube_version}/bin/${host_os}/${host_arch}/kubectl" kubelet
        logger_info "end to download kubelet"
    fi
    cd - &>/dev/null
}

# download file from remote host
# ${1} file url
# ${2} file name
function download() {
    local file_url="${1}"
    local file_name="${2}"
    if [[ $(which curl) ]]
    then 
        curl -fsL --retry 3 --keepalive-time 2 "${file_url}" -o "${file_name}"
    elif [[ $(which wget) ]] 
    then
        wget -q "${file_url}" -O "${file_name}"
    else 
        logger_error "Couldn't find curl or wget, please install one at least."
        exit 1
    fi 
}

mkdir_dirs

check_requirement

download_binaries

