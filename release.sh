#!/usr/bin/env bash

release() {
    APP="${1}"
    WORKSPACE="/var/lib/jenkins/jobs/${APP}/workspace"
    VERSION=$(jq -r -c -M '.version' < "${WORKSPACE}/package.json")

    if [[ "${APP}" == "" ]]; then
        echo "release error: supply an app name argument to the release command"
        exit 1
    fi
    
    cd "${WORKSPACE}" || (
        echo "probably jenkins error: workspace for ${APP} not found!"
        exit 1
    )

    # wire up the android sdk
    export ANDROID_HOME=/usr/local/android-sdk-linux
    export PATH="${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools"

    # wire up the keystore parameters
    export ECDRN_RELEASE_STORE_FILE="${WORKSPACE}/android/keystores/production.keystore"
    export ECDRN_RELEASE_STORE_PASSWORD=cnsnt_production
    export ECDRN_RELEASE_STORE_KEY_ALIAS=production
    export ECDRN_RELEASE_STORE_KEY_PASSWORD=cnsnt_production

    # refresh dependencies
    rm -rf node_modules || true && npm install

    # this step will fail because it tries to deploy the apk to a phone 
    # (there's no way to do the release build without deploying to a 
    #  phone because of a deficiency in react-native's build toolchain)
    react-native run-android --variant=release || true

    # create a new dir for this version
    mkdir -p "/srv/apk/${APP}/${VERSION}"

    # copy latest apks to their respective dirs in webroot
    cp "${WORKSPACE}/android/app/build/outputs/apk/app-*-release.apk" "/srv/apk/${APP}/${VERSION}"
    cp -R "${WORKSPACE}/android/app/build/outputs/apk/app-armeabi-v7a-release.apk" "/srv/apk/${APP}/arm-latest.apk"
    cp -R "${WORKSPACE}/android/app/build/outputs/apk/app-x86-release.apk" "/srv/apk/${APP}/x86-latest.apk"
}