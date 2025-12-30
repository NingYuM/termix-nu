#!/bin/bash

set -e

# Default configuration
SERVER_URL=${SERVER_URL:-"http://trantor2-installer.app.terminus.io"}
# Set defaults for parameters
SMART_MODE=false
NON_INTERACTIVE=false
ERDA_COOKIE=""
ERDA_TOKEN=""
ERDA_BASE_URL="https://erda.cloud"
ORG_NAME="terminus"
PROJECT_ID=""
APP_NAME="trantor2"
BRANCH="develop"
PIPELINE_YML_NAME=".erda/pipelines/trantor-artifact-transfer.yml"
PIPELINE_TEMPLATE="trantor-artifact-transfer.yml"
TIMEOUT_MINUTES=30
ARTIFACT_URL=""
HISTORY_FILE="$HOME/.trantor_artifact_transfer_history"
HISTORY_MAX=5
OUTPUT_FORMAT="none"  # Options: json, none (default: none)

# Auto-inlined libraries

# Begin content from: common.sh

# Function for logging
log() {
  if [ "$QUIET_MODE" != "yes" ]; then
    if [ "$1" = "-n" ]; then
      shift
      echo -n >&2 "$@"
    else
      echo >&2 "$@"
    fi
  fi
}

# Parse JSON without dependencies
parse_json_field() {
  local field="$1"
  local result=$(cat)

  # Fallback for nested fields - split by dots and extract step by step
  local fields
  IFS='.' read -ra fields <<< "$field"

  # For simple non-nested case
  if [ ${#fields[@]} -eq 1 ]; then
    # Match string values (in quotes)
    string_value=$(echo "$result" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed "s/\"${field}\"[[:space:]]*:[[:space:]]*\"//;s/\"$//")
    if [ -n "$string_value" ]; then
      echo "$string_value"
      return
    fi

    # Match boolean values or numbers (not in quotes)
    bool_or_num=$(echo "$result" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[a-zA-Z0-9][a-zA-Z0-9]*" | sed "s/\"${field}\"[[:space:]]*:[[:space:]]*//;s/[,}]$//")
    if [ -n "$bool_or_num" ]; then
      echo "$bool_or_num"
      return
    fi

    # Return empty if no match
    echo ""
    return
  fi

  # Handle nested fields case
  local idx=0
  local fields_len=${#fields[@]}
  for part in "${fields[@]}"; do
    # Extract the value for this field level
    result=$(echo "$result" | grep -o "\"${part}\"[[:space:]]*:[[:space:]]*{.*}" ||
             echo "$result" | grep -o "\"${part}\"[[:space:]]*:[[:space:]]*\[[^]]*\]" ||
             echo "$result" | grep -o "\"${part}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" ||
             echo "$result" | grep -o "\"${part}\"[[:space:]]*:[[:space:]]*[a-zA-Z0-9][a-zA-Z0-9]*")

    # Strip the field name part, keep just the value
    result=$(echo "$result" | sed "s/\"${part}\"[[:space:]]*:[[:space:]]*//")

    # If it's the final field, extract just the value
    if [ "$idx" -eq "$((fields_len - 1))" ]; then
      # If it's a string value in quotes
      if [[ "$result" =~ ^\"(.*)\"$ ]]; then
        echo "$result" | sed 's/^"//;s/"$//'
      else
        # Clean up any trailing commas or braces for boolean/numeric values
        echo "$result" | sed 's/[,}]$//'
      fi
    fi
    idx=$((idx+1))
  done
}

# Function for JSON formatting
format_json() {
  if command -v jq &> /dev/null; then
    jq .
  else
    cat
  fi
}

# Show help message banner
show_banner() {
  log "═══════════════════════════════════════════════════════════"
  log "$@"
  log "═══════════════════════════════════════════════════════════"
}

# Function to check if a command exists
check_command() {
  command -v "$1" &> /dev/null
}

select_menu() {
    local prompt="$1"
    local search_col="$2"
    shift 2
    local items=("$@")

    get_col() {
        local line="$1"
        local col="$2"
        IFS='|' read -r -a parts <<< "$line"
        echo "${parts[col]}"
    }

    # 计算未匹配字符数
    calc_unmatched_chars() {
        local field="$1"
        local search="$2"
        local field_len=${#field}
        local search_len=${#search}
        # 移除特殊字符 ^ 和 $ 计算实际搜索长度
        search=${search#^}
        search=${search%$}
        search_len=${#search}
        local unmatched=$((field_len - search_len))
        echo "$unmatched"
    }

    # 显示搜索语法帮助
    show_search_help() {
        echo "搜索语法帮助：" >&2
        echo "  普通搜索：输入关键词，匹配包含该关键词的项" >&2
        echo "  前缀匹配：以 ^ 开头，如 ^trantor 匹配以 trantor 开头的项" >&2
        echo "  后缀匹配：以 $ 结尾，如 trantor$ 匹配以 trantor 结尾的项" >&2
        echo "  精确匹配：同时使用 ^ 和 \$，如 ^trantor$ 只匹配完全等于 trantor 的项" >&2
        echo "  通配符：使用 * 代表任意字符，如 t*2 匹配 t 开头 2 结尾的项" >&2
        echo "结果将按未匹配字符数从少到多排序" >&2
    }

    local input=""
    while true; do
        echo -n "$prompt (按回车搜索，空行退出，?帮助)：${input:+"[$input] "}" >&2
        read -r new_input || return 1
        
        # 显示帮助
        if [[ "$new_input" == "?" ]]; then
            show_search_help
            continue
        fi
        
        # If new input is empty but we have previous input, keep using it
        if [[ -z "$new_input" && -n "$input" ]]; then
            # Empty input with existing search term continues with same term
            :
        elif [[ -z "$new_input" ]]; then
            # Empty input with no previous search term exits
            echo "已退出" >&2 && return 1
        else
            # Update the input with new search term
            input="$new_input"
        fi

        local filtered=()
        local unmatched_values=()
        local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
        
        # 检查是否使用了特殊匹配语法
        local match_start=0
        local match_end=0
        local has_wildcard=0
        if [[ "$input_lower" == ^* ]]; then
            match_start=1
        fi
        if [[ "$input_lower" == *$ ]]; then
            match_end=1
        fi
        if [[ "$input_lower" == *"*"* ]]; then
            has_wildcard=1
        fi
        
        # 移除特殊字符以便进行实际匹配
        local search_term="${input_lower}"
        search_term="${search_term#^}"
        search_term="${search_term%$}"
        
        for item in "${items[@]}"; do
            local field=$(get_col "$item" "$search_col")
            local field_lower=$(echo "$field" | tr '[:upper:]' '[:lower:]')
            local matched=0
            
            # 根据不同的匹配模式进行匹配
            if (( has_wildcard == 1 )); then
                # 通配符匹配
                # 将搜索模式转换为 bash 模式匹配
                local pattern="${search_term}"
                if [[ "$field_lower" == $pattern ]]; then
                    matched=1
                fi
            elif (( match_start == 1 && match_end == 1 )); then
                # 精确匹配
                if [[ "$field_lower" == "$search_term" ]]; then
                    matched=1
                fi
            elif (( match_start == 1 )); then
                # 前缀匹配
                if [[ "$field_lower" == "$search_term"* ]]; then
                    matched=1
                fi
            elif (( match_end == 1 )); then
                # 后缀匹配
                if [[ "$field_lower" == *"$search_term" ]]; then
                    matched=1
                fi
            else
                # 包含匹配（默认）
                if [[ "$field_lower" == *"$search_term"* ]]; then
                    matched=1
                fi
            fi
            
            if (( matched == 1 )); then
                filtered+=("$item")
                # 计算未匹配字符数并存储
                unmatched_values+=("$(calc_unmatched_chars "$field_lower" "$input_lower")")
            fi
        done

        if [[ ${#filtered[@]} -eq 0 ]]; then
            echo "❌ 没有匹配项，请重新输入。" >&2
            continue
        fi

        # 按未匹配字符数排序
        local sorted_filtered=()
        local sorted_unmatched=()
        
        # 创建索引数组
        local indices=()
        for i in "${!filtered[@]}"; do
            indices+=("$i")
        done
        
        # 冒泡排序（按未匹配字符数从小到大）
        for ((i=0; i<${#indices[@]}; i++)); do
            for ((j=0; j<${#indices[@]}-i-1; j++)); do
                if (( unmatched_values[indices[j]] > unmatched_values[indices[j+1]] )); then
                    # 交换索引
                    local temp=${indices[j]}
                    indices[j]=${indices[j+1]}
                    indices[j+1]=$temp
                fi
            done
        done
        
        # 使用排序后的索引重新组织数组
        for i in "${indices[@]}"; do
            sorted_filtered+=("${filtered[i]}")
            sorted_unmatched+=("${unmatched_values[i]}")
        done
        
        # 更新filtered数组为排序后的数组
        filtered=("${sorted_filtered[@]}")
        unmatched_values=("${sorted_unmatched[@]}")

        local max_show=10
        local total=${#filtered[@]}
        local shown=0
        echo "🔍 匹配结果 (按未匹配字符数排序)：" >&2
        for i in "${!filtered[@]}"; do
            if (( i < max_show )); then
                local field_name=$(get_col "${filtered[i]}" "$search_col")
                echo "  $((i+1))) $field_name (未匹配: ${unmatched_values[i]})" >&2
                ((shown++))
            fi
        done

        if (( total > max_show )); then
            echo "  ...其余 $((total - max_show)) 条匹配结果" >&2
        fi

        # 添加"修改搜索词"选项
        local change_option=0
        echo "  $change_option) 🔁 修改搜索词" >&2

        echo -n "请输入编号选择：" >&2
        read -r idx
        if [[ "$idx" =~ ^[0-9]+$ ]]; then
            if (( idx >= 1 && idx <= shown )); then
                echo "${filtered[idx-1]}"
                return 0
            elif (( idx == change_option )); then
                continue  # 回到搜索输入
            fi
        fi

        echo "⚠️ 无效编号，请重试。" >&2
    done
}

# End content from: common.sh

# Begin content from: erda.sh

# Check if a JSON response indicates a failure (success=false)
check_erda_response() {
  local response_file="$1"

  # Use parse_json_field to extract success value
  local success_value=$(cat "$response_file" | parse_json_field "success")

  # Check if success is explicitly false
  if [ "$success_value" = "false" ]; then
    # Extract error message and code if available
    local error_msg=$(cat "$response_file" | parse_json_field "err.msg")
    local error_code=$(cat "$response_file" | parse_json_field "err.code")

    # Log the error
    if [ -n "$error_msg" ]; then
      log "Error: API returned failure: $error_msg (code: $error_code)"
    else
      log "Error: API returned success:false without specific error message"
    fi

    # Display the response for debugging
    cat "$response_file" | format_json >&2

    return 1
  fi

  return 0
}

# Wrapper function for curl that handles Erda API specifics
# Usage: erda_api_curl --creds FILE [curl_options] "{base_url}/api/{org_name}/path"
erda_api_curl() {
  local creds_file=""
  local curl_args=()
  local local_base_url=""
  local local_org_name=""
  local local_cookie=""
  local local_token=""
  local has_url=false
  local url=""

  # First, parse arguments to extract --creds
  if [[ "$1" != "--creds" ]]; then
    log "Error: --creds parameter is required"
    return 1
  fi

  creds_file="$2"
  shift 2

  # Validate and parse the credentials file
  if [ ! -f "$creds_file" ]; then
    log "Error: Credentials file '$creds_file' not found"
    return 1
  fi

  # Parse credentials into local variables
  local_cookie=$(cat "$creds_file" | parse_json_field "erda_cookie")
  local_token=$(cat "$creds_file" | parse_json_field "erda_token")
  local_org_name=$(cat "$creds_file" | parse_json_field "org_name")
  local_base_url=$(cat "$creds_file" | parse_json_field "base_url")

  # Check that we got all required credentials
  if [ -z "$local_org_name" ] || [ -z "$local_base_url" ] || { [ -z "$local_cookie" ] && [ -z "$local_token" ]; }; then
    log "Error: Could not parse credentials from '$creds_file'"
    return 1
  fi

  # Process arguments to extract URL with placeholders and preserve curl options
  for arg in "$@"; do
    if [[ "$arg" == *"{base_url}"* || "$arg" == *"{org_name}"* ]] && [ "$has_url" = false ]; then
      # This argument contains our placeholders, it's the URL
      url="$arg"

      # Replace the placeholders with actual values
      url="${url/"{base_url}"/$local_base_url}"
      url="${url/"{org_name}"/$local_org_name}"

      has_url=true
    else
      # Add all other arguments to curl arguments
      curl_args+=("$arg")
    fi
  done

  if [ "$has_url" = false ]; then
    log "Error: No URL with {base_url} or {org_name} placeholders provided"
    return 1
  fi

  # Create a temporary file for the response
  local temp_response=$(mktemp)
  local output_file=""
  local output_arg_index=-1
  local headers_file=$(mktemp)

  # Find if there's an output file specified (-o or --output)
  for i in "${!curl_args[@]}"; do
    if [ "${curl_args[$i]}" == "-o" ] || [ "${curl_args[$i]}" == "--output" ]; then
      output_arg_index=$i
      output_file="${curl_args[$i+1]}"
      break
    fi
  done

  # If output file is specified, temporarily redirect output to our temp file
  if [ $output_arg_index -ne -1 ]; then
    # Store the original output file path
    orig_output="${curl_args[$output_arg_index+1]}"
    # Replace with our temp file
    curl_args[$output_arg_index+1]="$temp_response"
  else
    # Otherwise, add output redirection to temp file
    curl_args+=("-o" "$temp_response")
  fi

  # Add authentication header (prefer token when available)
  if [ -n "$local_token" ]; then
    curl_args+=("-H" "Authorization: Bearer $local_token")
  elif [ -n "$local_cookie" ]; then
    curl_args+=("--cookie" "$local_cookie")
  fi

  # Add header dump to analyze content type
  curl_args+=("--dump-header" "$headers_file")

  # Execute curl with the constructed arguments
  local curl_status=0
  curl "${curl_args[@]}" "$url" || curl_status=$?

  # Check for API response with success: false for JSON responses
  if [ $curl_status -eq 0 ]; then
    # Check if the response is JSON by looking at Content-Type header
    if grep -i "Content-Type:.*application/json" "$headers_file" >/dev/null 2>&1 ||
       head -c 1 "$temp_response" | grep -q '{'; then

      # Check the response using our new function
      if ! check_erda_response "$temp_response"; then
        # If an original output file was specified, copy the error response there too
        if [ -n "$output_file" ]; then
          cp "$temp_response" "$orig_output"
        fi

        # Clean up and return error
        rm -f "$temp_response" "$headers_file"
        return 1
      fi
    fi
  fi

  # If original output file was specified, copy response there
  if [ -n "$output_file" ]; then
    cp "$temp_response" "$orig_output"
  else
    # If no output file was specified, output the response to stdout
    cat "$temp_response"
  fi

  # Clean up
  rm -f "$temp_response" "$headers_file"
  return $curl_status
}

# 从 authorize_url 提取 schema+host
get_uc_base_url_from_authorize_url() {
  local authorize_url="$1"
  # 提取 schema://host
  local uc_url=$(echo "$authorize_url" | sed -E 's#^((https?://[^/]+)).*#\1#')
  if [ -z "$uc_url" ]; then
    return 1
  fi
  echo "$uc_url"
}

# Function to get the OpenAPI URL from base URL
get_openapi_url() {
  local base_url="$1"

  # Try to get the OpenAPI URL from metadata.json
  local metadata_url="${base_url}/metadata.json"
  local metadata_response=""
  if ! metadata_response=$(curl -s -f -XGET "${metadata_url}"); then
    echo "Error: Could not fetch metadata.json from ${base_url}" >&2
    return 1
  fi

  # Extract the OpenAPI URL using parse_json_field
  local openapi_url=$(echo "$metadata_response" | parse_json_field "openapi_public_url")

  if [[ -z "$openapi_url" ]]; then
    echo "Error: Could not find openapi_public_url in metadata.json" >&2
    return 1
  fi

  echo "$openapi_url"
  return 0
}

# Function to login to Erda API and save credentials
erda_login() {
  local base_url="$1"
  local org_name="$2"
  local username="$3"
  local password="$4"
  local output_file="$5"

  # Validate input parameters
  if [ -z "$base_url" ] || [ -z "$org_name" ] || [ -z "$username" ] || [ -z "$password" ] || [ -z "$output_file" ]; then
    log "Error: base_url, org_name, username, password, and output file are required for login"
    return 1
  fi

  # Get openapi_url using the helper function
  log "Determining OpenAPI URL from $base_url"
  local openapi_url=""
  if ! openapi_url=$(get_openapi_url "$base_url"); then
    log "Error: Failed to determine OpenAPI URL from $base_url"
    return 1
  fi
  log "Found OpenAPI URL: $openapi_url"

  # Prepare login payload
  local payload="{\"username\":\"$username\",\"password\":\"$password\"}"
  local login_url="${openapi_url}/login"
  local temp_response=$(mktemp)

  log "Logging in to Erda as $username"

  # Make login request
  if ! curl -s -f -X POST "$login_url" \
       -H "Content-Type: application/json" \
       -d "$payload" \
       -o "$temp_response"; then
    log "Error: Failed to connect to login service"
    rm -f "$temp_response"
    return 1
  fi

  # Extract session ID and token from response
  local session_id=$(cat "$temp_response" | parse_json_field "sessionid")
  local access_token=$(cat "$temp_response" | parse_json_field "token.access_token")
  local token_type=$(cat "$temp_response" | parse_json_field "token.token_type")

  if [ -z "$session_id" ] && [ -z "$access_token" ]; then
    log "Error: Failed to extract session ID or access token from response"
    cat "$temp_response" | format_json >&2
    rm -f "$temp_response"
    return 1
  fi

  # Extract user ID using parse_json_field
  local user_id=$(cat "$temp_response" | parse_json_field "user.id")
  if [ -z "$user_id" ]; then
    user_id=$(cat "$temp_response" | parse_json_field "id")
  fi

  # Extract username from response using parse_json_field
  local username_resp=$(cat "$temp_response" | parse_json_field "user.username")
  if [ -z "$username_resp" ]; then
    username_resp=$(cat "$temp_response" | parse_json_field "username")
  fi

  # Create the cookie value if session exists
  local cookie=""
  if [ -n "$session_id" ]; then
    cookie="OPENAPISESSION=$session_id"
  fi

  # Store credentials in the output file, including org_name
  cat > "$output_file" << EOF
{
  "erda_cookie": "$cookie",
  "erda_token": "$access_token",
  "erda_token_type": "$token_type",
  "user_id": "$user_id",
  "username": "$username_resp",
  "base_url": "$base_url",
  "org_name": "$org_name"
}
EOF

  log "Successfully logged in as $username_resp"
  rm -f "$temp_response"
  return 0
}

# Function to login to Erda API via SMS code and save credentials
erda_login_by_sms_code() {
  local base_url="$1"
  local org_name="$2"
  local mobile="$3"
  local output_file="$4"

  if [ -z "$base_url" ] || [ -z "$org_name" ] || [ -z "$mobile" ] || [ -z "$output_file" ]; then
    log "Error: base_url, org_name, mobile, and output file are required for SMS login"
    return 1
  fi

  # 直接获取 authorize_url
  local authorize_url
  authorize_url=$(curl -s -I "$base_url" | grep -i '^Location:' | head -1 | awk '{print $2}' | tr -d '\r\n')
  if [ -z "$authorize_url" ]; then
    log "Error: 无法获取 authorize 跳转 URL"
    return 1
  fi

  # 解析 UC 域名
  local uc_base_url
  if ! uc_base_url=$(get_uc_base_url_from_authorize_url "$authorize_url"); then
    log "Error: 无法从 authorize_url 解析 UC 域名"
    return 1
  fi

  # Step 1: 获取图形验证码
  local captcha_resp_file=$(mktemp)
  if ! curl -s -f -X GET "$uc_base_url/api/user/web/get-captcha" -o "$captcha_resp_file"; then
    log "Error: 获取图形验证码失败"
    rm -f "$captcha_resp_file"
    return 1
  fi
  local captcha_token=$(cat "$captcha_resp_file" | parse_json_field "result.token")
  local captcha_img=$(cat "$captcha_resp_file" | parse_json_field "result.imageUrl")
  if [ -z "$captcha_token" ] || [ -z "$captcha_img" ]; then
    log "Error: 无法解析图形验证码信息"
    rm -f "$captcha_resp_file"
    return 1
  fi
  # 生成临时 HTML 文件，内嵌 data:image/gif;base64 的字符串，自动用默认浏览器打开
  local captcha_html_file=$(mktemp).html
  cat > "$captcha_html_file" <<EOF
<html><body><img src="$captcha_img" /></body></html>
EOF
  log "已生成验证码页面，正在用默认浏览器打开..."
  open "$captcha_html_file"
  read -p "请输入图片中的验证码: " captcha_code
  rm -f "$captcha_resp_file"

  # Step 2: 发送短信验证码
  local sms_req_file=$(mktemp)
  local sms_payload="{\"prefix\":\"86\",\"mobile\":\"$mobile\",\"captcha\":\"$captcha_code\",\"token\":\"$captcha_token\"}"
  if ! curl -s -f -X POST "$uc_base_url/api/user/web/login/login-send-sms-code" \
    -H "Content-Type: application/json" \
    -d "$sms_payload" -o "$sms_req_file"; then
    log "Error: 发送短信验证码失败"
    rm -f "$sms_req_file" "$captcha_html_file"
    return 1
  fi
  local sms_success=$(cat "$sms_req_file" | parse_json_field "success")
  if [ "$sms_success" != "true" ]; then
    log "Error: 短信验证码发送失败"
    cat "$sms_req_file" | format_json >&2
    rm -f "$sms_req_file" "$captcha_html_file"
    return 1
  fi
  rm -f "$sms_req_file"

  read -p "请输入收到的短信验证码: " sms_code

  # Step 3: 用短信验证码登录
  local login_resp_file=$(mktemp)
  local login_payload="{\"prefix\":\"86\",\"mobile\":\"$mobile\",\"smsCode\":\"$sms_code\"}"
  # -c 写入 cookie，-L 跟随跳转
  if ! curl -s -c "$login_resp_file.cookie" -b "$login_resp_file.cookie" -L -X POST "$uc_base_url/api/user/web/login/login-by-sms-code" \
    -H "Content-Type: application/json" \
    -d "$login_payload" -o /dev/null; then
    log "Error: 短信验证码登录失败"
    rm -f "$login_resp_file" "$login_resp_file.cookie" "$captcha_html_file"
    return 1
  fi

  # Step 4: 完成 OAuth 跳转，获取 OPENAPISESSION
  local authorize_resp_file=$(mktemp)
  curl -s -b "$login_resp_file.cookie" -c "$login_resp_file.cookie" -I "$authorize_url" -o "$authorize_resp_file"
  local logincb_url=$(grep -i '^location:' "$authorize_resp_file" | tail -1 | awk '{print $2}' | tr -d '\r\n')
  rm -f "$authorize_resp_file"
  if [ -z "$logincb_url" ]; then
    log "Error: 未能获取 logincb 跳转 URL"
    rm -f "$login_resp_file" "$login_resp_file.cookie" "$captcha_html_file"
    return 1
  fi
  curl -s -b "$login_resp_file.cookie" -c "$login_resp_file.cookie" "$logincb_url" -o /dev/null
  local erda_cookie=""
  erda_cookie=$(grep OPENAPISESSION "$login_resp_file.cookie" | awk '{print $6"=" $7}' | paste -sd ';' -)
  if [ -z "$erda_cookie" ]; then
    log "Error: 未能获取 OPENAPISESSION cookie"
    rm -f "$login_resp_file" "$login_resp_file.cookie" "$captcha_html_file"
    return 1
  fi

  cat > "$output_file" <<EOF
{
  "erda_cookie": "$erda_cookie",
  "user_id": "$mobile",
  "username": "$mobile",
  "base_url": "$base_url",
  "org_name": "$org_name"
}
EOF
  log "短信验证码登录成功，凭证已保存"
  rm -f "$login_resp_file" "$login_resp_file.cookie" "$captcha_html_file"
  return 0
}

# Function to manage Erda credentials interactively
manage_erda_credentials() {
  local base_url="$1"
  local org_name="$2"
  local creds_output="$3"

  # Create credentials directory if it doesn't exist
  local creds_dir="${HOME}/.trantor2-installer/erda/credentials"
  mkdir -p "$creds_dir"

  # Define the credentials storage file pattern
  local creds_base_file="${creds_dir}/${base_url//\//_}_${org_name}"

  # Get existing usernames for this base_url and org_name
  local existing_users=()
  if [ -d "$creds_dir" ]; then
    while IFS= read -r file; do
      if [[ "$file" == "${creds_base_file}_"* ]]; then
        local basename_file=$(basename "$file")
        # 跳过 .pwd 文件
        if [[ "$basename_file" == *.pwd ]]; then
          continue
        fi
        local username=$(echo "$basename_file" | sed "s/${base_url//\//_}_${org_name}_//")
        existing_users+=("$username")
      fi
    done < <(find "$creds_dir" -type f -name "${base_url//\//_}_${org_name}_*")
  fi

  local username=""
  local password=""
  local use_existing=false
  local tried_saved_password=false

  # If we have existing credentials, offer them as options
  if [ ${#existing_users[@]} -gt 0 ]; then
    log "Found existing credentials for ${base_url} (${org_name}):"
    for i in "${!existing_users[@]}"; do
      log "  $((i+1)). ${existing_users[$i]}"
    done
    log "  $((${#existing_users[@]}+1)). Use a new account"

    local choice
    # Set default choice to 1 if existing users are available
    if [ ${#existing_users[@]} -gt 0 ]; then
      default_choice=1
    else
      default_choice=$((${#existing_users[@]}+1))
    fi
    read -p "Select an option [1-$((${#existing_users[@]}+1))] (default: $default_choice): " choice

    # If no choice is entered, use the default
    if [ -z "$choice" ]; then
      choice="$default_choice"
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#existing_users[@]}" ]; then
      username="${existing_users[$((choice-1))]}"
      use_existing=true
      log "Selected existing account: $username"
    else
      log "Using a new account"
    fi
  fi

  # If not using existing credentials, prompt for username
  if [ "$use_existing" = false ]; then
    read -p "请输入用户名或手机号: " username
  fi

  # Check if credentials exist and are valid
  local creds_file="${creds_base_file}_${username}"
  local password_file="${creds_file}.pwd"
  local need_password=true

  if [ "$use_existing" = true ] && [ -f "$creds_file" ]; then
    # Try to use existing credentials
    cp "$creds_file" "$creds_output"

    # Verify the credentials by making a test API call
    if erda_verify_login "$creds_output"; then
      log "Using cached credentials for $username (valid session)"
      need_password=false
    else
      log "Cached credentials expired for $username, try saved password if available"
      # 尝试用保存的密码自动登录
      if [ -f "$password_file" ]; then
        password=$(cat "$password_file")
        if erda_login "$base_url" "$org_name" "$username" "$password" "$creds_output"; then
          cp "$creds_output" "$creds_file"
          log "Re-login succeeded using saved password for $username"
          need_password=false
          tried_saved_password=true
        else
          log "Saved password login failed for $username, please re-authenticate"
        fi
      fi
    fi
  fi

  # If we need password (new user or expired credentials and saved password failed)
  if [ "$need_password" = true ]; then
    # 新增登录方式选择
    log "请选择登录方式："
    log "  1. 密码登录 (默认)"
    log "  2. 短信验证码登录"
    read -p "输入选项 [1/2] (默认: 1): " login_method
    if [ -z "$login_method" ]; then
      login_method=1
    fi
    if [ "$login_method" = "2" ]; then
      # 手机号即为用户名，无需再次输入
      mobile_input="$username"
      if ! erda_login_by_sms_code "$base_url" "$org_name" "$mobile_input" "$creds_output"; then
        log "Error: 短信验证码登录失败"
        return 1
      fi
      cp "$creds_output" "$creds_file"
      log "Credentials saved for future use (SMS login)"
      # 不保存密码
    else
      # Prompt for password securely (without echoing to terminal)
      read -s -p "Enter password for $username: " password
      log  # Add newline after password input
      # Attempt to login with the provided credentials
      if ! erda_login "$base_url" "$org_name" "$username" "$password" "$creds_output"; then
        log "Error: Authentication failed"
        return 1
      fi
      # Save credentials to the user's credentials directory
      cp "$creds_output" "$creds_file"
      log "Credentials saved for future use"
      # 保存密码到 .pwd 文件，权限设为 600
      echo -n "$password" > "$password_file"
      chmod 600 "$password_file"
    fi
  elif [ "$tried_saved_password" = true ]; then
    # 如果是用保存的密码自动登录成功，确保 .pwd 文件权限正确
    chmod 600 "$password_file" 2>/dev/null || true
  fi

  return 0
}

# Function to verify if credentials are still valid
erda_verify_login() {
  local creds_file="$1"

  # Make a test API call to verify the session
  local test_url="{base_url}/api/{org_name}/users/me"

  # Check if the API call was successful
  if ! erda_api_curl --creds $creds_file -s -f -X GET "$test_url" > /dev/null; then
    log "Error: Failed to verify credentials"
    return 1
  else
    return 0
  fi
}

# End content from: erda.sh

# Begin content from: erda-func.sh

# Download a release from Erda using the curl wrapper
download_release() {
  local creds_file="$1"
  local release_id="$2"
  local output_path="$3"

  # Set quiet mode for curl if needed
  local curl_opts=("-f" "-L")
  if [ "$QUIET_MODE" = "yes" ]; then
    curl_opts+=("-s")
  fi

  # Use our wrapper to download the release
  log "Downloading release ID $release_id to $output_path"
  if erda_api_curl --creds "$creds_file" "${curl_opts[@]}" "{base_url}/api/{org_name}/releases/${release_id}/actions/download" -o "$output_path"; then
    log "Download successful. Saved to $output_path"
    return 0
  else
    log "Error: Download failed."
    return 1
  fi
}

# End content from: erda-func.sh

# Begin content from: erda-func-ext.sh

# Function to get credentials from the server
get_build_credentials() {
  local server_url="$1"
  local build_id="$2"
  local build_token="$3"
  local temp_creds="$4"

  local creds_url="${server_url}/build/${build_id}/credentials?build_token=${build_token}"
  log "Retrieving credentials from: $creds_url"

  if ! curl -s -f "$creds_url" -o "$temp_creds"; then
    log "Error: Failed to retrieve credentials."
    return 1
  fi

  return 0
}

# Prepare application by updating pipeline YAML directly through Erda API
prepare_application() {
  local creds_file="$1"
  local project_id="$2"
  local app_name="$3"
  local branch="$4"
  local pipeline_yml_name="$5"
  local server_url="$6"

  log "Preparing application '$app_name' with artifact transfer pipeline..."

  # Get app ID
  local app_id=""
  if ! app_id=$(erda_api_curl --creds "$creds_file" -s -f -X GET \
    "{base_url}/api/{org_name}/applications?pageSize=9999&pageNo=1&projectId=$project_id" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
apps = data.get('data', {}).get('list', [])
for app in apps:
    if app.get('name') == '$app_name':
        print(app.get('id'))
        break
"); then
    log "Error: Failed to get applications or find app ID"
    return 1
  fi

  if [ -z "$app_id" ]; then
    log "Error: Could not find application '$app_name' in project $project_id"
    return 1
  fi

  log "Found application ID: $app_id"

  # Get app details to get Git repo info
  local git_repo_url=""
  if ! git_repo_url=$(erda_api_curl --creds "$creds_file" -s -f -X GET \
    "{base_url}/api/{org_name}/applications/$app_id" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
repo = data.get('data', {}).get('gitRepoNew') or data.get('data', {}).get('gitRepo')
print(repo or '')
"); then
    log "Error: Failed to get application details or Git repository URL"
    return 1
  fi

  if [ -z "$git_repo_url" ]; then
    log "Error: Could not get Git repository URL"
    return 1
  fi

  # Add auth token to Git URL
  local git_token=""
  if ! git_token=$(erda_api_curl --creds "$creds_file" -s -f -X GET \
    "{base_url}/api/{org_name}/applications/$app_id" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
token = data.get('data', {}).get('token')
print(token or '')
"); then
    log "Error: Failed to get Git token"
    return 1
  fi

  if [ -z "$git_token" ]; then
    log "Error: Could not get Git token"
    return 1
  fi

  # Process Git URL to add authentication
  local auth_git_url=""
  if [[ "$git_repo_url" == *"://"* ]]; then
    local protocol=$(echo "$git_repo_url" | cut -d':' -f1)
    local host_path=$(echo "$git_repo_url" | cut -d'/' -f3-)
    auth_git_url="$protocol://git:$git_token@$host_path"
  else
    # Follow base_url's protocol when git_repo_url has no protocol
    local base_url=$(cat "$creds_file" | parse_json_field "base_url")
    local proto="https"
    if [[ "$base_url" == *"://"* ]]; then
      proto="${base_url%%://*}"
    fi
    auth_git_url="$proto://git:$git_token@$git_repo_url"
  fi

  # Clone repo, update pipeline YAML, and push
  local temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT

  log "Cloning repository..."
  if ! git clone -q "$auth_git_url" "$temp_dir"; then
    log "Error: Failed to clone repository"
    return 1
  fi

  cd "$temp_dir"

  # Checkout or create branch
  if git ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
    git checkout -q "$branch"
  else
    git checkout -q --orphan "$branch"
    git rm -rf . >/dev/null 2>&1 || true
  fi

  # Configure git user
  git config user.email "trantor-installer@erda.cloud"
  git config user.name "Trantor Installer"

  # Get pipeline template content
  local pipeline_template_content=""
  if ! pipeline_template_content=$(curl -s -f "$server_url/scripts/trantor-artifact-transfer.yml"); then
    log "Error: Failed to get pipeline template content"
    cd - >/dev/null
    return 1
  fi

  # Write pipeline YAML
  mkdir -p "$(dirname "$pipeline_yml_name")"
  echo "$pipeline_template_content" > "$pipeline_yml_name"

  # Commit and push
  git add "$pipeline_yml_name"
  if [ -n "$(git status --porcelain)" ]; then
    git commit -q -m "Initialize trantor artifact transfer pipeline" 1>&2
    git push -q origin "$branch" 1>&2
  else
    log "No changes to commit on branch $branch"
  fi

  cd - >/dev/null

  log "Application prepared successfully"
  return 0
}

# Start a pipeline build and return the build response by directly calling Erda API
start_pipeline_build() {
  local creds_file="$1"
  local server_url="$2"
  local project_id="$3"
  local app_name="$4"
  local branch="$5"
  local pipeline_yml_name="$6"
  local build_params_file="$7"

  # Get app ID
  local apps_response=$(mktemp)
  if ! erda_api_curl --creds "$creds_file" -s -f -X GET \
    "{base_url}/api/{org_name}/applications?pageSize=9999&pageNo=1&projectId=$project_id" -o "$apps_response"; then
    log "Error: Failed to get applications"
    rm -f "$apps_response"
    return 1
  fi

  local app_id=$(cat "$apps_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
apps = data.get('data', {}).get('list', [])
for app in apps:
    if app.get('name') == '$app_name':
        print(app.get('id'))
        break
")

  if [ -z "$app_id" ]; then
    log "Error: Could not find application '$app_name' in project $project_id"
    rm -f "$apps_response"
    return 1
  fi

  rm -f "$apps_response"

  # Get branch workspace mapping
  local workspace_response=$(mktemp)
  if ! erda_api_curl --creds "$creds_file" -s -f -X GET \
    "{base_url}/api/{org_name}/cicds/actions/app-all-valid-branch-workspaces?appID=$app_id" -o "$workspace_response"; then
    log "Error: Failed to get branch workspace mapping"
    rm -f "$workspace_response"
    return 1
  fi

  local workspace_id=$(cat "$workspace_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
branches = data.get('data', [])
for branch in branches:
    if branch.get('name') == '$branch':
        print(branch.get('workspace', ''))
        break
")

  if [ -z "$workspace_id" ]; then
    log "Error: Could not find workspace ID for branch '$branch'"
    rm -f "$workspace_response"
    return 1
  fi

  rm -f "$workspace_response"

  # Create pipeline
  local pipeline_response=$(mktemp)
  local pipeline_payload=$(cat <<EOF
{
  "appID": $app_id,
  "branch": "$branch",
  "pipelineYmlSource": "gittar",
  "pipelineYmlName": "$pipeline_yml_name",
  "source": "dice",
  "autoRun": false
}
EOF
  )

  if ! erda_api_curl --creds "$creds_file" -s -f -X POST \
    -H "Content-Type: application/json" \
    -d "$pipeline_payload" \
    "{base_url}/api/{org_name}/cicds" -o "$pipeline_response"; then
    log "Error: Failed to create pipeline"
    rm -f "$pipeline_response"
    return 1
  fi

  local pipeline_id=$(cat "$pipeline_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('data', {}).get('id', ''))
")

  if [ -z "$pipeline_id" ]; then
    log "Error: Could not get pipeline ID"
    rm -f "$pipeline_response"
    return 1
  fi

  rm -f "$pipeline_response"

  # Prepare build request payload
  log "Preparing build request for pipeline: $pipeline_yml_name"
  local params_json=""

  # Add parameters from file if provided
  if [ -n "$build_params_file" ] && [ -f "$build_params_file" ]; then
    params_json=$(cat "$build_params_file")
    log "Using pipeline parameters from file"
  else
    params_json="[]"  # Empty parameters array if no file provided
  fi

  # Run pipeline with parameters
  local run_payload=$(cat <<EOF
{
  "pipelineRunParams": $params_json
}
EOF
  )

  local run_response=$(mktemp)
  if ! erda_api_curl --creds "$creds_file" -s -f -X POST \
    -H "Content-Type: application/json" \
    -d "$run_payload" \
    "{base_url}/api/{org_name}/cicds/$pipeline_id/actions/run" -o "$run_response"; then
    log "Error: Failed to run pipeline"
    rm -f "$run_response"
    return 1
  fi

  rm -f "$run_response"

  log "Pipeline started successfully with ID: $pipeline_id"

  local build_response=$(cat <<EOF
{
  "pipeline_id": "$pipeline_id",
  "app_id": "$app_id",
  "project_id": $project_id,
  "app_name": "$app_name"
}
EOF
  )

  # Output the build response
  echo "$build_response"
  return 0
}

# Monitor pipeline execution until completion or timeout by directly calling Erda API
monitor_pipeline_execution() {
  local creds_file="$1"
  local pipeline_id="$2"
  local project_id="$3"
  local timeout_minutes="${4:-30}"  # Default timeout: 30 minutes
  local check_interval="${5:-10}"   # Default interval: 10 seconds

  # Calculate the max number of checks
  local max_checks=$((timeout_minutes * 60 / check_interval))
  local check_count=0

  # Check pipeline status at regular intervals
  log "Monitoring pipeline status..."

  # Print initial marker without newline
  log -n "Pipeline progress: "

  while [ $check_count -lt $max_checks ]; do
    local status_response=$(mktemp)
    if ! erda_api_curl --creds "$creds_file" -s -f -X GET \
      "{base_url}/api/{org_name}/pipelines/$pipeline_id?projectId=$project_id" -o "$status_response"; then
      log "Error: Failed to get pipeline status"
      rm -f "$status_response"
      return 1
    fi

    local status=$(cat "$status_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('data', {}).get('status', 'Unknown'))
")

    local final=$(cat "$status_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
status = data.get('data', {}).get('status', 'Unknown')
print(str(status in ['Success', 'Failed', 'Cancelled', 'Error']).lower())
")

    local success=$(cat "$status_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
status = data.get('data', {}).get('status', 'Unknown')
print(str(status == 'Success').lower())
")

    local error_msg=$(cat "$status_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('data', {}).get('errorMessage', ''))
")

    rm -f "$status_response"

    log -n "*"

    # Exit if pipeline has reached a final state
    if [ "$final" = "true" ]; then
      log ""
      if [ "$success" = "true" ]; then
        log "✅ Pipeline completed successfully"
        # Return a response similar to the old format
        local status_response_json=$(cat <<EOF
{
  "status": "$status",
  "final": true,
  "success": true,
  "error": "$error_msg"
}
EOF
        )
        echo "$status_response_json"
        return 0
      else
        log "❌ Pipeline failed: $error_msg"
        return 1
      fi
    fi

    # Sleep before checking again
    sleep $check_interval
    check_count=$((check_count + 1))
  done

  log "⚠️ Timeout reached while waiting for pipeline to complete"
  return 2  # Special return code for timeout
}

# Function to extract metadata from a specific task in a completed pipeline by directly calling Erda API
extract_task_metadata_from_pipeline() {
  local creds_file="$1"
  local pipeline_id="$2"
  local project_id="$3"
  local task_name="$4"

  # Get pipeline details
  local pipeline_response=$(mktemp)
  if ! erda_api_curl --creds "$creds_file" -s -f -X GET \
    "{base_url}/api/{org_name}/pipelines/$pipeline_id?projectId=$project_id" -o "$pipeline_response"; then
    log "Error: Failed to get pipeline details"
    rm -f "$pipeline_response"
    return 1
  fi

  # Extract temp_url from the rebuild-artifact task metadata
  local temp_url=$(python3 -c "
import sys, json
data = json.load(open('$pipeline_response'))
stages = data.get('data', {}).get('pipelineStages', [])
for stage in stages:
    for task in stage.get('pipelineTasks', []):
        if task.get('name') == '$task_name' and task.get('status') == 'Success':
            metadata = task.get('result', {}).get('metadata', [])
            for item in metadata:
                if item.get('name') == 'temp_url':
                    print(item.get('value', ''))
                    sys.exit(0)
print('')
")

  rm -f "$pipeline_response"

  if [ -n "$temp_url" ]; then
    # Return metadata in the expected format
    local metadata_json=$(cat <<EOF
{
  "temp_url": "$temp_url"
}
EOF
    )
    echo "$metadata_json"
    return 0
  else
    log "Error: Could not extract temp_url from pipeline metadata"
    return 1
  fi
}

# Function to upload an artifact file to Erda and create a release
upload_release() {
  local creds_file="$1"
  local org_id="$2"
  local project_id="$3"
  local artifact_file="$4"
  local version="${5:-""}"  # Optional version parameter

  # Check that required parameters are provided
  if [ -z "$org_id" ]; then
    log "Error: Organization ID is required!"
    return 1
  fi

  if [ -z "$project_id" ]; then
    log "Error: Project ID is required!"
    return 1
  fi

  if [ ! -f "$artifact_file" ]; then
    log "Error: Artifact file '$artifact_file' does not exist!"
    return 1
  fi

  # Extract credentials
  local erda_cookie=$(cat "$creds_file" | parse_json_field "erda_cookie")
  local erda_token=$(cat "$creds_file" | parse_json_field "erda_token")
  local base_url=$(cat "$creds_file" | parse_json_field "base_url")
  local org_name=$(cat "$creds_file" | parse_json_field "org_name")

  # Create a temporary credentials file for erda_api_curl
  local temp_creds=$(mktemp)
  trap "rm -f $temp_creds" EXIT

  cat > "$temp_creds" << EOF
{
  "erda_cookie": "$erda_cookie",
  "erda_token": "$erda_token",
  "org_name": "$org_name",
  "base_url": "$base_url"
}
EOF

  # Get user ID by making an API call
  local user_info_response=$(mktemp)
  if ! erda_api_curl --creds "$temp_creds" \
       "{base_url}/api/{org_name}/users/me" -o "$user_info_response"; then
    log "Error: Failed to get user information"
    rm -f "$user_info_response"
    return 1
  fi

  local user_id=$(cat "$user_info_response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('data', {}).get('id', ''))
")

  if [ -z "$user_id" ]; then
    log "Error: User ID not found in response"
    rm -f "$user_info_response"
    return 1
  else
    log "Using user ID: $user_id"
  fi

  rm -f "$user_info_response"

  # Step 1: Upload the artifact file
  log "Step 1: Uploading artifact file to Erda..."
  local temp_response=$(mktemp)

  if ! erda_api_curl --creds "$temp_creds" -X POST \
       -H "Content-Type: multipart/form-data" \
       -F "file=@$artifact_file" \
       "{base_url}/api/files" -o "$temp_response"; then
    log "Error: Failed to upload artifact file"
    rm -f "$temp_response"
    return 1
  fi

  # Extract the UUID from the response
  local file_uuid=$(cat "$temp_response" | parse_json_field "data.uuid")
  if [ -z "$file_uuid" ]; then
    log "Error: Could not extract file UUID from response"
    cat "$temp_response"
    rm -f "$temp_response"
    return 1
  fi

  log "File uploaded successfully. UUID: $file_uuid"

  # Step 2: Parse the version if not provided
  if [ -z "$version" ]; then
    log "Step 2: Detecting version from the uploaded artifact..."

    if ! erda_api_curl --creds "$temp_creds" \
         "{base_url}/api/{org_name}/releases/actions/parse-version?diceFileID=$file_uuid" \
         -o "$temp_response"; then
      log "Error: Failed to parse version from artifact"
      rm -f "$temp_response"
      return 1
    fi

    version=$(cat "$temp_response" | parse_json_field "data.version")
    if [ -z "$version" ]; then
      log "Error: Could not extract version from response"
      cat "$temp_response"
      rm -f "$temp_response"
      return 1
    fi

    log "Detected version: $version"
  else
    log "Step 2: Using provided version: $version"
  fi

  # Step 3: Check if version is unique
  log "Step 3: Checking if version is unique..."
  local encoded_version=$(echo "$version" | sed 's/+/%2B/g')

  if ! erda_api_curl --creds "$temp_creds" \
       "{base_url}/api/{org_name}/releases/actions/check-version?isProjectRelease=true&orgID=$org_id&projectID=$project_id&version=$encoded_version" \
       -o "$temp_response"; then
    log "Error: Failed to check version uniqueness"
    rm -f "$temp_response"
    return 1
  fi

  local is_unique=$(cat "$temp_response" | parse_json_field "data.isUnique")
  if [ "$is_unique" != "true" ]; then
    log "Error: Version '$version' already exists"
    rm -f "$temp_response"
    return 1
  fi

  log "Version is unique. Proceeding with release creation."

  # Step 4: Create the release
  log "Step 4: Creating release..."

  # Prepare the JSON request body
  local request_body="{\"version\":\"$version\",\"diceFileID\":\"$file_uuid\",\"orgId\":$org_id,\"userId\":\"$user_id\",\"projectID\":$project_id}"

  if ! erda_api_curl --creds "$temp_creds" -X POST \
       -H "Content-Type: application/json" \
       -d "$request_body" \
       "{base_url}/api/{org_name}/releases/actions/upload" \
       -o "$temp_response"; then
    log "Error: Failed to create release"
    rm -f "$temp_response"
    return 1
  fi

  # Extract the release ID from the response
  local release_id=$(cat "$temp_response" | parse_json_field "data.releaseId")
  if [ -z "$release_id" ]; then
    log "Error: Could not extract release ID from response"
    cat "$temp_response"
    rm -f "$temp_response"
    return 1
  fi

  log "Release created successfully!"
  show_banner "Release Information"
  echo "File Name:  $(basename "$artifact_file")"
  echo "Version:    $version"
  echo "Release ID: $release_id"

  # Output the release ID for potential use in subsequent commands
  echo "action meta: release_id=$release_id"
  echo "action meta: release_version=$version"
  local release_url="${base_url}/${org_name}/dop/projects/${project_id}/release/project/${release_id}"
  echo "action meta: release_url=$release_url"

  # Create JSON result for backward compatibility
  local result_json=$(cat <<EOF
{
  "release_id": "$release_id",
  "release_version": "$version",
  "release_url": "$release_url"
}
EOF
  )
  echo "$result_json"

  rm -f "$temp_response"
  return 0
}

# Verify build credentials are valid
verify_build_credentials() {
  local server_url="$1"
  local build_id="$2"
  local build_token="$3"

  local verify_url="${server_url}/build/${build_id}/verify?build_token=${build_token}"
  log "Verifying build credentials..."

  local verify_response=""
  if ! verify_response=$(curl -s -f -X GET "$verify_url"); then
    log "Error: Failed to verify build credentials"
    return 1
  fi

  # Check if the build is verified
  local verified=$(echo "$verify_response" | parse_json_field "verified")
  if [ "$verified" != "true" ]; then
    log "Error: Build verification failed. This build was not created through the proxy."
    return 1
  fi

  log "Build credentials verified successfully."
  return 0
}

# Run a pipeline from start to finish and wait for results by directly calling Erda API
run_pipeline() {
  local creds_file="$1"
  local server_url="$2"
  local project_id="$3"
  local app_name="$4"
  local branch="$5"
  local pipeline_yml_name="$6"
  local build_params_file="$7"
  local timeout_minutes="${8:-30}"
  local task_name="${9:-""}"  # Task name for metadata extraction, optional
  local wait_for_completion="${10:-true}"  # Whether to wait for completion, defaults to true

  # Start the pipeline build
  local build_response=""
  if ! build_response=$(start_pipeline_build "$creds_file" "$server_url" "$project_id" "$app_name" "$branch" "$pipeline_yml_name" "$build_params_file"); then
    return 1
  fi

  # Extract pipeline_id from the response
  local pipeline_id=$(echo "$build_response" | parse_json_field "pipeline_id")
  local app_id=$(echo "$build_response" | parse_json_field "app_id")

  # Validate that we have the required parameters
  if [ -z "$pipeline_id" ]; then
    log "Error: Failed to extract pipeline_id from build response"
    return 1
  fi

  if [ -z "$app_id" ]; then
    log "Error: Failed to extract app_id from build response"
    return 1
  fi

  # Base URL from credentials
  local base_url=$(cat "$creds_file" | parse_json_field "base_url")
  local org_name=$(cat "$creds_file" | parse_json_field "org_name")

  # Display pipeline information
  log "Build pipeline started successfully:"
  log "  Pipeline ID: $pipeline_id"
  log "  Organization: $org_name"
  log "  Project ID: $project_id"
  log "  Application: $app_name (ID: $app_id)"
  log "  Branch: $branch"

  # Construct the nodeId (unencoded)
  local node_id_raw="${project_id}/${app_id}/tree/${branch}/${pipeline_yml_name}"

  # Base64 encode the nodeId
  # Using base64 with -w 0 to avoid line breaks
  local node_id_encoded=$(echo -n "$node_id_raw" | base64 -w 0)

  # Construct the pipeline URL with app_id and pipeline_id
  local pipeline_url="${base_url}/${org_name}/dop/projects/${project_id}/apps/${app_id}/pipeline/obsoleted?nodeId=${node_id_encoded}&pipelineID=${pipeline_id}"

  # Log the pipeline URL
  log "  Pipeline URL: $pipeline_url"

  # If not waiting for completion, return pipeline info immediately
  if [ "$wait_for_completion" = "false" ]; then
    # Return JSON with pipeline information
    local pipeline_info=$(cat <<EOF
{
  "pipeline_id": "$pipeline_id",
  "app_id": "$app_id",
  "pipeline_url": "$pipeline_url"
}
EOF
    )
    echo "$pipeline_info"
    return 0
  fi

  # Monitor the pipeline execution
  local result=""
  if ! result=$(monitor_pipeline_execution "$creds_file" "$pipeline_id" "$project_id" "$timeout_minutes"); then
    return 1
  fi

  # If task_name is provided, extract its metadata
  if [ -n "$task_name" ]; then
    log "Extracting metadata from task: $task_name"
    local metadata=""
    if ! metadata=$(extract_task_metadata_from_pipeline "$creds_file" "$pipeline_id" "$project_id" "$task_name"); then
      log "Warning: Failed to extract metadata from task '$task_name'"
      return 1
    fi
    # Output the metadata
    echo "$metadata"
  fi

  return 0
}

# End content from: erda-func-ext.sh


# Function to display help
show_help() {
  echo "Usage: trantor-artifact-transfer.sh [options]"
  echo
  echo "Transfer an artifact to a project application."
  echo
  echo "Options:"
  echo "  -h, --help                  Show this help message and exit"
  echo "  -s, --server URL            Installer API server (default: $SERVER_URL)"
  echo "  --smart                     Enable smart mode for interactive parameter input"
  echo "  --non-interactive           Enable non-interactive mode (skip confirmations, return pipeline info only)"
  echo "  --erda-cookie COOKIE        Erda cookie for authentication (bypasses credential management)"
  echo "  --erda-token TOKEN          Erda access token for authentication (bypasses credential management)"
  echo "  --base-url URL              Erda base URL (default: $ERDA_BASE_URL)"
  echo "  --org-name ORG_NAME         Erda organization name (default: $ORG_NAME)"
  echo "  --project-id ID             Project ID"
  echo "  --app-name APP_NAME         Application name (default: $APP_NAME)"
  echo "  --artifact-url URL          Artifact URL to transfer"
  echo "  --branch BRANCH             Git branch to use (default: $BRANCH)"
  echo "  --pipeline-yml PATH         Pipeline YAML path (default: $PIPELINE_YML_NAME)"
  echo "  --pipeline-template NAME    Pipeline template to use (default: $PIPELINE_TEMPLATE)"
  echo "  --timeout MINUTES           Timeout for pipeline (default: $TIMEOUT_MINUTES)"
  echo "  --output-format FORMAT      Output format: json, none (default: none)"
  echo "                              json: JSON-only output to stdout"
  echo "                              none: no stdout output (logs still go to stderr)"
  echo
  echo "Non-interactive mode:"
  echo "  When --non-interactive is used:"
  echo "  - All user confirmations and interactions are skipped"
  echo "  - Returns pipeline_id and build_id immediately without waiting for completion"
  echo "  - Works best with --erda-cookie or --erda-token to bypass authentication prompts"
  echo "  - Requires all necessary parameters to be provided via command line"
  echo
  echo "Examples:"
  echo "  trantor-artifact-transfer.sh --project-id 190 --app-name trantor2-app --artifact-url https://example.com/artifact.tar.gz"
  echo "  trantor-artifact-transfer.sh --non-interactive --erda-cookie 'YOUR_COOKIE' --project-id 190 --artifact-url https://example.com/artifact.tar.gz"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      show_help
      exit 0
      ;;
    -s|--server)
      SERVER_URL="$2"
      shift 2
      ;;
    --smart)
      SMART_MODE=true
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    --erda-cookie)
      ERDA_COOKIE="$2"
      shift 2
      ;;
    --erda-token)
      ERDA_TOKEN="$2"
      shift 2
      ;;
    --base-url)
      ERDA_BASE_URL="$2"
      shift 2
      ;;
    --org-name)
      ORG_NAME="$2"
      shift 2
      ;;
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --artifact-url)
      ARTIFACT_URL="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --pipeline-yml)
      PIPELINE_YML_NAME="$2"
      shift 2
      ;;
    --pipeline-template)
      PIPELINE_TEMPLATE="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_MINUTES="$2"
      shift 2
      ;;
    --output-format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    *)
      log "Error: Unknown option '$key'"
      show_help
      exit 1
      ;;
  esac
done

# Check for conflicting modes
if [ "$SMART_MODE" = true ] && [ "$NON_INTERACTIVE" = true ]; then
  log "Error: --smart and --non-interactive modes cannot be used together"
  exit 1
fi

# Skip smart mode if non-interactive mode is enabled
if [ "$NON_INTERACTIVE" = true ]; then
  SMART_MODE=false
fi

if [ "$SMART_MODE" = true ]; then
  log "Smart mode enabled. Interactive parameter input."

  # Load execution history if available
  if [ -f "$HISTORY_FILE" ]; then
    log "Found previous execution history."
    echo
    echo "Select a configuration (default: 1 - most recent):"

    # Display history entries with numbering
    HISTORY_COUNT=0
    while IFS='|' read -r h_base_url h_org_name h_project_id h_timestamp || [ -n "$h_base_url" ]; do
      if [ -n "$h_base_url" ] && [ -n "$h_org_name" ] && [ -n "$h_project_id" ]; then
        HISTORY_COUNT=$((HISTORY_COUNT + 1))
        echo "$HISTORY_COUNT) $h_base_url/$h_org_name - Project: $h_project_id (Last used: $h_timestamp)"
      fi
    done < "$HISTORY_FILE"

    # Add the "new configuration" option at the end
    echo "0) Enter new configuration"

    # Get user selection with default to 1 (most recent)
    echo
    read -p "Select option [1-$HISTORY_COUNT/0] (default: 1): " HISTORY_SELECTION

    # Set default to 1 if empty
    if [ -z "$HISTORY_SELECTION" ]; then
      HISTORY_SELECTION=1
    fi

    # Process selection
    if [[ "$HISTORY_SELECTION" =~ ^[1-9][0-9]*$ ]] && [ "$HISTORY_SELECTION" -le "$HISTORY_COUNT" ]; then
      # Extract the selected history entry
      SELECTED_ENTRY=$(sed -n "${HISTORY_SELECTION}p" "$HISTORY_FILE")
      IFS='|' read -r ERDA_BASE_URL ORG_NAME PROJECT_ID _ <<< "$SELECTED_ENTRY"

      log "Selected configuration:"
      log "  Base URL:      $ERDA_BASE_URL"
      log "  Organization:  $ORG_NAME"
      log "  Project ID:    $PROJECT_ID"
    else
      # User chose to enter new configuration or invalid selection
      # Step 1: Get project URL
      echo
      echo "Please enter an Erda project URL, for example:"
      echo "- https://erda.cloud/terminus/dop/projects/190"
      echo "- https://erda.cloud/terminus/dop/projects/190/apps/10384/pipeline/obsoleted?nodeId=..."
      echo "- https://erda.cloud/terminus/dop/projects/190/deploy/list/dev?advanceFilter..."
      echo
      read -p "Enter URL: " PROJECT_URL

      # Extract parameters from URL
      if [[ "$PROJECT_URL" =~ ^(https?://[^/]+)/([^/]+)/(dop|cmp|msp)/projects/([0-9]+) ]]; then
        ERDA_BASE_URL="${BASH_REMATCH[1]}"
        ORG_NAME="${BASH_REMATCH[2]}"
        PROJECT_ID="${BASH_REMATCH[4]}"

        log "Extracted information from URL:"
        log "  Base URL:      $ERDA_BASE_URL"
        log "  Organization:  $ORG_NAME"
        log "  Project ID:    $PROJECT_ID"
      else
        log "Error: Could not extract information from the provided URL"
        log "Please ensure the URL is in the format: {base_url}/{org_name}/{platform}/projects/{project_id}/..."
        exit 1
      fi
    fi
  else
    # No history available, get new configuration
    echo
    echo "Please enter an Erda project URL, for example:"
    echo "- https://erda.cloud/terminus/dop/projects/190"
    echo "- https://erda.cloud/terminus/dop/projects/190/apps/10384/pipeline/obsoleted?nodeId=..."
    echo "- https://erda.cloud/terminus/dop/projects/190/deploy/list/dev?advanceFilter..."
    echo
    read -p "Enter URL: " PROJECT_URL

    # Extract parameters from URL
    if [[ "$PROJECT_URL" =~ ^(https?://[^/]+)/([^/]+)/(dop|cmp|msp)/projects/([0-9]+) ]]; then
      ERDA_BASE_URL="${BASH_REMATCH[1]}"
      ORG_NAME="${BASH_REMATCH[2]}"
      PROJECT_ID="${BASH_REMATCH[4]}"

      log "Extracted information from URL:"
      log "  Base URL:      $ERDA_BASE_URL"
      log "  Organization:  $ORG_NAME"
      log "  Project ID:    $PROJECT_ID"
    else
      log "Error: Could not extract information from the provided URL"
      log "Please ensure the URL is in the format: {base_url}/{org_name}/{platform}/projects/{project_id}/..."
      exit 1
    fi
  fi

  # Step 2: Get artifact URL only if not provided via command line
  if [ -z "$ARTIFACT_URL" ]; then
    echo
    read -p "Enter artifact URL: " ARTIFACT_URL

    if [ -z "$ARTIFACT_URL" ]; then
      log "Error: Artifact URL cannot be empty"
      exit 1
    fi
  else
    log "Using provided artifact URL: $ARTIFACT_URL"
  fi
fi

# Validate required parameters
if [ -z "$PROJECT_ID" ]; then
  log "Error: Project ID is required (use --project-id)"
  exit 1
fi

if [ -z "$ARTIFACT_URL" ]; then
  log "Error: Artifact URL is required (use --artifact-url)"
  exit 1
fi

if [ -z "$APP_NAME" ]; then
  log "Error: Application name is required (use --app-name)"
  exit 1
fi

save_execution_history() {
  # Create history file if it doesn't exist
  if [ ! -f "$HISTORY_FILE" ]; then
    touch "$HISTORY_FILE"
  fi

  # Create a new history entry with timestamp
  CURRENT_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  NEW_ENTRY="$ERDA_BASE_URL|$ORG_NAME|$PROJECT_ID|$CURRENT_TIMESTAMP"

  # Check if this configuration already exists
  # Escape pipe characters in the grep pattern
  if grep -q "^$ERDA_BASE_URL\\\|$ORG_NAME\\\|$PROJECT_ID\\\|" "$HISTORY_FILE"; then
    # Update the timestamp of the existing entry
    TMP_HISTORY=$(mktemp)
    grep -v "^$ERDA_BASE_URL\|$ORG_NAME\|$PROJECT_ID\|" "$HISTORY_FILE" > "$TMP_HISTORY"
    echo "$NEW_ENTRY" >> "$TMP_HISTORY"
    mv "$TMP_HISTORY" "$HISTORY_FILE"
  else
    # Add the new entry at the beginning
    TMP_HISTORY=$(mktemp)
    echo "$NEW_ENTRY" > "$TMP_HISTORY"
    cat "$HISTORY_FILE" >> "$TMP_HISTORY"
    mv "$TMP_HISTORY" "$HISTORY_FILE"

    # Limit the number of entries
    if [ "$(wc -l < "$HISTORY_FILE")" -gt "$HISTORY_MAX" ]; then
      head -n "$HISTORY_MAX" "$HISTORY_FILE" > "$TMP_HISTORY"
      mv "$TMP_HISTORY" "$HISTORY_FILE"
    fi
  fi
}

# User confirmation step
if [ "$NON_INTERACTIVE" = false ]; then
  log "Please confirm the transfer operation with the following details:"
  log "  Project ID:    $PROJECT_ID"
  log "  Application:   $APP_NAME"
  log "  Artifact URL:  $ARTIFACT_URL"
  log "  Erda URL:      $ERDA_BASE_URL (organization: $ORG_NAME)"
  echo
  read -p "Do you want to proceed? (Y/n): " confirm
  if [[ -z "$confirm" || "$confirm" =~ ^[Yy](es)?$ ]]; then
    save_execution_history
  else
    log "Operation cancelled by user"
    exit 0
  fi
else
  # In non-interactive mode, automatically proceed and save history
  log "Non-interactive mode: proceeding with transfer operation"
  log "  Project ID:    $PROJECT_ID"
  log "  Application:   $APP_NAME"
  log "  Artifact URL:  $ARTIFACT_URL"
  log "  Erda URL:      $ERDA_BASE_URL (organization: $ORG_NAME)"
  save_execution_history
fi

# Temporary file to store credentials for this session
CREDS_FILE=$(mktemp)
trap 'rm -f "$CREDS_FILE"' EXIT

# Credential management
if [ -n "$ERDA_COOKIE" ] || [ -n "$ERDA_TOKEN" ]; then
  # Use provided cookie/token directly
  if [ -n "$ERDA_TOKEN" ]; then
    log "Using provided Erda token for authentication"
  else
    log "Using provided Erda cookie for authentication"
  fi
  
  # Create a minimal credentials file with the provided cookie/token
  cat > "$CREDS_FILE" << EOF
{
  "base_url": "$ERDA_BASE_URL",
  "org_name": "$ORG_NAME",
  "erda_cookie": "$ERDA_COOKIE",
  "erda_token": "$ERDA_TOKEN",
  "username": "provided-via-auth",
  "user_id": "unknown"
}
EOF
  
  # Extract the cookie/token for later use
  ERDA_COOKIE=$(cat "$CREDS_FILE" | parse_json_field "erda_cookie")
  ERDA_TOKEN=$(cat "$CREDS_FILE" | parse_json_field "erda_token")
else
  # Interactive credential management
  log "Accessing Erda at $ERDA_BASE_URL (organization: $ORG_NAME)"
  if ! manage_erda_credentials "$ERDA_BASE_URL" "$ORG_NAME" "$CREDS_FILE"; then
    log "Error: Failed to authenticate with Erda"
    exit 1
  fi

  # Display login information
  USERNAME_RESP=$(cat "$CREDS_FILE" | parse_json_field "username")
  USER_ID=$(cat "$CREDS_FILE" | parse_json_field "user_id")
  log "Successfully logged in as $USERNAME_RESP (ID: $USER_ID)"

  # Extract the cookie/token from credentials file
  ERDA_COOKIE=$(cat "$CREDS_FILE" | parse_json_field "erda_cookie")
  ERDA_TOKEN=$(cat "$CREDS_FILE" | parse_json_field "erda_token")
fi

# Step 1: Prepare the application by creating/updating the pipeline YAML
log "Step 1: Preparing application '$APP_NAME' with artifact transfer pipeline..."

# Use the new prepare_application function
if ! prepare_application "$CREDS_FILE" "$PROJECT_ID" "$APP_NAME" "$BRANCH" "$PIPELINE_YML_NAME" "$SERVER_URL"; then
  log "Error: Failed to prepare application"
  exit 1
fi

log "Application prepared successfully"

# Step 2: Run the pipeline to transfer the artifact
log "Step 2: Running transfer pipeline with artifact URL: $ARTIFACT_URL"

# Define pipeline parameters
pipeline_params=$(cat <<EOF
[
  {
    "name": "artifact_url",
    "value": "$ARTIFACT_URL"
  }
]
EOF
)

# Create a temporary file for the pipeline parameters
PARAMS_FILE=$(mktemp)
echo "$pipeline_params" > "$PARAMS_FILE"
trap 'rm -f "$CREDS_FILE" "$PARAMS_FILE"' EXIT

# Run the pipeline with different behavior based on interaction mode
log "Starting artifact transfer pipeline..."

if [ "$NON_INTERACTIVE" = true ]; then
  # Non-interactive mode: start pipeline and return immediately
  RESULT_JSON=$(run_pipeline "$CREDS_FILE" "$SERVER_URL" "$PROJECT_ID" "$APP_NAME" "$BRANCH" "$PIPELINE_YML_NAME" "$PARAMS_FILE" "$TIMEOUT_MINUTES" "" "false")

  if [ $? -ne 0 ] || [ -z "$RESULT_JSON" ]; then
    log "Error: Failed to start pipeline build"
    exit 1
  fi

  # Output pipeline info JSON and exit without proceeding to Step 3
  echo "$RESULT_JSON"
  exit 0

else
  # Interactive mode: run pipeline and wait for completion with metadata extraction
  METADATA_JSON=$(run_pipeline "$CREDS_FILE" "$SERVER_URL" "$PROJECT_ID" "$APP_NAME" "$BRANCH" "$PIPELINE_YML_NAME" "$PARAMS_FILE" "$TIMEOUT_MINUTES" "rebuild-artifact" "true")

  # Check if metadata extraction was successful
  if [ -z "$METADATA_JSON" ]; then
    log "Error: Failed to extract metadata from rebuild-artifact task"
    exit 1
  fi

  # Extract metadata fields from the JSON response
  TEMP_URL=$(echo "$METADATA_JSON" | parse_json_field "temp_url")

  # Check if required fields are present
  if [ -z "$TEMP_URL" ]; then
    log "Warning: No temp_url found in metadata"
  fi
fi

# Step 3: Download the artifact from temp storage and upload to Erda release
log "Step 3: Uploading artifact to Erda release..."

# Create a temporary directory for the downloaded artifact
TEMP_ARTIFACT_DIR=$(mktemp -d)
TEMP_ARTIFACT_PATH="$TEMP_ARTIFACT_DIR/artifact.zip"
trap 'rm -rf "$CREDS_FILE" "$TEMP_ARTIFACT_DIR"' EXIT

# Download the artifact from temp storage
if ! curl -s -f -L "$TEMP_URL" -o "$TEMP_ARTIFACT_PATH"; then
  log "Error: Failed to download artifact from temp storage"
  exit 1
fi

# Get org ID
ORG_INFO_RESPONSE=$(mktemp)
if ! erda_api_curl --creds "$CREDS_FILE" -s -f -X GET \
  "{base_url}/api/{org_name}/orgs" -o "$ORG_INFO_RESPONSE"; then
  log "Error: Failed to get organization information"
  rm -f "$ORG_INFO_RESPONSE"
  exit 1
fi

ORG_ID=$(cat "$ORG_INFO_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
orgs = data.get('data', []).get('list', [])
for org in orgs:
    if org.get('name') == '$ORG_NAME':
        print(org.get('id', ''))
        break
")

if [ -z "$ORG_ID" ]; then
  log "Error: Could not get organization ID"
  rm -f "$ORG_INFO_RESPONSE"
  exit 1
fi

rm -f "$ORG_INFO_RESPONSE"

# Use the new upload_release function and capture the result
UPLOAD_RESULT=""
if ! UPLOAD_RESULT=$(upload_release "$CREDS_FILE" "$ORG_ID" "$PROJECT_ID" "$TEMP_ARTIFACT_PATH"); then
  log "Error: Failed to upload release"
  exit 1
fi

# Extract release information from the result
if [ "$NON_INTERACTIVE" = false ]; then
  RELEASE_ID=$(echo "$UPLOAD_RESULT" | parse_json_field "release_id")
  RELEASE_VERSION=$(echo "$UPLOAD_RESULT" | parse_json_field "release_version")
  RELEASE_URL=$(echo "$UPLOAD_RESULT" | parse_json_field "release_url")

  # Display all extracted information
  log "✅ Successfully transferred artifact to application $APP_NAME"
  log "Results:"
  [ -n "$RELEASE_ID" ] && log "  - Release ID:      $RELEASE_ID"
  [ -n "$RELEASE_VERSION" ] && log "  - Release Version: $RELEASE_VERSION"
  [ -n "$RELEASE_URL" ] && log "  - Release URL:     $RELEASE_URL"

  # Create result JSON for interactive mode with upload results
  RESULT_JSON=$(cat <<EOF
{
  "release_id": "$RELEASE_ID",
  "release_version": "$RELEASE_VERSION",
  "release_url": "$RELEASE_URL"
}
EOF
)

  # Output JSON result for interactive mode with upload results
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "$RESULT_JSON"
  fi
fi

# For non-interactive mode, always output the upload result
if [ "$NON_INTERACTIVE" = true ]; then
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "$UPLOAD_RESULT"
  fi
fi

exit 0
