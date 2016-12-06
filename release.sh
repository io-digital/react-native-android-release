#!/usr/bin/env bash

android_sdk_install() {
    [[ $# == 3 ]] || {
        echo "expected three argument(s), exiting!"
        return 1
    }
    android_sdk_install_prefix=$1
    android_sdk=$2
    android_sdk_url=$3
    [[ -d "${android_sdk_install_prefix}/${android_sdk}" ]] || {
        curl --silent -L "${android_sdk_url}" -o "${android_sdk}.tgz"
        tar xf "${android_sdk}.tgz"
        mv "${android_sdk}" "${android_sdk_install_prefix}"
        rm "${android_sdk}.tgz"
    }
    export ANDROID_HOME="${android_sdk_install_prefix}/${android_sdk}"
    export PATH="${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools"
    return 0
}

android_sdk_build_tools_install() {
    [[ $# == 1 ]] || {
        echo "expected one argument(s), exiting!"
        return 1
    }
    build_tools_version=$1
    echo y | /usr/local/android-sdk/android update sdk --no-ui --all --filter "build-tools-${build_tools_version}" || return 1
    return 0
}

keystore_create_if_not_exists() {
    [[ $# == 6 ]] || {
        echo "expected six argument(s), exiting!"
        return 1
    }
    keystore_path_prefix=$1
    keystore_name=$2
    keystore_alias=$3
    keystore_keypass=$4
    keystore_storepass=$5
    keystore_dname=$6

    initial_dir=$(pwd)

    [[ -f "${keystore_path_prefix}/${keystore_name}" ]] || {
        cd "${keystore_path_prefix}" || {
            echo "path is not navigable, exiting!"
            return 1
        }
        keytool -noprompt \
                -genkeypair \
                -keystore "${keystore_name}" \
                -alias "${keystore_alias}" \
                -keypass "${keystore_keypass}" \
                -storepass "${keystore_storepass}" \
                -keyalg RSA \
                -keysize 2048 \
                -validity 10000 \
                -dname "${keystore_dname}" || return 1
        cd "${initial_dir}" || {
            echo "path is not navigable, exiting!"
            return 1
        }
    }
    return 0
}

jq_install() {
    type jq || apt-get install -y jq
    return 0
}

nvm_install() {
    [[ $# == 2 ]] || {
        echo "expected two argument(s), exiting!"
        return 1
    }
    nvm_install_prefix=$1
    nvm_install_url=$2
    [[ -d "${nvm_install_prefix}/nvm" ]] || {
        apt-get install -y build-essential libssl-dev
        curl --silent -o- "${nvm_install_url}" | NVM_DIR="${nvm_install_prefix}/nvm" bash
    }
    # shellcheck source=/dev/null
    source "${nvm_install_prefix}/nvm/nvm.sh"
    return 0
}

release() {

    [[ $# == 11 ]] || {
        echo "expected eleven argument(s), exiting!"
        return 1
    }

    apk_output_prefix=$1
    keystore_file_name=$2
    keystore_key_alias=$3
    keystore_store_password=$4
    keystore_key_password=$5
    cert_cn="$6"
    cert_ou="$7"
    cert_o="$8"
    cert_l="$9"
    cert_s="${10}"
    cert_c="${11}"

    jq_install || {
        echo "failed to install jq, exiting!"
        return 1
    }

    nvm_install /usr/local https://raw.githubusercontent.com/creationix/nvm/v0.32.1/install.sh || {
        echo "failed to install nvm, exiting!"
        return 1
    }

    export RELEASE_KEYSTORE_FILE_NAME="${keystore_file_name}"
    export RELEASE_STORE_FILE="${WORKSPACE}/android/keystores/${RELEASE_KEYSTORE_FILE_NAME}"
    export RELEASE_STORE_PASSWORD="${keystore_store_password}"
    export RELEASE_STORE_KEY_ALIAS="${keystore_key_alias}"
    export RELEASE_STORE_KEY_PASSWORD="${keystore_key_password}"

    # check if build deps are present
    android_sdk_install /usr/local android-sdk https://dl.google.com/android/android-sdk_r24.4.1-linux.tgz || {
        echo "failed to install android sdk, exiting!"
        return 1
    }

    android_sdk_build_tools_install "23.0.1" || {
        echo "failed to install android sdk build-tools, exiting!"
        return 1
    }

    keystore_create_if_not_exists "${WORKSPACE}/android/keystores" \
                                  "${RELEASE_KEYSTORE_FILE_NAME}" \
                                  "${RELEASE_STORE_KEY_ALIAS}" \
                                  "${RELEASE_STORE_KEY_PASSWORD}" \
                                  "${RELEASE_STORE_PASSWORD}" \
                                  "CN=${cert_cn}, OU=${cert_ou}, O=${cert_o}, L=${cert_l}, S=${cert_s}, C=${cert_c}" || {
                                      echo "failed to check or generate keystore, exiting!"
                                      return 1
                                  }

    # change to node version if specified, otherwise presume stable
    if [[ -f "${WORKSPACE}/.nvmrc" ]]; then
        nvm use || nvm install
    else
        nvm install stable
    fi

    # refresh dependencies
    rm -rf node_modules || true
    npm install

    # we are forced to "|| true" this step because it tries to deploy the apk 
    # to a phone (there's no way to do the release build without deploying to a 
    # phone due to a deficiency in react-native's build toolchain for android)
    react-native run-android --variant=release || true

    VERSION=$(jq -r -c -M '.version' < "${WORKSPACE}/package.json")
    APP=$(jq -r -c -M '.name' < "${WORKSPACE}/package.json")

    # create a new dir for this version
    mkdir -p "${apk_output_prefix}/${APP}/${VERSION}"

    # copy latest apks to their respective dirs in webroot
    cp "${WORKSPACE}/android/app/build/outputs/apk/app-*-release.apk" "${apk_output_prefix}/${APP}/${VERSION}"
    cp -R "${WORKSPACE}/android/app/build/outputs/apk/app-armeabi-v7a-release.apk" "${apk_output_prefix}/${APP}/arm-latest.apk"
    cp -R "${WORKSPACE}/android/app/build/outputs/apk/app-x86-release.apk" "${apk_output_prefix}/${APP}/x86-latest.apk"

    return 0
}