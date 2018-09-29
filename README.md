![](https://img.shields.io/badge/platform-OSX-lightgrey.svg)

# QWResign
QWResign is a lightweight script that resigns the ipa file on macOS.

# Usage
```bash
sh QWResign.sh -s <string> -i <path> [-b <string>] [-m <path>] [-e <path>]
    Options:
    -s signature string
    -i .ipa file path
    -b bundle id string you will change
    -m provisioning profile path
    -e entitlements.plist path

```
