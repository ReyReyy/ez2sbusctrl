#!/bin/bash

# 配置
DOMAIN="yourProxyDomain.com"
SNI="yourRealitySNI.com"
PBK="yourRealityPublickKey"

USER_CSV="/path/to/users.csv"
LINKS_DIR="/path/to/subscription/files"
TEMP_USER_CSV="/tmp/users.csv"
USER_TABLE_URL="https://yourUserServer.com/a/super/freaking/long/path/users.csv"


# 节点列表 “节点代号：端口”
REGION_LIST=(
    "hk:17919" 
    "mo:17414" 
    "tw:30678" 
    # 可添加更多节点
)

# 多语言支持（虽然没什么用）
declare -A PROXYNAME_MAP_ZH_HANS=(
    ["hk"]="香港" 
    ["mo"]="澳门" 
    ["tw"]="台湾"
    # 添加中文简体节点名称
)

declare -A PROXYNAME_MAP_ZH_HANT=(
    ["hk"]="香港" 
    ["mo"]="澳門" 
    ["tw"]="臺灣"
    # 添加中文繁體節點名稱（給在大陸的港澳台朋友）
)

declare -A PROXYNAME_MAP_EN=(
    ["hk"]="Hong Kong" 
    ["mo"]="Macau" 
    ["tw"]="Taiwan"
    # Add proxy names in English (For someone who'd like to read English)
)

# 下载用户表文件到缓存目录
curl -s -o "$TEMP_USER_CSV" "$USER_TABLE_URL"

# 检查用户表文件是否存在并且不为空
if [[ ! -s "$TEMP_USER_CSV" ]]; then
    echo "用户表文件下载失败或为空，操作中止。"
    exit 1
fi

# 检查是否传递了 --force 参数
FORCE_UPDATE=false
if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
    FORCE_UPDATE=true
fi

# 计算MD5值并进行对比，若MD5改变或者传递了 --force 参数，则更新链接文件
if [[ "$FORCE_UPDATE" == true ]] || [[ $(md5sum "$TEMP_USER_CSV" | awk '{print $1}') != $(md5sum "$USER_CSV" | awk '{print $1}') ]]; then
    mv "$TEMP_USER_CSV" "$USER_CSV"
    echo "用户表文件已更新。"

    # 清空并重新生成链接目录
    rm -rf "$LINKS_DIR"
    mkdir -p "$LINKS_DIR"

    # 读取用户表并生成链接，跳过标题行
    sed 1d "$USER_CSV" | while IFS=',' read -r USERNAME UUID LANGUAGE; do
        case $LANGUAGE in
            zh-hans) declare -n PROXYNAME_MAP=PROXYNAME_MAP_ZH_HANS;;
            zh-hant) declare -n PROXYNAME_MAP=PROXYNAME_MAP_ZH_HANT;;
            en) declare -n PROXYNAME_MAP=PROXYNAME_MAP_EN;;
            *) declare -n PROXYNAME_MAP=PROXYNAME_MAP_ZH_HANS;;  # 默认使用简体中文
        esac

        FILE="$LINKS_DIR/${UUID}.txt"
        echo "# $USERNAME" > "$FILE"

        for region_port in "${REGION_LIST[@]}"; do
            REGION=${region_port%%:*}
            PORT=${region_port##*:}

            # 根据语言映射 PROXYNAME，如果没有找到映射则使用 REGION 名称
            PROXYNAME="${PROXYNAME_MAP[$REGION]:-$REGION}"

            # 添加链接 可根据使用的节点协议自行更改
            echo "vless://${UUID}@${REGION}.${DOMAIN}:${PORT}?type=tcp&fp=chrome&pbk=${PBK}&security=reality&sni=${SNI}#${PROXYNAME}" >> "$FILE"
            echo "" >> "$FILE"  # 在链接之间添加一个空行 (｡･ω･｡)
        done
    done

    echo "VLESS 链接文件已更新。"
else
    echo "用户表文件未变化，无需更新 VLESS 链接文件。"
    rm "$TEMP_USER_CSV"
fi