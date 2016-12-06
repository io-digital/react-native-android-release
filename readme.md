
# react-native-android-release

> run android apk release builds from a continuous-integration environment

this set of shell functions makes it trivial to automate the installation of android build tools and run gradle release build configurations. it is assumed that you are using gradle to do multiple apk builds per instruction set.

## example

```bash
# make the functions available in the current shell
source /path/to/react/native/android/release.sh

# explicit export not required if running from within jenkins
export WORKSPACE="/path/to/your/react/native/app"

# run the release with given arguments
release "/srv/releases" \ # apk output prefix
        "my-release-keystore.keystore" \ # keystore file name
        "release" \ # keystore key alias
        "keyboardcat" \ # keystore store password
        "keyboardcat" \ # keystore key password
        "your first and last name" \ # certificate CN
        "your organisational unit" \ # certificate OU
        "your organisation" \ # certificate O
        "your city" \ # certificate L
        "your province" \ # certificate S
        "two-letter country code" # certificate C
```

## todo

* expose arguments for urls to dependencies
* remove aptitude assumptions
* pass arrays to shell functions instead of individual arguments