#!/bin/sh

#   QWResign
#  
#   Copyright (c) 2012-2014 Qin Wei. All rights reserved.
#
#   Change the code sign of an ipa file.
#

set -e

######################## Usage ########################

usage()
{
    echo "\n"
    echo "Usage: sh `basename $0` -s <string> -i <path> [-b <string>] [-m <path>] [-e <path>]\n"
    echo "Options:\n"
    echo "    -s \t signature string"
    echo "    -i \t .ipa file path"
    echo "    -b \t bundle id string you will change"
    echo "    -m \t provisioning profile path"
    echo "    -e \t entitlements.plist path"
    echo "\n"
    exit 1
}

while getopts s:i:b:m:e: opt
do
    case "$opt" in
        s)
        identity=$OPTARG;;
        i)
        originalIpaPath=$OPTARG;;
        b)
        bundleID=$OPTARG;;
        m)
        mobileprovisionPath=$OPTARG;;
        e)
        entitlementPath=$OPTARG;;
        h)
        usage;;
        \?)
        usage;;
    esac
done

if [ $# = 0 ];then
    usage
fi

if [[ -z "${identity}" || -z "${originalIpaPath}" ]];then
    usage
fi


######################## Settings ########################

# 工作路径
workingPath="`dirname $0`/QWResign"

#下面的变量已从脚本外部传入参数了，所以注掉了

# 签名字符串
#
# 查看钥匙串中有效的签名：/usr/bin/security find-identity -v -p codesigning
#
# 签名字符串，以下两种形式都有效：
# "iPhone Distribution: Anhui Yuesheng Musical Instruments Trading Co., Ltd."
# "0068AEAE7D83D36FB4F6BF46B50A53DC92DE1233"

# 原ipa路径
#read -p ".ipa path: " originalIpaPath
##originalIpaPath="/Users/Wayne/Documents/淘宝/用户数据/挥霍光阴/lunhui-resigned.ipa"

# Bundle ID
#read -p "Bundle ID: " bundleID
##bundleID="com.example.lhdc"

# 描述文件
#read -p ".mobileprovision path: " mobileprovisionPath

# entitlement
#read -p "entitlement path: " entitlementPath
##entitlementPath=""


######################## Function ########################

fatal() {

local msg=$1
echo "error: $msg\n" >&2

rm -rf "${workingPath}"

exit 1

}

# 检查签名字符串
checkIdentity() {

# 签名字符串非空，且钥匙串查询有效
if [ -n "${identity}" ];then
    if [[ `/usr/bin/security find-identity -v -p codesigning` =~ "${identity}" ]];then
        return 0
    else
        fatal "Invalid identity."
    fi
else
    fatal "You must specify a identity."
fi

}

# 验证ipa文件
checkIpa() {

local fileName=`echo $(basename "${originalIpaPath}")|tr "A-Z" "a-z"`
local extName=${fileName##*.}

# 判断扩展名
if [ "$extName" == "ipa" ];then
    # 判断文件存在
    if [ -e "${originalIpaPath}" ];then
        # 判断文件小大不为零
        if [ -s "${originalIpaPath}" ];then
            return 0
        else
            fatal "Invalid *.ipa file."
        fi
    else
        fatal "Specified *.ipa file does not exist."
    fi
else
    fatal "You must choose an *.ipa file."
fi

}

# 建立工作目录
makeWorkingPath() {

# 先删除
rm -rf "${workingPath}"

# 再建立
mkdir -p "${workingPath}"

return 0

}

# 解压
doUnzip() {
/usr/bin/unzip -q "${originalIpaPath}" -d "${workingPath}"

#检测Payload目录是否存在
if [ -d "${workingPath}" ];then
    return 0
else
    fatal "Unzip failed."
fi

}

# 修改Bundle ID
changeBundleID() {

# 修改Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundleID" "${infoPlistPath}"

# 改后的文件如果验证不正确，则报错退出
/usr/bin/plutil -lint "${infoPlistPath}" >/dev/null 2>&1 || fatal "Invalid plist at ${infoPlistPath}."

# 如果iTunesMetadata.plist存在，则修改
if [ -n "${iTunesMetadataPath}" ];then
    /usr/libexec/PlistBuddy -c "Set :softwareVersionBundleId $bundleID" "${iTunesMetadataPath}"
    # 改后的文件如果验证不正确，则报错退出
    /usr/bin/plutil -lint "${iTunesMetadataPath}" >/dev/null 2>&1|| fatal "Invalid plist at ${infoPlistPath}."
fi

return 0

}

# 复制描述文件
doProvisioning() {

/bin/rm -rf "${embedPath}"
/bin/cp -rp "${mobileprovisionPath}" "${embedPath}"

return 0

}

# 检查描述文件
checkProvisioning() {

local identifier=`cat "${embedPath}"|grep -a -A1 application-identifier|sed -n "/application-identifier/{n;p;}"|sed "s/^.*\<string\>//;s/\<\/string\>//"`
local bundleInIdentifier=${identifier#*.}
local lastComponent=${identifier##*.}

# 如果描述文件是通配符*的，或者Info.plist文件里包含描述文件里的身份，就是有效的
if [[ "${lastComponent}" == "*" || `cat ${infoPlistPath}` =~ "${bundleInIdentifier}" ]];then
    return 0
else
    fatal "Provisioning profile does not match."
fi

}

# 重建entitlement
doEntitlement() {

/usr/bin/security cms -D -i "${mobileprovisionPath}" >"${workingPath}/entitlements.plist"

# 挑出Entitlements标签的内容，单独覆盖保存为plist
plutil -extract Entitlements xml1 "${workingPath}/entitlements.plist"

# 重设entitlement路径
entitlementPath="${workingPath}/entitlements.plist"

return 0

}


# 签名
doCodeSigning() {

# codesign的参数字符串
arguments="-fs \"${identity}\""

# 获得OSX系统版本号
systemVersion=`cat /System/Library/CoreServices/SystemVersion.plist|grep -a -A1 ProductVersion|sed -n "/ProductVersion/{n;p;}"|sed "s/^.*\<string\>//;s/\<\/string\>//"`
local version[0]=${systemVersion%%.*}
local version[1]=`echo ${systemVersion#*.}|sed "s/\..*$//"`

# 判断版本号
if [[ "${version[0]}" -lt 10 || ("${version[0]}" -eq 10 && "${version[1]}" -le 9) ]];then

    # OSX 10.9之前的系统

    #增加|resourceRulesArgument|参数
    local resourceRulesArgument="--resource-rules=\"`dirname $0`/ResourceRules.plist\""
    arguments="${arguments} ${resourceRulesArgument}"

else

    # OSX 10.10以及之后的系统

    # 如果Info.plist文件里包含CFBundleResourceSpecification键值
    if [[ `cat "${infoPlistPath}"` =~ /CFBundleResourceSpecification/ ]];then

        # 删除CFBundleResourceSpecification键值，覆盖保存
        /usr/libexec/PlistBuddy -c "Delete :CFBundleResourceSpecification" "${infoPlistPath}" >/dev/null 2>&1

        # 改后的文件如果验证不正确，则报错退出
        /usr/bin/plutil -lint "${infoPlistPath}" >/dev/null 2>&1|| fatal "Invalid plist at ${infoPlistPath}."

    fi

    # 增加|noStrictArgument|参数
    local noStrictArgument="--no-strict"
    arguments="${arguments} ${noStrictArgument}"

fi

# 如果|entitlementPath|路径非空
if [ -n "${entitlementPath}" ];then

    # 且指向的文件存在
    if [ -e "${entitlementPath}" ];then

        # 增加|entitlementArgument|参数
        entitlementArgument="--entitlements=\"${entitlementPath}\""
        arguments="${arguments} ${entitlementArgument}"

    fi

fi

# 增加|appPathArgument|参数
local appPathArgument="\"${appPath}\""
arguments="${arguments} ${appPathArgument}"


# 判断SWIFT目录是否存在
if [ -d "${workingPath}/SwiftSupport" ];then
    for dylib in `ls "${workingPath}/SwiftSupport"`
    do
        /usr/bin/codesign -fs "${identity}" "${workingPath}/SwiftSupport/${dylib}"
    done
fi

# 执行codesign命令
/usr/bin/codesign $arguments

return 0

}

# 验证签名
checkCodesigning() {

verificationResult=`/usr/bin/codesign -v "${appPath}"`

# 如果验证结果为空，验证成功
if [ -z "${verificationResult}" ];then
    return 0
else
    fatal "Signing failed".
fi

}

# 压缩
doZip() {

# 定义目标路径, 文件名加上-resigned
local originalName=`basename "${originalIpaPath}"`
local destinationPath="`dirname ${originalIpaPath}`/${originalName%.*}-resigned.ipa"

# 记录当前路径
currentPath=`pwd`

# 进入|workingPath|再压缩，否则压缩包的内容结构会有问题
cd "${workingPath}"

# zip命令
/usr/bin/zip -qry "${destinationPath}" "."

# 回到原路径
cd "${currentPath}"

return 0

}


######################## 重签名 ########################

# 检查签名字符串
checkIdentity

# 验证ipa文件
checkIpa

# 建立工作目录
makeWorkingPath

# 解压
doUnzip

# 声明解压后的一些文件路径变量
appPath=`find "${workingPath}/Payload" -type d -name "*.app"|head -1`
infoPlistPath=`find "${appPath}" -maxdepth 1 -type f -name "Info.plist"`
iTunesMetadataPath=`find "${workingPath}" -maxdepth 1 -type f -name "*.plist"|head -1`
embedPath=`find "${appPath}" -type f -name "embedded.mobileprovision"`

# 检测上面定义的文件是否存在
if [ -n "${appPath}" ];then
    if [ -n "${infoPlistPath}" ];then
        :
    else
        fatal "Info.plist file does not exist."
    fi
else
    fatal "*.app directory does not exist."
fi

# 如果Bundle ID非空
if [ -n "${bundleID}" ];then
    #修改Bundle ID
    changeBundleID
fi

# 如果描述文件路径非空，且指向的文件存在
if [ -e "${mobileprovisionPath}" ];then
    # 检查描述文件
    checkProvisioning
    # 复制描述文件
    doProvisioning
    # 重建entitlement
    doEntitlement
fi

# 签名
doCodeSigning

# 验证签名
checkCodesigning

# 压缩
doZip

# 清理工作目录
# 下次执行脚本自动清理|workingPath|工作目录
