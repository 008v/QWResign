![](https://img.shields.io/badge/platform-OSX-lightgrey.svg)

# QWResign
QWResign is a lightweight script that resigns the ipa file on macOS.

# Usage
```bash
sh QWResign.sh -s <string> -i <path> [-b <string>] [-m <path>] [-e <path>]
    Options:
    -s \t signature string
    -i \t .ipa file path
    -b \t bundle id string you will change
    -m \t provisioning profile path
    -e \t entitlements.plist path

```
