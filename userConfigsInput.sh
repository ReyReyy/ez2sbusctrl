#!/bin/bash

# 配置
TAG="yourInboundTag"
USER_CSV="/etc/sing-box/users.csv"
JSON_FILE="/etc/sing-box/config.json"
TEMP_JSON="/tmp/config_temp.json"
TEMP_USER_CSV="/tmp/users.csv"
USER_TABLE_URL="https://yourUserServer.com/a/super/freaking/long/path/users.csv"

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

# 计算MD5值并进行对比，若MD5改变或者传递了 --force 参数，则更新文件
if [[ "$FORCE_UPDATE" == true ]] || [[ $(md5sum "$TEMP_USER_CSV" | awk '{print $1}') != $(md5sum "$USER_CSV" | awk '{print $1}') ]]; then
    mv "$TEMP_USER_CSV" "$USER_CSV"
    echo "用户表文件已更新。"

    # 读取用户表文件并生成用户数组
    user_entries=$(awk -F, 'NR>1 { printf("{\"name\": \"%s\", \"uuid\": \"%s\"},", $1, $2) }' "$USER_CSV")

    # 去掉最后一个多余的逗号，并添加方括号形成数组
    user_entries="[${user_entries%,}]"

    # 调试输出用户数组，检查格式是否正确
    echo "生成的用户数组: $user_entries"

    # 手动构建 jq 命令，直接传递用户数组字符串
    jq ".inbounds |= map(if .tag == \"$TAG\" then .users = $user_entries else . end)" "$JSON_FILE" > "$TEMP_JSON"

    # 检查更新后的 JSON 文件是否为空，以防止误覆盖原有配置文件
    if [[ ! -s "$TEMP_JSON" ]]; then
        echo "更新后的 JSON 文件为空，操作中止。"
        exit 1
    fi

    # 替换原 JSON 文件
    mv "$TEMP_JSON" "$JSON_FILE"

    # 重载 sing-box 服务
    systemctl reload sing-box

    echo "JSON 文件已更新并重载 sing-box 服务。"
else
    echo "用户表文件未变化，无需更新 JSON 文件。"
    rm "$TEMP_USER_CSV"
fi