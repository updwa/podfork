# Check if string is valid IPv4
is_ipv4() {
    local ip="$1"
    local regex="^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$"
    [[ "$ip" =~ $regex ]]
}

# Check if string is valid IPv4 with CIDR mask
is_ipv4_cidr() {
    local ip="$1"
    local regex="^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}(\/(3[0-2]|2[0-9]|1[0-9]|[0-9]))$"
    [[ "$ip" =~ $regex ]]
}

is_ipv4_ip_or_ipv4_cidr() {
    is_ipv4 "$1" || is_ipv4_cidr "$1"
}

is_domain() {
    local str="$1"
    local regex='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$'

    [[ "$str" =~ $regex ]]
}

is_domain_suffix() {
    local str="$1"
    local normalized="${str#.}"

    is_domain "$normalized"
}

# Checks if the given string is a valid base64-encoded sequence
is_base64() {
    local str="$1"

    if echo "$str" | base64 -d > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Checks if the given string looks like a Shadowsocks userinfo
is_shadowsocks_userinfo_format() {
    local str="$1"
    local regex='^[^:]+:[^:]+(:[^:]+)?$'

    [[ "$str" =~ $regex ]]
}

# Compares the current package version with the required minimum
is_min_package_version() {
    local current="$1"
    local required="$2"

    local lowest
    lowest="$(printf '%s\n' "$current" "$required" | sort -V | head -n1)"

    [ "$lowest" = "$required" ]
}

# Checks if the given file exists
file_exists() {
    local filepath="$1"

    if [[ -f "$filepath" ]]; then
        return 0
    else
        return 1
    fi
}

# Checks if a service script exists in /etc/init.d
service_exists() {
    local service="$1"

    if [ -x "/etc/init.d/$service" ]; then
        return 0
    else
        return 1
    fi
}

# Returns the inbound tag name by appending the postfix to the given section
get_inbound_tag_by_section() {
    local section="$1"
    local postfix="in"

    echo "$section-$postfix"
}

# Returns the outbound tag name by appending the postfix to the given section
get_outbound_tag_by_section() {
    local section="$1"
    local postfix="out"

    echo "$section-$postfix"
}

# Constructs and returns a domain resolver tag by appending a fixed postfix to the given section
get_domain_resolver_tag() {
    local section="$1"
    local postfix="domain-resolver"

    echo "$section-$postfix"
}

# Converts a comma-separated string into a JSON array string
comma_string_to_json_array() {
    local input="$1"

    if [ -z "$input" ]; then
        echo "[]"
        return
    fi

    local replaced="${input//,/\",\"}"

    echo "[\"$replaced\"]"
}

# Decodes a URL-encoded string
url_decode() {
    local encoded="$1"
    printf '%b' "$(echo "$encoded" | sed 's/+/ /g; s/%/\\x/g')"
}

# Prints the features the installed sing-box reports in the "Features:" line of
# "sing-box version", comma-separated; nothing for a sing-box without that line
sing_box_get_features() {
    sing-box version 2> /dev/null | sed -n 's/^Features:[[:space:]]*//p'
}

# Checks if the installed sing-box reports the given feature
sing_box_has_feature() {
    local feature="$1"

    case ",$(sing_box_get_features)," in
    *",$feature,"*) return 0 ;;
    esac

    return 1
}

# Returns the scheme (protocol) part of a URL
url_get_scheme() {
    local url="$1"
    echo "${url%%://*}"
}

# Extracts the userinfo (username[:password]) part from a URL
url_get_userinfo() {
    local url="$1"
    echo "$url" | sed -n -e 's#^[^:/?]*://##' -e '/@/!d' -e 's/@.*//p'
}

# Extracts the host part from a URL
url_get_host() {
    local url="$1"

    url="${url#*://}"
    url="${url#*@}"
    url="${url%%[/?#]*}"

    echo "${url%%:*}"
}

# Extracts the port number from a URL
url_get_port() {
    local url="$1"

    url="${url#*://}"
    url="${url#*@}"
    url="${url%%[/?#]*}"

    [[ "$url" == *:* ]] && echo "${url#*:}" || echo ""
}

# Extracts the path from a URL (without query or fragment; returns "/" if empty)
url_get_path() {
    local url="$1"
    echo "$url" | sed -n -e 's#^[^:/?]*://##' -e 's#^[^/]*##' -e 's#\([^?]*\).*#\1#p'
}

# Extracts the value of a specific query parameter from a URL
url_get_query_param() {
    local url="$1"
    local param="$2"

    local raw
    raw=$(echo "$url" | sed -n "s/.*[?&]$param=\([^&?#]*\).*/\1/p")

    [ -z "$raw" ] && echo "" && return

    echo "$raw"
}

# Extracts the basename (filename without extension) from a URL
url_get_basename() {
    local url="$1"

    local filename="${url##*/}"
    local basename="${filename%%.*}"

    echo "$basename"
}

# Extracts and returns the file extension from the given URL
url_get_file_extension() {
    local url="$1"

    local basename="${url##*/}"
    case "$basename" in
    *.*) echo "${basename##*.}" ;;
    *) echo "" ;;
    esac
}

# Remove url fragment (everything after the first '#')
url_strip_fragment() {
    local url="$1"

    echo "${url%%#*}"
}

# Decodes and returns a base64-encoded string
base64_decode() {
    local str="$1"
    local decoded_url

    decoded_url="$(echo "$str" | base64 -d 2> /dev/null)"

    echo "$decoded_url"
}

# Generates a unique 16-character ID based on the current timestamp and a random number
gen_id() {
    printf '%s%s' "$(date +%s)" "$RANDOM" | md5sum | cut -c1-16
}

# Adds a missing UCI option with the given value if it does not exist
migration_add_new_option() {
    local package="$1"
    local section="$2"
    local option="$3"
    local value="$4"

    local current
    current="$(uci -q get "$package.$section.$option")"
    if [ -z "$current" ]; then
        log "Adding missing option '$option' with value '$value'"
        uci set "$package.$section.$option=$value"
        uci commit "$package"
        return 0
    else
        return 1
    fi
}

# Migrates a configuration key in an OpenWrt config file from old_key_name to new_key_name
migration_rename_config_key() {
    local config="$1"
    local key_type="$2"
    local old_key_name="$3"
    local new_key_name="$4"

    if grep -q "$key_type $old_key_name" "$config"; then
        log "Deprecated $key_type found: $old_key_name migrating to $new_key_name"
        sed -i "s/$key_type $old_key_name/$key_type $new_key_name/g" "$config"
    fi
}

# Download URL to file
download_to_file() {
    local url="$1"
    local filepath="$2"
    local http_proxy_address="$3"
    local retries="${4:-3}"
    local wait="${5:-2}"

    for attempt in $(seq 1 "$retries"); do
        if [ -n "$http_proxy_address" ]; then
            http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" wget -O "$filepath" "$url" && break
        else
            wget -O "$filepath" "$url" && break
        fi

        log "Attempt $attempt/$retries to download $url failed" "warn"
        sleep "$wait"
    done
}

# Converts Windows-style line endings (CRLF) to Unix-style (LF)
convert_crlf_to_lf() {
    local filepath="$1"

    if grep -q $'\r' "$filepath"; then
        log "File '$filepath' contains CRLF line endings. Converting to LF..." "debug"
        local tmpfile
        tmpfile=$(mktemp)
        tr -d '\r' < "$filepath" > "$tmpfile" && mv "$tmpfile" "$filepath" || rm -f "$tmpfile"
    fi
}

#######################################
# Parses a whitespace-separated string, validates items as either domains
# or IPv4 addresses/subnets, and returns a comma-separated string of valid items.
# Arguments:
#   $1 - Input string (space-separated list of items)
#   $2 - Type of validation ("domains" or "subnets")
# Outputs:
#   Comma-separated string of valid domains or subnets
#######################################
parse_domain_or_subnet_string_to_commas_string() {
    local string="$1"
    local type="$2"

    tmpfile=$(mktemp)
    printf "%s\n" "$string" | sed 's/\/\/.*//' | tr ', ' '\n' | grep -v '^$' > "$tmpfile"

    result="$(parse_domain_or_subnet_file_to_comma_string "$tmpfile" "$type")"
    rm -f "$tmpfile"

    echo "$result"
}

# Prints the build tags of the sing-box core, comma separated.
get_sing_box_tags() {
    if [ -n "${NETSHIFT_SING_BOX_TAGS+x}" ]; then
        echo "$NETSHIFT_SING_BOX_TAGS"
        return 0
    fi

    if command -v sing-box > /dev/null 2>&1; then
        sing-box version 2> /dev/null | sed -n 's/^Tags:[[:space:]]*//p' | sed -n '1p'
    fi
}

# Returns 0 when the core has the build tag.
core_has_tag() {
    local tags

    tags="$(get_sing_box_tags)"
    [ -n "$tags" ] || return 0

    core_has_tag_strict "$1"
}

# Returns 0 only when the core says it has the tag.
core_has_tag_strict() {
    get_sing_box_tags | tr ',' '\n' | grep -qx "$1"
}

# Returns 0 if the given (or detected) sing-box version is an "extended" build.
is_sing_box_extended() {
    local version="${1:-}"

    [ -n "$version" ] || version="$(get_sing_box_version)"

    case "$version" in
    *extended*) return 0 ;;
    esac

    return 1
}

# Returns 0 if the given (or detected) sing-box version is an "extended" build
# at or above the given extended release.
is_sing_box_extended_at_least() {
    local required="$1"
    local version="${2:-}"
    local release

    [ -n "$version" ] || version="$(get_sing_box_version)"

    is_sing_box_extended "$version" || return 1
    release="${version##*-extended-}"
    is_min_package_version "${release%%-*}" "$required"
}

# Soft memory ceiling (GOMEMLIMIT) for short-lived sing-box runs.
sing_box_oneshot_memlimit() {
    local mem_kb limit_mb

    mem_kb="$(awk '$1 == "MemTotal:" { print $2; exit }' /proc/meminfo 2> /dev/null)"
    case "$mem_kb" in
    '' | *[!0-9]*) return 0 ;;
    esac

    limit_mb=$((mem_kb / 8192))
    [ "$limit_mb" -lt 16 ] && limit_mb=16
    [ "$limit_mb" -gt 128 ] && limit_mb=128
    printf '%sMiB' "$limit_mb"
}

# Sets NETSHIFT_ONESHOT_GOMEMLIMIT to the ceiling above, once per shell.
sing_box_oneshot_memlimit_init() {
    [ -n "${NETSHIFT_ONESHOT_GOMEMLIMIT+x}" ] && return 0
    NETSHIFT_ONESHOT_GOMEMLIMIT="${GOMEMLIMIT:-$(sing_box_oneshot_memlimit)}"
}

# Runs a short-lived sing-box command under the ceiling above.
sing_box_oneshot() {
    sing_box_oneshot_memlimit_init
    GOMEMLIMIT="$NETSHIFT_ONESHOT_GOMEMLIMIT" sing-box "$@"
}

###############################################################################
# Subscription download, validation and normalization (ported from netshift)
###############################################################################

# Download URL to file with subscription client-mimicking headers.
download_subscription() {
    local url="${1%%#*}"
    local filepath="$2"
    local http_proxy_address="$3"
    local retries="${4:-3}"
    local wait="${5:-2}"
    local timeout="${6:-10}"
    local user_agent="${7:-}"
    local insecure="${8:-0}"

    local device_os device_model kernel_version hwid
    device_os="${SUBSCRIPTION_DEVICE_OS:-OpenWrt Linux}"
    device_model="${SUBSCRIPTION_DEVICE_MODEL:-$(get_device_model)}"
    kernel_version="${SUBSCRIPTION_OS_VERSION:-$(get_kernel_version)}"
    hwid="${SUBSCRIPTION_HWID:-$(generate_hwid)}"
    [ -n "$user_agent" ] || user_agent="$(get_subscription_user_agent)"

    local cert_flag=""
    if [ "$insecure" = "1" ]; then
        cert_flag="--no-check-certificate"
    fi

    local tmpfile errfile rc family
    tmpfile="${filepath}.part.$$"
    errfile="${filepath}.err.$$"
    rm -f "$tmpfile" "$errfile"

    for attempt in $(seq 1 "$retries"); do
        family="any"
        if should_force_wget_ipv4 "$url"; then
            family="ipv4"
            if [ -n "$http_proxy_address" ]; then
                http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" \
                    _wget_subscription_request "$cert_flag" "$user_agent" "$hwid" "$device_os" \
                        "$device_model" "$kernel_version" "$tmpfile" "$errfile" "$url" \
                        -4 -T "$timeout"
            else
                _wget_subscription_request "$cert_flag" "$user_agent" "$hwid" "$device_os" \
                    "$device_model" "$kernel_version" "$tmpfile" "$errfile" "$url" \
                    -4 -T "$timeout"
            fi
        else
            if [ -n "$http_proxy_address" ]; then
                http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" \
                    _wget_subscription_request "$cert_flag" "$user_agent" "$hwid" "$device_os" \
                        "$device_model" "$kernel_version" "$tmpfile" "$errfile" "$url" \
                        -T "$timeout"
            else
                _wget_subscription_request "$cert_flag" "$user_agent" "$hwid" "$device_os" \
                    "$device_model" "$kernel_version" "$tmpfile" "$errfile" "$url" \
                    -T "$timeout"
            fi
        fi

        rc=$?
        if [ "$rc" -eq 0 ] && [ -s "$tmpfile" ]; then
            if ! mv "$tmpfile" "$filepath"; then
                log "Subscription download succeeded but failed to move temporary file to destination" "error"
                rm -f "$tmpfile" "$errfile"
                return 1
            fi
            rm -f "$errfile"
            return 0
        fi

        if [ "$rc" -eq 0 ] && [ ! -s "$tmpfile" ]; then
            log "Subscription download returned success but produced an empty file: host=$(url_host_for_log "$url"), url=$(redact_url_for_log "$url")" "warn"
        fi

        rm -f "$tmpfile"
        log_wget_failure "Subscription download" "$url" "$errfile" "$rc" "$attempt" "$retries" "$timeout" "$http_proxy_address" "$family"

        if [ "$family" != "ipv4" ] && has_ipv4_default_route && wget_supports_ipv4_flag; then
            family="ipv4"
            log "Retrying subscription download over IPv4-only" "warn"
            if [ -n "$http_proxy_address" ]; then
                http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" \
                    _wget_subscription_request "$cert_flag" "$user_agent" "$hwid" "$device_os" \
                        "$device_model" "$kernel_version" "$tmpfile" "$errfile" "$url" \
                        -4 -T "$timeout"
            else
                _wget_subscription_request "$cert_flag" "$user_agent" "$hwid" "$device_os" \
                    "$device_model" "$kernel_version" "$tmpfile" "$errfile" "$url" \
                    -4 -T "$timeout"
            fi
            rc=$?
            if [ "$rc" -eq 0 ] && [ -s "$tmpfile" ]; then
                if ! mv "$tmpfile" "$filepath"; then
                    log "Subscription download IPv4 retry succeeded but failed to move temporary file to destination" "error"
                    rm -f "$tmpfile" "$errfile"
                    return 1
                fi
                rm -f "$errfile"
                return 0
            fi
            if [ "$rc" -eq 0 ] && [ ! -s "$tmpfile" ]; then
                log "Subscription download IPv4 retry returned success but produced an empty file: host=$(url_host_for_log "$url"), url=$(redact_url_for_log "$url")" "warn"
            fi
            log_wget_failure "Subscription download IPv4 retry" "$url" "$errfile" "$rc" "$attempt" "$retries" "$timeout" "$http_proxy_address" "$family"
        fi

        sleep "$wait"
    done

    rm -f "$tmpfile"
    rm -f "$errfile"
    log "Subscription download failed after $retries attempts: host=$(url_host_for_log "$url"), url=$(redact_url_for_log "$url")" "error"
    return 1
}

check_subscription_connectivity() {
    local url="${1%%#*}"
    local http_proxy_address="$2"
    local retries="${3:-3}"
    local wait="${4:-2}"
    local timeout="${5:-5}"

    local user_agents device_os device_model kernel_version hwid
    device_os="${SUBSCRIPTION_DEVICE_OS:-OpenWrt Linux}"
    device_model="${SUBSCRIPTION_DEVICE_MODEL:-$(get_device_model)}"
    kernel_version="${SUBSCRIPTION_OS_VERSION:-$(get_kernel_version)}"
    hwid="${SUBSCRIPTION_HWID:-$(generate_hwid)}"
    if [ -z "$SUBSCRIPTION_USER_AGENT" ] &&
        [ -n "$SUBSCRIPTION_HWID$SUBSCRIPTION_DEVICE_OS$SUBSCRIPTION_OS_VERSION$SUBSCRIPTION_DEVICE_MODEL" ]; then
        user_agents="$(build_subscription_user_agent_candidates "" "" "")"
    else
        user_agents="$(get_subscription_user_agent "$SUBSCRIPTION_USER_AGENT")"
    fi

    local attempt errfile user_agent
    errfile="/tmp/podkop-subscription-check.$$"
    rm -f "$errfile"
    for attempt in $(seq 1 "$retries"); do
        while IFS= read -r user_agent; do
            [ -n "$user_agent" ] || continue
            if _check_subscription_connectivity_once "$url" "$http_proxy_address" "$timeout" "$errfile" \
                "$attempt" "$retries" "$user_agent" "$hwid" "$device_os" "$device_model" "$kernel_version"; then
                rm -f "$errfile"
                return 0
            fi
        done << EOF
$user_agents
EOF

        [ "$attempt" -lt "$retries" ] && sleep "$wait"
    done

    rm -f "$errfile"
    return 1
}

# One connectivity request with one User-Agent, retried over IPv4 when that may help.
_check_subscription_connectivity_once() {
    local url="$1" http_proxy_address="$2" timeout="$3" errfile="$4" attempt="$5" retries="$6"
    local user_agent="$7" hwid="$8" device_os="$9" device_model="${10}" kernel_version="${11}"
    local family="any" rc

    set -- -q -T "$timeout"
    if should_force_wget_ipv4 "$url"; then
        family="ipv4"
        set -- "$@" -4
    fi
    if [ -n "$http_proxy_address" ]; then
        http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" \
            _wget_subscription_request "" "$user_agent" "$hwid" "$device_os" "$device_model" "$kernel_version" \
                /dev/null "$errfile" "$url" "$@"
    else
        _wget_subscription_request "" "$user_agent" "$hwid" "$device_os" "$device_model" "$kernel_version" \
            /dev/null "$errfile" "$url" "$@"
    fi
    rc=$?
    [ "$rc" -eq 0 ] && return 0

    log_wget_failure "Subscription connectivity" "$url" "$errfile" "$rc" "$attempt" "$retries" "$timeout" "$http_proxy_address" "$family"

    [ "$family" != "ipv4" ] && has_ipv4_default_route && wget_supports_ipv4_flag || return 1
    family="ipv4"
    if [ -n "$http_proxy_address" ]; then
        http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" \
            _wget_subscription_request "" "$user_agent" "$hwid" "$device_os" "$device_model" "$kernel_version" \
                /dev/null "$errfile" "$url" -q -4 -T "$timeout"
    else
        _wget_subscription_request "" "$user_agent" "$hwid" "$device_os" "$device_model" "$kernel_version" \
            /dev/null "$errfile" "$url" -q -4 -T "$timeout"
    fi
    rc=$?
    [ "$rc" -eq 0 ] && return 0

    log_wget_failure "Subscription connectivity IPv4 retry" "$url" "$errfile" "$rc" "$attempt" "$retries" "$timeout" "$http_proxy_address" "$family"
    return 1
}

# Runs a single wget subscription request with the shared client-mimicking headers.
_wget_subscription_request() {
    local cert_flag="$1"
    local req_user_agent="$2"
    local req_hwid="$3"
    local req_device_os="$4"
    local req_device_model="$5"
    local req_kernel_version="$6"
    local output_file="$7"
    local err_file="$8"
    local url="$9"
    shift 8

    local errfile="$err_file"
    local attempt rc family

    family="any"
    if should_force_wget_ipv4 "$url"; then
        family="ipv4"
        if [ -n "$http_proxy" ]; then
            http_proxy="http://$http_proxy" https_proxy="http://$http_proxy" wget -4 -q -T 10 -O "$output_file" "$url" 2>"$errfile"
        else
            wget -4 -q -T 10 -O "$output_file" "$url" 2>"$errfile"
        fi
    elif [ -n "$http_proxy" ]; then
        http_proxy="http://$http_proxy" https_proxy="http://$http_proxy" wget -q -T 10 -O "$output_file" "$url" 2>"$errfile"
    else
        wget -q -T 10 -O "$output_file" "$url" 2>"$errfile"
    fi
    rc=$?
    [ "$rc" -eq 0 ] && return 0

    # Retry with IPv4 if generic failure and IPv4 route exists
    if [ "$family" != "ipv4" ] && has_ipv4_default_route && wget_supports_ipv4_flag; then
        if [ -n "$http_proxy" ]; then
            http_proxy="http://$http_proxy" https_proxy="http://$http_proxy" wget -4 -q -T 10 -O "$output_file" "$url" 2>"$errfile"
        else
            wget -4 -q -T 10 -O "$output_file" "$url" 2>"$errfile"
        fi
        rc=$?
        [ "$rc" -eq 0 ] && return 0
    fi

    return 1
}

validate_subscription_file() {
    local filepath="$1"

    [ -s "$filepath" ] || return 1

    jq -e '
        type == "object" and
        (.outbounds | type == "array") and
        ([.outbounds[] | select(
            .type != "selector" and
            .type != "urltest" and
            .type != "direct" and
            .type != "dns" and
            .type != "block"
        )] | length > 0)
    ' "$filepath" > /dev/null 2>&1
}

describe_subscription_validation_failure() {
    local filepath="$1"
    local total usable

    if [ ! -s "$filepath" ]; then
        echo "downloaded file is empty"
        return 0
    fi

    if ! jq -e '.' "$filepath" >/dev/null 2>&1; then
        echo "downloaded file is not valid JSON"
        return 0
    fi

    if ! jq -e 'type == "object"' "$filepath" >/dev/null 2>&1; then
        echo "subscription root is not a JSON object"
        return 0
    fi

    if ! jq -e '.outbounds | type == "array"' "$filepath" >/dev/null 2>&1; then
        echo "subscription has no outbounds array"
        return 0
    fi

    total="$(jq -r '.outbounds | length' "$filepath" 2>/dev/null)"
    usable="$(jq -r '[.outbounds[] | select(
        .type != "selector" and
        .type != "urltest" and
        .type != "direct" and
        .type != "dns" and
        .type != "block"
    )] | length' "$filepath" 2>/dev/null)"
    echo "subscription contains no usable proxy outbounds: total=${total:-unknown}, usable=${usable:-unknown}"
}

# Convert an "Xray JSON" subscription body into a newline-separated list of
# proxy share URIs (one per line) that the fallback parser's URI loop can
# consume.
xray_json_to_uri_lines() {
    local src_file="$1"

    [ -s "$src_file" ] || return 1

    jq -er '
        (if type == "array" then . else [.] end) as $configs
        | def safe($v):
            if $v == null then ""
            else
              ($v | tostring) as $s
              | if ($s == "") then ""
                elif ($s | (index("&") // index("?") // index("#")
                            // index(" ") // index("%")
                            // index("\t") // index("\n"))) != null then ""
                else $s end
            end;
        | def kv($k; $v):
            safe($v) as $s
            | if $s == "" then empty else ($k + "=" + $s) end;
        | def tag_num:
            if . == "proxy" then 1
            elif startswith("proxy-")
                 and (ltrimstr("proxy-") | explode
                      | length > 0 and length <= 6 and all(. >= 48 and . <= 57))
            then ltrimstr("proxy-") | tonumber
            else null end;
        | [ $configs[]
          | ((.remarks // "") | tostring
             | if explode | all(. <= 32) then "" else . end) as $cfg_name
          | [ (.outbounds // [])[]
            | select(type == "object")
            | select(.protocol == "vless" or .protocol == "trojan"
                     or .protocol == "shadowsocks"
                     or .protocol == "hysteria")
            | select((.streamSettings.sockopt.dialerProxy // "") == "")
            | select(.protocol != "hysteria"
                     or ((.streamSettings.hysteriaSettings.version // 0) == 2))
            ] as $usable
          | ($usable | length) as $n_usable
          | ((.routing.balancers? // []) as $b
             | $n_usable + (if ($b | type) == "array" and ($b | length) > 0
                           then 1 else 0 end)) as $prio
          | [ $usable[] | (.tag // "" | tostring)
            | select(. == "" or tag_num != null) | tag_num ] as $gnums
          | (($gnums | all(. != null))
             and ($gnums | unique | length) == ($gnums | length)) as $by_tag
          | range(0; $n_usable) as $ob_idx
          | $usable[$ob_idx]
          | . as $ob
          | (.streamSettings // {}) as $ss
          | ($ss.network // "tcp") as $net_raw
          | (if $net_raw == "splithttp" then "xhttp" else $net_raw end) as $net
          | ($ss.xhttpSettings // $ss.splithttpSettings // {}) as $xs
          | ($ss.security // "") as $sec
          | ($ss.realitySettings // {}) as $reality
          | ($ss.tlsSettings // $ss.realitySettings // {}) as $tls
          | (if $ob.protocol == "hysteria"
             then {address: $ob.settings.address, port: $ob.settings.port}
             else ($ob.settings.vnext[0] // $ob.settings.servers[0] // {}) end) as $peer
          | ($peer.users[0] // {}) as $user
          | ($peer.address // "") as $host
          | ($peer.port // "") as $port
          | select($host != "" and ($port | tostring) != "")
          | ($ob.tag // "" | tostring) as $tag
          | ($tag == "" or ($tag | tag_num) != null) as $generic
          | ($generic and $cfg_name != "" and $n_usable > 1) as $numbered
          | (if ($generic | not) or $cfg_name == "" then $tag
             elif ($numbered | not) then $cfg_name
             else $cfg_name + " · "
                  + ((if $by_tag then $tag | tag_num else $ob_idx + 1 end)
                     | tostring) end) as $name
          | (if $numbered then $cfg_name else $name end) as $name_base
          | (
              if $ob.protocol == "vless" then
                ([ ("encryption="
                    + (($user.encryption // "") | tostring
                       | if . == "" then "none" else @uri end)),
                   ("type=" + $net),
                   kv("flow"; $user.flow),
                   (if $sec != "" then ("security=" + $sec) else empty end),
                   kv("sni"; ($tls.serverName // "")) ])
                + (if $sec == "reality" then
                     [ kv("pbk"; $reality.publicKey),
                       kv("sid"; $reality.shortId),
                       kv("fp"; ($reality.fingerprint // "chrome")) ]
                   else
                     [ kv("fp"; ($tls.fingerprint // "")) ]
                   end)
              elif $ob.protocol == "trojan" then
                [ ("type=" + $net),
                  (if $sec != "" then ("security=" + ($sec)) else "security=tls" end),
                  kv("sni"; ($tls.serverName // "")),
                  kv("fp"; ($tls.fingerprint // "")) ]
              elif $ob.protocol == "hysteria" then
                ($ss.hysteriaSettings // {}) as $hy
                | [ kv("sni"; ($tls.serverName // "")),
                    (if (($tls.allowInsecure // $tls.insecure // false) == true)
                     then "insecure=1" else empty end) ]
                  + (if ($hy.obfs // "") != "" then
                        [ "obfs=salamander",
                          kv("obfs-password"; ($hy.obfsPassword // $hy.obfs_password // "")) ]
                      else [] end)
              else
                [ ("type=" + $net) ]
              end
            ) as $base
          | (
              if $net == "ws" then
                [ kv("path"; ($ss.wsSettings.path // "")),
                  kv("host"; ($ss.wsSettings.headers.Host // "")) ]
              elif $net == "xhttp" then
                [ kv("path"; ($xs.path // "")),
                  kv("host"; ($xs.host // "")),
                  kv("mode"; ($xs.mode // "")),
                  (if ($xs.extra | type) == "object" and ($xs.extra | length) > 0
                   then ("extra=" + ($xs.extra | tojson | @uri)) else empty end) ]
              elif $net == "grpc" then
                [ kv("serviceName"; ($ss.grpcSettings.serviceName // "")) ]
              else [] end
            ) as $transport
          | ([ ($tls.alpn // [])[] | tostring ] | join(",")) as $alpn_str
          | ($base + $transport
             + (if $alpn_str != "" then [ kv("alpn"; $alpn_str) ] else [] end)
             | map(select(. != null and . != ""))) as $query
          | (if $ob.protocol == "vless" then ($user.id // "")
             elif $ob.protocol == "hysteria" then
               ($ss.hysteriaSettings.auth // "")
             else ($peer.password // $ob.settings.password // "") end) as $cred
          | select($cred != "")
          | ($ob.protocol
             | if . == "shadowsocks" then "ss"
               elif . == "hysteria" then "hysteria2"
               else . end) as $scheme
          | ($scheme + "://" + $cred + "@" + $host + ":" + ($port | tostring)
             + (if ($query | length) > 0 then "?" + ($query | join("&")) else "" end)
            ) as $conn
          | { conn: $conn, prio: $prio, name: $name, base: $name_base }
        ]
        | reduce .[] as $e ({ idx: {}, out: [] };
            .idx[$e.conn] as $i
            | if $i == null then
                .idx[$e.conn] = (.out | length) | .out += [$e]
              elif $e.prio < .out[$i].prio then .out[$i] = $e
              else . end)
        | reduce .out[] as $e ({ used: {}, next: {}, out: [] };
            if $e.name == "" then .out += [$e.conn]
            else
              . as $st
              | (if $st.used[$e.name] | not then {n: $e.name}
                 else
                   first(range($st.next[$e.base] // 2; infinite) as $k
                         | {n: ($e.base + " · " + ($k | tostring)), k: $k}
                         | select($st.used[.n] | not))
                 end) as $pick
              | ($pick.n) as $n
              | (if $pick.k then .next[$e.base] = $pick.k + 1 else . end)
              | .used[$n] = true
              | .out += [$e.conn + "#" + ($n | @uri)]
            end)
        | .out
        | select(length > 0)
        | .[]
    ' "$src_file" 2>/dev/null
}

# Count the Xray-JSON proxy outbounds that look like real nodes but use a
# protocol the Podkop facade cannot build (vmess). Prints a single integer.
xray_json_count_unsupported() {
    local src_file="$1"

    [ -s "$src_file" ] || {
        echo 0
        return 0
    }

    jq -er '
        [ (if type == "array" then . else [.] end)[]
          | (.outbounds // [])[]
          | select(type == "object")
          | select((.streamSettings.sockopt.dialerProxy // "") == "")
          | select(.protocol == "vmess")
        ] | length
    ' "$src_file" 2>/dev/null || echo 0
}

# Fallback subscription parser: decodes base64/plaintext URI lists or Xray JSON
# into a minimal sing-box configuration.
normalize_subscription_to_singbox() {
    local src_file="$1"
    local out_file="$2"
    local section="$3"

    local pad_len bom work_dir body_file candidate_file
    local udp_over_tcp config new_config
    local line idx kept skipped final_count builder_tag builder_out_tag
    local fragment display_name first_char xray_uris xray_unsupported
    local NETSHIFT_REALITY_MLKEM=0
    local NETSHIFT_REALITY_MLKEM_HINT_UNGATED=1

    [ -s "$src_file" ] || return 1

    work_dir="$(mktemp -d 2> /dev/null)" || {
        log "Cannot create a working directory in /tmp to parse the subscription of '$section'" "error"
        return 1
    }
    body_file="$src_file"

    bom="$(printf '\357\273\277')"
    if [ "$(head -c 3 "$src_file" 2> /dev/null)" = "$bom" ]; then
        tail -c +4 "$src_file" > "$work_dir/body" 2> /dev/null && [ -s "$work_dir/body" ] && body_file="$work_dir/body"
    fi

    first_char="$(head -c 4096 "$body_file" 2> /dev/null | sed -n '1{s/^[[:space:]]*//;s/\(.\).*/\1/p;};1q' 2> /dev/null)"
    case "$first_char" in
    '{' | '[')
        xray_uris="$(xray_json_to_uri_lines "$body_file" 2> /dev/null)"
        if [ -n "$xray_uris" ]; then
            log "Detected Xray JSON subscription for '$section'; converting proxy outbounds to share URIs" "debug"
            printf '%s\n' "$xray_uris" > "$work_dir/xray"
            unset xray_uris
            body_file="$work_dir/xray"
            xray_unsupported="$(xray_json_count_unsupported "$src_file")"
            case "$xray_unsupported" in
            '' | *[!0-9]*) xray_unsupported=0 ;;
            esac
            if [ "$xray_unsupported" -gt 0 ]; then
                log "Xray JSON subscription for '$section' has $xray_unsupported VMess node(s); VMess is not supported and they were skipped" "warn"
            fi
        fi
        ;;
    esac

    candidate_file="$body_file"
    if ! grep -q -F -- '://' "$body_file" 2> /dev/null; then
        tr -d ' \t\r\n' < "$body_file" > "$work_dir/stripped" 2> /dev/null
        if [ -s "$work_dir/stripped" ] &&
            [ -z "$(tr -d 'A-Za-z0-9+/=' < "$work_dir/stripped" 2> /dev/null | head -c 1)" ]; then
            pad_len=$(( $(wc -c < "$work_dir/stripped" | tr -d ' ') % 4 ))
            if [ "$pad_len" -eq 2 ]; then
                printf '==' >> "$work_dir/stripped"
            elif [ "$pad_len" -eq 3 ]; then
                printf '=' >> "$work_dir/stripped"
            fi
            if base64 -d < "$work_dir/stripped" > "$work_dir/decoded" 2> /dev/null &&
                grep -q -F -- '://' "$work_dir/decoded" 2> /dev/null; then
                candidate_file="$work_dir/decoded"
            fi
        fi
        rm -f "$work_dir/stripped"
    fi

    udp_over_tcp="$(uci -q get "podkop.${section}.enable_udp_over_tcp" 2>/dev/null)"

    local max_nodes
    max_nodes="$(uci -q get "podkop.${section}.subscription_max_nodes" 2>/dev/null)"
    case "$max_nodes" in
    '') max_nodes="$SUBSCRIPTION_MAX_NODES_DEFAULT" ;;
    *[!0-9]*) max_nodes="$SUBSCRIPTION_MAX_NODES_DEFAULT" ;;
    esac

    config='{"outbounds":[]}'
    idx=0
    kept=0
    skipped=0

    local NETSHIFT_SING_BOX_VERSION NETSHIFT_SING_BOX_TAGS
    NETSHIFT_SING_BOX_VERSION="$(get_sing_box_version)"
    [ -n "${NETSHIFT_SING_BOX_TAGS+x}" ] || NETSHIFT_SING_BOX_TAGS="$(get_sing_box_tags)"

    local cand_file fast_file entries_file
    local feed_end=0 want ncand nfast
    cand_file="$work_dir/cand"
    fast_file="$work_dir/fast"
    entries_file="$work_dir/entries"
    : > "$entries_file"

    local quic_ok utls_ok ext_ok
    core_has_tag with_quic && quic_ok=true || quic_ok=false
    core_has_tag with_utls && utls_ok=true || utls_ok=false
    is_sing_box_extended "$NETSHIFT_SING_BOX_VERSION" && ext_ok=true || ext_ok=false

    exec 3< "$candidate_file"
    while [ "$feed_end" -eq 0 ]; do
        want=0
        if [ "$max_nodes" -gt 0 ]; then
            want=$(( max_nodes - kept ))
            if [ "$want" -le 0 ]; then
                want=1
            fi
        fi

        ncand=0
        {
            while [ "$want" -eq 0 ] || [ "$ncand" -lt "$want" ]; do
                if ! IFS= read -r line <&3; then
                    feed_end=1
                    [ -n "$line" ] || break
                fi
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line%"${line##*[![:space:]]}"}"
                [ -n "$line" ] || continue
                case "$line" in
                '#'*) continue ;;
                esac
                case "${line%%://*}" in
                vless | vmess | trojan | ss | hysteria2 | hy2 | tuic | anytls | socks5 | socks4 | socks4a | naive+https | naive+quic)
                    printf '%s\n' "$line"
                    ncand=$(( ncand + 1 ))
                    ;;
                *)
                    skipped=$(( skipped + 1 ))
                    ;;
                esac
                [ "$feed_end" -eq 0 ] || break
            done
        } > "$cand_file"
        [ "$ncand" -gt 0 ] || break

        if [ "$max_nodes" -gt 0 ] && [ "$kept" -ge "$max_nodes" ]; then
            log "Subscription for '$section' has more than $max_nodes servers; only the first $max_nodes are used" "warn"
            break
        fi

        : > "$fast_file"
        if [ -r "$PODKOP_LIB/linkfast.jq" ]; then
            fast_opt="$(jq -n -c --argjson quic "$quic_ok" --argjson utls "$utls_ok" --argjson ext "$ext_ok" --arg uot "$udp_over_tcp" --argjson base "$idx" \
                '{quic: $quic, utls: $utls, extended: $ext, udp_over_tcp: $uot, base: $base}')"
            jq -R -n -c --argjson opt "$fast_opt" -f "$PODKOP_LIB/linkfast.jq" < "$cand_file" > "$fast_file" 2> /dev/null || : > "$fast_file"
            nfast="$(grep -c '^{"s":"ok"' "$fast_file" 2> /dev/null)"
            log "Subscription for '$section': $ncand link(s) in this round, ${nfast:-0} converted in one pass" "debug"
        fi

        exec 4< "$fast_file"
        while IFS= read -r line; do
            res=""
            IFS= read -r res <&4 || res=""
            case "$res" in
            '{"s":"ok"'*)
                printf '%s\n' "$res" >> "$entries_file"
                idx=$(( idx + 1 ))
                kept=$(( kept + 1 ))
                continue
                ;;
            esac

            case "$line" in
            *"#"*) fragment="${line##*#}" ;;
            *) fragment="" ;;
            esac
            display_name=""
            [ -z "$fragment" ] || display_name="$(url_decode "$fragment" 2>/dev/null)"
            builder_tag="${section}-fb${idx}"
            builder_out_tag="$(get_outbound_tag_by_section "$builder_tag")"

            new_config="$(sing_box_cf_add_proxy_outbound '{"outbounds":[]}' "$builder_tag" "$line" "$udp_over_tcp" </dev/null 2>/dev/null)" || {
                log "skip unparsable subscription key #$idx for '$section'" "debug"
                idx=$(( idx + 1 ))
                continue
            }

            name_out="$(
                printf '%s' "$new_config" | jq -c --arg name "$display_name" --arg builder_out_tag "$builder_out_tag" --argjson i "$idx" '
                    if (.outbounds[-1].tag // null) != $builder_out_tag then error("no outbound added") else . end
                    | {s: "ok", name: $name, ob: (.outbounds[-1] | del(.tag)), i: $i}
                ' 2>/dev/null
            )" && [ -n "$name_out" ] || {
                log "skip subscription key (invalid result or no outbound added) for '$section'" "debug"
                idx=$(( idx + 1 ))
                continue
            }
            printf '%s\n' "$name_out" >> "$entries_file"
            idx=$(( idx + 1 ))
            kept=$(( kept + 1 ))
        done < "$cand_file"
        exec 4<&-
    done
    exec 3<&-

    if [ -s "$entries_file" ]; then
        config="$(jq -s -c --arg section "$section" '
            reduce .[] as $e ({used: {}, out: []};
                ($e.name | explode | map(select(. != 9 and . != 10 and . != 13)) | implode) as $n0
                | (if $n0 == "" then ($section + "-fb" + ($e.i | tostring)) else $n0 end) as $n
                | . as $st
                | (if ($st.used[$n] | not) then $n
                   else first(range(1; 1000001) | ($n + "-" + tostring) as $c | select($st.used[$c] | not) | $c) end) as $tag
                | .used[$tag] = true
                | .out += [{type: $e.ob.type, tag: $tag} + ($e.ob | del(.type))])
            | {outbounds: .out}
        ' "$entries_file" 2>/dev/null)" || config='{"outbounds":[]}'
    fi
    rm -rf "$work_dir"

    if [ "$skipped" -gt 0 ]; then
        log "Fallback subscription parser for '$section' skipped $skipped key(s) with unknown/unsupported schemes" "debug"
    fi

    final_count="$(printf '%s' "$config" | jq -r '.outbounds | length' 2>/dev/null)"
    [ -n "$final_count" ] || final_count=0
    log "Fallback subscription parser for '$section' produced $final_count outbound(s) from $kept accepted key(s)" "debug"
    if [ "$final_count" -le 0 ]; then
        return 1
    fi

    printf '%s' "$config" | jq '.' > "$out_file" 2>/dev/null || return 1
    return 0
}

# Best-effort, in-place gzip decompression of a downloaded subscription body.
maybe_gunzip_subscription_file() {
    local filepath="$1"
    local tmpfile

    [ -s "$filepath" ] || return 0

    tmpfile=$(mktemp)
    if gzip -dc "$filepath" > "$tmpfile" 2>/dev/null &&
        [ -s "$tmpfile" ] &&
        ! subscription_body_is_binary "$tmpfile"; then
        log "Decompressed gzip subscription body for '$filepath'" "debug"
        mv "$tmpfile" "$filepath"
    else
        rm -f "$tmpfile"
    fi

    return 0
}

# Returns 0 (true) if the file contains at least one NUL byte (binary / undecodable).
subscription_body_is_binary() {
    local filepath="$1"
    local raw_count stripped_count

    [ -s "$filepath" ] || return 1

    raw_count="$(wc -c < "$filepath" 2>/dev/null | tr -d ' ')"
    stripped_count="$(tr -d '\000' < "$filepath" 2>/dev/null | wc -c 2>/dev/null | tr -d ' ')"

    [ -n "$raw_count" ] || raw_count=0
    [ -n "$stripped_count" ] || stripped_count=0

    [ "$raw_count" != "$stripped_count" ]
}

# Generates a deterministic HWID based on WAN MAC address and device model.
generate_hwid() {
    local mac="" model="" raw_hash=""

    if [ -f /sys/class/net/eth0/address ]; then
        mac="$(cat /sys/class/net/eth0/address 2>/dev/null)"
    elif [ -f /sys/class/net/br-lan/address ]; then
        mac="$(cat /sys/class/net/br-lan/address 2>/dev/null)"
    fi

    model="$(get_device_model)"

    raw_hash="$(printf '%s-%s' "$mac" "$model" | md5sum | cut -c1-16)"

    printf '%s-%s-%s-%s' \
        "$(echo "$raw_hash" | cut -c1-4)" \
        "$(echo "$raw_hash" | cut -c5-8)" \
        "$(echo "$raw_hash" | cut -c9-12)" \
        "$(echo "$raw_hash" | cut -c13-16)"
}

# One client option of a section.
_subscription_client_option() {
    uci -q get "podkop.$1.subscription_$2" | tr -d "\r\n"
}

# The app a subscription request claims to be. Sets SUBSCRIPTION_HWID,
# SUBSCRIPTION_DEVICE_OS, SUBSCRIPTION_OS_VERSION, SUBSCRIPTION_DEVICE_MODEL and
# SUBSCRIPTION_USER_AGENT.
load_subscription_client_identity() {
    local section="$1"

    SUBSCRIPTION_HWID="$(_subscription_client_option "$section" hwid)"
    SUBSCRIPTION_DEVICE_OS="$(_subscription_client_option "$section" device_os)"
    SUBSCRIPTION_OS_VERSION="$(_subscription_client_option "$section" os_version)"
    SUBSCRIPTION_DEVICE_MODEL="$(_subscription_client_option "$section" device_model)"
    SUBSCRIPTION_USER_AGENT="$(_subscription_client_option "$section" user_agent)"
}

# Resolves the effective subscription User-Agent.
get_subscription_user_agent() {
    local custom_user_agent="${1:-}"

    if [ -n "$custom_user_agent" ]; then
        printf '%s' "$custom_user_agent"
        return 0
    fi

    printf 'singbox/%s' "$(get_sing_box_version)"
}

# Emits the ordered, de-duplicated list of User-Agent candidates.
build_subscription_user_agent_candidates() {
    local configured_user_agent="${1:-}"
    local preferred_user_agent="${2:-}"
    local format_preference="${3:-}"
    local default_user_agent candidate seen

    if [ -n "$configured_user_agent" ]; then
        printf '%s\n' "$configured_user_agent"
        return 0
    fi

    default_user_agent="$(get_subscription_user_agent)"
    seen=""

    if [ "$format_preference" = "xray" ]; then
        set -- $SUBSCRIPTION_USER_AGENT_XRAY_CANDIDATES "$default_user_agent" "$preferred_user_agent" $SUBSCRIPTION_USER_AGENT_CANDIDATES
    else
        set -- "$default_user_agent" "$preferred_user_agent" $SUBSCRIPTION_USER_AGENT_CANDIDATES
    fi

    for candidate in "$@"; do
        [ -n "$candidate" ] || continue
        case "$seen" in
        *"
$candidate
"*) continue ;;
        esac
        seen="${seen}
$candidate
"
        printf '%s\n' "$candidate"
    done
}

# Redact a URL for logging (hide path, query, fragment, userinfo).
redact_url_for_log() {
    local url="$1"
    local scheme rest authority suffix userinfo_flag path_flag query_flag fragment_flag

    scheme=""
    rest="$url"
    userinfo_flag=0
    path_flag=0
    query_flag=0
    fragment_flag=0

    case "$url" in
    *'#'*) fragment_flag=1 ;;
    esac
    rest="${rest%%#*}"

    case "$url" in
    *\?*) query_flag=1 ;;
    esac
    rest="${rest%%\?*}"

    case "$rest" in
    *://*)
        scheme="${rest%%://*}://"
        rest="${rest#*://}"
        ;;
    esac

    authority="${rest%%/*}"
    if [ "$authority" != "$rest" ]; then
        path_flag=1
    fi

    case "$authority" in
    *@*)
        userinfo_flag=1
        authority="${authority##*@}"
        ;;
    esac

    suffix=""
    [ "$path_flag" -eq 1 ] && suffix="$suffix/<redacted>"
    [ "$query_flag" -eq 1 ] && suffix="$suffix?<redacted>"
    [ "$fragment_flag" -eq 1 ] && suffix="$suffix#<redacted>"

    if [ -z "$authority" ]; then
        printf 'redacted-url(has_path=%s,has_query=%s,has_userinfo=%s,has_fragment=%s)\n' \
            "$path_flag" "$query_flag" "$userinfo_flag" "$fragment_flag"
        return 0
    fi

    printf '%s%s%s(has_path=%s,has_query=%s,has_userinfo=%s,has_fragment=%s)\n' \
        "$scheme" "$authority" "$suffix" "$path_flag" "$query_flag" "$userinfo_flag" "$fragment_flag"
}

url_host_for_log() {
    local url="$1"
    local host

    host="${url#*://}"
    host="${host%%/*}"
    host="${host%%\?*}"
    host="${host%%#*}"
    host="${host##*@}"

    case "$host" in
    \[*\]*)
        host="${host#\[}"
        host="${host%%\]*}"
        ;;
    *)
        host="${host%%:*}"
        ;;
    esac

    printf '%s\n' "$host"
}

# One-time, idempotent normalization of a legacy scalar `option subscription_url`
# into the canonical `list subscription_url`. Runs at startup.
migrate_legacy_subscription_url_option() {
    SUBSCRIPTION_URL_OPTION_MIGRATED=0

    config_foreach _migrate_legacy_subscription_url_option_handler "section"

    if [ "$SUBSCRIPTION_URL_OPTION_MIGRATED" -eq 1 ]; then
        if uci commit "podkop" 2>/dev/null; then
            config_load "$PODKOP_CONFIG"
        else
            log "Failed to commit subscription_url option->list migration; continuing" "warn"
        fi
    fi
}

_migrate_legacy_subscription_url_option_handler() {
    local section="$1"
    local connection_type proxy_config_type scalar_url

    config_get connection_type "$section" "connection_type"
    [ "$connection_type" = "proxy" ] || return 0

    config_get proxy_config_type "$section" "proxy_config_type" "url"
    [ "$proxy_config_type" = "subscription" ] || return 0

    SUBSCRIPTION_URLS_COLLECTED=""
    config_list_foreach "$section" "subscription_url" _collect_subscription_url_handler
    [ -z "$SUBSCRIPTION_URLS_COLLECTED" ] || return 0

    config_get scalar_url "$section" "subscription_url"
    [ -n "$scalar_url" ] || return 0

    uci -q delete "podkop.${section}.subscription_url" 2>/dev/null
    if uci_add_list podkop "$section" subscription_url "$scalar_url" 2>/dev/null; then
        SUBSCRIPTION_URL_OPTION_MIGRATED=1
        log "Migrated legacy scalar subscription_url to list for section '$section'" "info"
    else
        uci_set podkop "$section" subscription_url "$scalar_url"
        log "Failed to migrate scalar subscription_url to list for section '$section'; restored the original option" "warn"
    fi
}

# Mark a section as having no usable subscription outbound.
mark_section_without_links() {
    local section="$1"
    local what="$2"

    echolog "Section '$section' has no $what configured; its traffic will be rejected until the configuration is fixed" "error"
    mark_section_outbound_unavailable "$section"
}

# Mark a section outbound as unavailable (reuses SUBSCRIPTION_UNAVAILABLE_SECTIONS).
mark_section_outbound_unavailable() {
    local section="$1"

    case " $SUBSCRIPTION_UNAVAILABLE_SECTIONS " in
    *" $section "*) ;;
    *) SUBSCRIPTION_UNAVAILABLE_SECTIONS="$SUBSCRIPTION_UNAVAILABLE_SECTIONS $section" ;;
    esac
}

# Check if a section is disabled.
section_is_disabled() {
    local section="$1"
    local disabled

    config_get_bool disabled "$section" "disabled" 0
    [ "$disabled" -eq 1 ]
}

###############################################################################
# Subscription support (ported from netshift)
###############################################################################

# Stable, filesystem-safe subkey for a subscription URL within a section. A
# section may list MULTIPLE subscription_url entries; each feed keeps its
# own independent download/UA/rejected/json cache keyed by this hash so the
# feeds never collide and one bad feed cannot poison another. md5sum is
# busybox-safe and the URL bytes are opaque user text (never parsed here). The
# #fragment is left out: it only names the feed on the dashboard and is never
# fetched, so renaming a feed keeps its cache.
get_subscription_url_hash() {
    local url="${1%%#*}"

    printf '%s' "$url" | md5sum 2>/dev/null | awk '{print $1}'
}

# Subscription cache-path builders. The optional second argument is the per-URL
# hash: when present the path is keyed "${section}.<urlhash>.<ext>"; when absent
# it falls back to the legacy bare "${section}.<ext>" path.
get_subscription_json_path() {
    local section="$1"
    local urlhash="$2"

    echo "$SUBSCRIPTION_CACHE_FOLDER/${section}${urlhash:+.$urlhash}.json"
}

get_subscription_url_cache_path() {
    local section="$1"
    local urlhash="$2"

    echo "$SUBSCRIPTION_CACHE_FOLDER/${section}${urlhash:+.$urlhash}.url"
}

# True when the .url sidecar $1 records URL $2. Both sides are compared without
# the #fragment.
subscription_url_cache_matches() {
    local url_cache_path="$1"
    local url="$2"
    local cached_url=""

    [ -f "$url_cache_path" ] && cached_url="$(cat "$url_cache_path" 2>/dev/null)"
    [ "${cached_url%%#*}" = "${url%%#*}" ]
}

get_subscription_rejected_cache_path() {
    local section="$1"
    local urlhash="$2"

    echo "$SUBSCRIPTION_CACHE_FOLDER/${section}${urlhash:+.$urlhash}.rejected"
}

get_subscription_user_agent_cache_path() {
    local section="$1"
    local urlhash="$2"

    echo "$SUBSCRIPTION_CACHE_FOLDER/${section}${urlhash:+.$urlhash}.user_agent"
}

# Collect a section's subscription_url entries (a UCI list; a legacy / CLI /
# migrated `option subscription_url` is a scalar that config_list_foreach does
# NOT iterate — get_subscription_urls_for_section handles that shape with a
# scalar fallback) into the newline-delimited global SUBSCRIPTION_URLS_COLLECTED.
_collect_subscription_url_handler() {
    local url="$1"

    [ -n "$url" ] || return 0
    if [ -z "$SUBSCRIPTION_URLS_COLLECTED" ]; then
        SUBSCRIPTION_URLS_COLLECTED="$url"
    else
        SUBSCRIPTION_URLS_COLLECTED="$SUBSCRIPTION_URLS_COLLECTED
$url"
    fi
}

get_subscription_urls_for_section() {
    local section="$1"
    local scalar_url

    SUBSCRIPTION_URLS_COLLECTED=""
    config_list_foreach "$section" "subscription_url" _collect_subscription_url_handler

    # Backward compat: legacy / CLI / migrated configs store
    # subscription_url as a scalar `option` (not a `list`). config_list_foreach
    # iterates ONLY list values, so it returns nothing for a scalar option. Fall
    # back to a scalar read and treat it as a 1-element list.
    if [ -z "$SUBSCRIPTION_URLS_COLLECTED" ]; then
        config_get scalar_url "$section" "subscription_url"
        [ -n "$scalar_url" ] && _collect_subscription_url_handler "$scalar_url"
    fi

    printf '%s' "$SUBSCRIPTION_URLS_COLLECTED"
}

# Remove any stale legacy bare-"${section}.<ext>" cache files left over from
# before per-URL hashing.
reap_legacy_subscription_cache_files() {
    local section="$1"

    rm -f \
        "$(get_subscription_json_path "$section")" \
        "$(get_subscription_url_cache_path "$section")" \
        "$(get_subscription_rejected_cache_path "$section")" \
        "$(get_subscription_user_agent_cache_path "$section")" \
        2>/dev/null
}

# Remove per-URL cache files of section $1 whose URL hash matches none of the
# URLs listed in file $2 (one per line).
reap_orphan_subscription_cache_files() {
    local section="$1"
    local urls_file="$2"
    local keep_hashes="" url urlhash cache_file name removed=0

    [ -d "$SUBSCRIPTION_CACHE_FOLDER" ] || return 0

    while IFS= read -r url || [ -n "$url" ]; do
        [ -n "$url" ] || continue
        urlhash="$(get_subscription_url_hash "$url")"
        [ -n "$urlhash" ] || return 0
        keep_hashes="$keep_hashes $urlhash"
    done < "$urls_file"
    [ -n "$keep_hashes" ] || return 0

    for cache_file in "$SUBSCRIPTION_CACHE_FOLDER/$section".*; do
        [ -f "$cache_file" ] || continue
        name="${cache_file##*/}"
        name="${name#"$section".}"
        urlhash="${name%%.*}"
        [ "$urlhash" != "$name" ] && [ "${#urlhash}" -eq 32 ] || continue
        case "$urlhash" in
        *[!0-9a-f]*) continue ;;
        esac
        case " $keep_hashes " in
        *" $urlhash "*) continue ;;
        esac
        rm -f "$cache_file" 2>/dev/null && removed=$((removed + 1))
    done

    [ "$removed" -eq 0 ] ||
        log "Removed $removed cache file(s) of subscription links no longer listed in section '$section'" "info"
}

ensure_subscription_cache_dir() {
    local state_dir_created=0 cache_dir_created=0
    local mkdir_errfile mkdir_rc

    [ -d "$PODKOP_STATE_DIR" ] || state_dir_created=1
    [ -d "$SUBSCRIPTION_CACHE_FOLDER" ] || cache_dir_created=1
    mkdir_errfile="/tmp/podkop-subscription-cache-mkdir.$$"
    if mkdir -p "$SUBSCRIPTION_CACHE_FOLDER" 2>"$mkdir_errfile"; then
        rm -f "$mkdir_errfile"
    else
        mkdir_rc=$?
        if [ -d "$SUBSCRIPTION_CACHE_FOLDER" ]; then
            log "Subscription cache directory '$SUBSCRIPTION_CACHE_FOLDER' already exists; continuing after mkdir rc=$mkdir_rc" "warn"
            rm -f "$mkdir_errfile"
        else
            local mkdir_err
            mkdir_err="$(tr '\n' ' ' < "$mkdir_errfile" 2>/dev/null | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//' | cut -c1-220)"
            rm -f "$mkdir_errfile"
            log "Failed to prepare subscription cache directory '$SUBSCRIPTION_CACHE_FOLDER': mkdir rc=$mkdir_rc, error=\"${mkdir_err:-no stderr}\"" "error"
            return 1
        fi
    fi

    if [ "$state_dir_created" -eq 1 ] || [ "$cache_dir_created" -eq 1 ]; then
        chmod 700 "$PODKOP_STATE_DIR" 2>/dev/null
        chmod 700 "$SUBSCRIPTION_CACHE_FOLDER" 2>/dev/null
    fi
}

migrate_subscription_cache_from_tmp() {
    local src_json src_url src_section src_url_value dst_url dst_json dst_url_cache urlhash

    [ -d "$TMP_SUBSCRIPTION_FOLDER" ] || return 0
    ensure_subscription_cache_dir || return 0

    # Legacy tmp caches are bare-keyed "<section>.json" (one feed per section).
    for src_json in "$TMP_SUBSCRIPTION_FOLDER"/*.json; do
        [ -e "$src_json" ] || continue
        src_section="$(basename "${src_json%.json}")"
        src_url="${src_json%.json}.url"

        subscription_cache_is_usable "$src_json" || continue

        src_url_value="$(cat "$src_url" 2>/dev/null)"
        if [ -z "$src_url_value" ]; then
            src_url_value="$(get_subscription_urls_for_section "$src_section" | head -n 1)"
        fi
        [ -n "$src_url_value" ] || continue

        urlhash="$(get_subscription_url_hash "$src_url_value")"
        [ -n "$urlhash" ] || continue
        dst_json="$(get_subscription_json_path "$src_section" "$urlhash")"
        dst_url_cache="$(get_subscription_url_cache_path "$src_section" "$urlhash")"

        if [ ! -e "$dst_json" ]; then
            cp "$src_json" "$dst_json" 2>/dev/null
            printf '%s' "${src_url_value%%#*}" > "$dst_url_cache" 2>/dev/null
            chmod 600 "$dst_json" "$dst_url_cache" 2>/dev/null
            log "Migrated subscription cache for section '$src_section' to per-URL persistent storage" "info"
        fi
    done
}

mark_subscription_outbound_unavailable() {
    local section="$1"
    local keyword_filter_active="${2:-0}"
    local url urlhash subscription_json_path rejected_cache_path rejected_hash

    case " $SUBSCRIPTION_UNAVAILABLE_SECTIONS " in
    *" $section "*) ;;
    *) SUBSCRIPTION_UNAVAILABLE_SECTIONS="$SUBSCRIPTION_UNAVAILABLE_SECTIONS $section" ;;
    esac

    if [ "$keyword_filter_active" -eq 1 ]; then
        get_subscription_urls_for_section "$section" | while IFS= read -r url; do
            [ -n "$url" ] || continue
            urlhash="$(get_subscription_url_hash "$url")"
            rm -f "$(get_subscription_rejected_cache_path "$section" "$urlhash")"
        done
        log "Subscription filter for section '$section' (keywords and/or parameters) removed all nodes" "warn"
        return 0
    fi

    log "Subscription cache for section '$section' is unavailable; matching traffic for this section will be rejected until refresh succeeds" "warn"
    get_subscription_urls_for_section "$section" | while IFS= read -r url; do
        [ -n "$url" ] || continue
        urlhash="$(get_subscription_url_hash "$url")"
        subscription_json_path="$(get_subscription_json_path "$section" "$urlhash")"
        rejected_cache_path="$(get_subscription_rejected_cache_path "$section" "$urlhash")"
        [ -s "$subscription_json_path" ] || continue
        rejected_hash="$(md5sum "$subscription_json_path" 2>/dev/null | awk '{print $1}')"
        if [ -n "$rejected_hash" ] && [ "$(cat "$rejected_cache_path" 2>/dev/null)" != "$rejected_hash" ]; then
            printf '%s' "$rejected_hash" > "${rejected_cache_path}.tmp.$$" && mv "${rejected_cache_path}.tmp.$$" "$rejected_cache_path"
            chmod 600 "$rejected_cache_path" 2>/dev/null
        fi
    done
}

subscription_outbound_is_unavailable() {
    local section="$1"

    case " $SUBSCRIPTION_UNAVAILABLE_SECTIONS " in
    *" $section "*) return 0 ;;
    esac
    return 1
}

download_proxy_section_is_unavailable() {
    local section="$1"
    local connection_type

    subscription_outbound_is_unavailable "$section" && return 0
    section_is_disabled "$section" && return 0

    config_get connection_type "$section" "connection_type"
    [ -z "$connection_type" ]
}

get_subscription_download_proxy_address() {
    local section="$1"
    local phase="$2"
    local download_lists_via_proxy download_lists_via_proxy_section

    config_get_bool download_lists_via_proxy "settings" "download_lists_via_proxy" 0
    [ "$download_lists_via_proxy" -eq 1 ] || return 0

    config_get download_lists_via_proxy_section "settings" "download_lists_via_proxy_section"
    if [ -z "$download_lists_via_proxy_section" ]; then
        log "download_lists_via_proxy is enabled but no proxy section is selected; using direct mode for $phase subscription download" "warn"
        return 0
    fi

    if [ "$phase" = "bootstrap" ]; then
        if [ "$download_lists_via_proxy_section" = "$section" ]; then
            log "Cannot bootstrap subscription for section '$section' through itself before cache exists; using direct mode" "warn"
        else
            log "download_lists_via_proxy is configured, but bootstrap subscription download for section '$section' must use direct mode until sing-box starts" "info"
        fi
        return 0
    fi

    if [ "$download_lists_via_proxy_section" = "$section" ]; then
        if section_has_usable_subscription_cache "$section"; then
            log "Updating subscription for section '$section' through its currently active cached proxy" "info"
            echo "$(get_service_proxy_address 2>/dev/null || echo '')"
            return 0
        fi

        log "Subscription section '$section' is selected as its own download proxy, but no usable cache exists yet; falling back to direct mode for bootstrap" "warn"
        return 0
    fi

    if section_is_disabled "$download_lists_via_proxy_section"; then
        log "Selected download proxy section '$download_lists_via_proxy_section' is disabled; using direct mode for $phase subscription download of '$section'" "warn"
        return 0
    fi

    echo "$(get_service_proxy_address 2>/dev/null || echo '')"
}

# Prints a fingerprint of the nodes in subscription cache $1.
subscription_nodes_fingerprint() {
    local nodes

    nodes="$(jq -c '[.outbounds[]?
        | select(.type | IN("selector", "urltest", "direct", "dns", "block") | not)
        | del(.tag) | tojson] | sort' "$1" 2> /dev/null)" || return 0
    [ -n "$nodes" ] || return 0
    printf '%s' "$nodes" | md5sum 2> /dev/null | awk '{print $1}'
}

subscription_cache_is_usable() {
    local subscription_json_path="$1"
    local rejected_cache_path current_hash rejected_hash has_proxy_outbound

    [ -s "$subscription_json_path" ] || return 1

    validate_subscription_file "$subscription_json_path" || return 1

    has_proxy_outbound="$(jq -e '
        [.outbounds[]? | select(
            .type != "selector" and
            .type != "urltest" and
            .type != "direct" and
            .type != "dns" and
            .type != "block"
        )] | length > 0
    ' "$subscription_json_path" >/dev/null 2>&1 && echo 1 || echo 0)"
    [ "$has_proxy_outbound" = "1" ] && return 0

    rejected_cache_path="${subscription_json_path%.json}.rejected"
    if [ -s "$rejected_cache_path" ]; then
        current_hash="$(md5sum "$subscription_json_path" 2>/dev/null | awk '{print $1}')"
        rejected_hash="$(cat "$rejected_cache_path" 2>/dev/null)"
        if [ -n "$current_hash" ] && [ "$current_hash" = "$rejected_hash" ]; then
            return 1
        fi
    fi

    return 0
}

# True (0) if ANY of the section's per-URL subscription caches is usable.
section_has_usable_subscription_cache() {
    local section="$1"
    local url urlhash found urls_tmp

    found=1
    urls_tmp="$(mktemp "${TMPDIR:-/tmp}/podkop-sub-urls.XXXXXX")" || return 1
    get_subscription_urls_for_section "$section" > "$urls_tmp"
    while IFS= read -r url || [ -n "$url" ]; do
        [ -n "$url" ] || continue
        urlhash="$(get_subscription_url_hash "$url")"
        if subscription_cache_is_usable "$(get_subscription_json_path "$section" "$urlhash")"; then
            found=0
            break
        fi
    done < "$urls_tmp"
    rm -f "$urls_tmp"

    return "$found"
}

wait_for_subscription_connectivity() {
    local section="$1"
    local subscription_url="$2"
    local service_proxy_address="$3"
    local attempts="${4:-12}"
    local wait="${5:-5}"
    local timeout="${6:-5}"
    local attempt
    local SUBSCRIPTION_HWID SUBSCRIPTION_DEVICE_OS SUBSCRIPTION_OS_VERSION SUBSCRIPTION_DEVICE_MODEL SUBSCRIPTION_USER_AGENT

    load_subscription_client_identity "$section"
    for attempt in $(seq 1 "$attempts"); do
        if check_subscription_connectivity "$subscription_url" "$service_proxy_address" 1 0 "$timeout"; then
            log "Subscription connectivity check passed for section '$section'" "info"
            return 0
        fi

        log "Subscription source is unavailable for section '$section' [$attempt/$attempts]" "warn"
        [ "$attempt" -lt "$attempts" ] && sleep "$wait"
    done

    log "Subscription connectivity check failed for section '$section' after $attempts attempts" "error"
    return 1
}

download_subscription_into_cache() {
    local section="$1"
    local subscription_url="$2"
    local subscription_json_path="$3"
    local subscription_url_cache_path="$4"
    local service_proxy_address="$5"
    local urlhash="$6"
    local tmpfile persist_tmpfile url_tmpfile rejected_cache_path tmp_hash rejected_hash validation_reason
    local configured_user_agent user_agent_cache_path cached_user_agent candidates_file
    local effective_user_agent download_ok winning_user_agent ua_tmpfile
    local subscription_insecure subscription_format_preference
    local SUBSCRIPTION_HWID SUBSCRIPTION_DEVICE_OS SUBSCRIPTION_OS_VERSION SUBSCRIPTION_DEVICE_MODEL SUBSCRIPTION_USER_AGENT

    ensure_subscription_cache_dir || {
        log "Failed to prepare persistent subscription cache directory '$SUBSCRIPTION_CACHE_FOLDER' for section '$section'" "error"
        return 10
    }
    mkdir -p "$TMP_SUBSCRIPTION_DOWNLOAD_FOLDER" || {
        log "Failed to create temporary subscription download directory '$TMP_SUBSCRIPTION_DOWNLOAD_FOLDER' for section '$section'" "error"
        return 11
    }
    tmpfile="$(mktemp "$TMP_SUBSCRIPTION_DOWNLOAD_FOLDER/${section}.download.XXXXXX")" || {
        log "Failed to create temporary subscription download file in '$TMP_SUBSCRIPTION_DOWNLOAD_FOLDER' for section '$section'" "error"
        return 11
    }

    load_subscription_client_identity "$section"
    user_agent_cache_path="$(get_subscription_user_agent_cache_path "$section" "$urlhash")"
    configured_user_agent="$SUBSCRIPTION_USER_AGENT"
    cached_user_agent="$(cat "$user_agent_cache_path" 2>/dev/null)"
    subscription_format_preference="$(uci -q get "podkop.${section}.subscription_format_preference" 2>/dev/null)"
    [ -n "$subscription_format_preference" ] || subscription_format_preference="auto"
    candidates_file="${tmpfile}.ua"
    if ! build_subscription_user_agent_candidates "$configured_user_agent" "$cached_user_agent" "$subscription_format_preference" > "$candidates_file"; then
        log "Failed to build subscription User-Agent candidate list for section '$section'" "error"
        rm -f "$tmpfile" "$candidates_file"
        return 11
    fi

    subscription_insecure="$(uci -q get "podkop.${section}.subscription_insecure" 2>/dev/null)"
    [ -n "$subscription_insecure" ] || subscription_insecure=0
    if [ "$subscription_insecure" = "1" ]; then
        log "Subscription fetch for section '$section' uses --no-check-certificate (TLS verification disabled): url=$(redact_url_for_log "$subscription_url")" "warn"
    fi

    download_ok=0
    winning_user_agent=""
    while IFS= read -r effective_user_agent || [ -n "$effective_user_agent" ]; do
        [ -n "$effective_user_agent" ] || continue

        log "Trying subscription User-Agent for section '$section': $effective_user_agent" "info"

        if ! download_subscription "$subscription_url" "$tmpfile" "$service_proxy_address" 3 2 10 "$effective_user_agent" "$subscription_insecure"; then
            log "Subscription download failed for section '$section' with User-Agent '$effective_user_agent'; trying next candidate" "warn"
            continue
        fi

        maybe_gunzip_subscription_file "$tmpfile"
        if subscription_body_is_binary "$tmpfile"; then
            log "Subscription body for section '$section' is binary/undecodable after gzip handling with User-Agent '$effective_user_agent'; trying next candidate" "warn"
            continue
        fi

        if validate_subscription_file "$tmpfile"; then
            download_ok=1
            winning_user_agent="$effective_user_agent"
            break
        fi

        # Fallback: provider returned base64 / plaintext key list or Xray JSON
        if normalize_subscription_to_singbox "$tmpfile" "${tmpfile}.fb" "$section" && validate_subscription_file "${tmpfile}.fb"; then
            mv -f "${tmpfile}.fb" "$tmpfile"
            log "Subscription for section '$section' parsed via fallback with User-Agent '$effective_user_agent'" "info"
            download_ok=1
            winning_user_agent="$effective_user_agent"
            break
        fi
        rm -f "${tmpfile}.fb"

        validation_reason="$(describe_subscription_validation_failure "$tmpfile")"
        log "Downloaded subscription for section '$section' is invalid with User-Agent '$effective_user_agent': ${validation_reason:-unknown validation error}; trying next candidate" "warn"
    done < "$candidates_file"
    rm -f "$candidates_file"

    if [ "$download_ok" -ne 1 ]; then
        log "No subscription User-Agent candidate produced valid outbounds for section '$section'" "error"
        rm -f "$tmpfile"
        return 13
    fi

    if [ -n "$winning_user_agent" ]; then
        ua_tmpfile="${user_agent_cache_path}.tmp.$$"
        if printf '%s' "$winning_user_agent" > "$ua_tmpfile" && mv "$ua_tmpfile" "$user_agent_cache_path"; then
            chmod 600 "$user_agent_cache_path" 2>/dev/null
        else
            rm -f "$ua_tmpfile"
        fi
    fi

    subscription_refresh_info "$section" "$subscription_url" "$urlhash" "$winning_user_agent" \
        "$service_proxy_address" "$subscription_insecure"

    rejected_cache_path="$(get_subscription_rejected_cache_path "$section" "$urlhash")"
    tmp_hash="$(md5sum "$tmpfile" 2>/dev/null | awk '{print $1}')"
    rejected_hash="$(cat "$rejected_cache_path" 2>/dev/null)"
    if [ -n "$tmp_hash" ] && [ "$tmp_hash" = "$rejected_hash" ]; then
        log "Downloaded subscription for section '$section' is unchanged and was previously rejected because it contains no usable sing-box outbounds" "warn"
        rm -f "$tmpfile"
        return 14
    fi

    if [ -f "$subscription_json_path" ] && cmp -s "$tmpfile" "$subscription_json_path"; then
        rm -f "$tmpfile"
        if ! subscription_url_cache_matches "$subscription_url_cache_path" "$subscription_url"; then
            url_tmpfile="${subscription_url_cache_path}.tmp.$$"
            if printf '%s' "${subscription_url%%#*}" > "$url_tmpfile" && mv "$url_tmpfile" "$subscription_url_cache_path"; then
                chmod 600 "$subscription_url_cache_path" 2>/dev/null
            else
                log "Subscription content for section '$section' is unchanged, but URL metadata could not be persisted; the next refresh may download it again" "warn"
                rm -f "$url_tmpfile"
            fi
        fi
        log "Subscription for section '$section' is unchanged" "info"
        return 2
    fi

    persist_tmpfile="${subscription_json_path}.tmp.$$"
    cp "$tmpfile" "$persist_tmpfile" && mv "$persist_tmpfile" "$subscription_json_path" || {
        log "Failed to persist subscription cache for section '$section' to '$subscription_json_path'" "error"
        rm -f "$tmpfile" "$persist_tmpfile"
        return 15
    }
    rm -f "$tmpfile"
    rm -f "$rejected_cache_path"

    url_tmpfile="${subscription_url_cache_path}.tmp.$$"
    printf '%s' "${subscription_url%%#*}" > "$url_tmpfile" && mv "$url_tmpfile" "$subscription_url_cache_path" || {
        log "Subscription cache for section '$section' was updated, but URL metadata could not be persisted; applying the cache and retrying metadata on a later refresh" "warn"
        rm -f "$url_tmpfile"
    }
    chmod 600 "$subscription_json_path" "$subscription_url_cache_path" 2>/dev/null
    return 0
}

prepare_subscription_cache_for_startup() {
    local section="$1"
    local connection_type proxy_config_type urls_tmp url urlhash
    local subscription_json_path subscription_url_cache_path
    local service_proxy_address had_usable_cache cache_needs_refresh
    local _download_lists_via_proxy section_any_usable url_count

    config_get connection_type "$section" "connection_type"
    [ "$connection_type" = "proxy" ] || return 0

    config_get proxy_config_type "$section" "proxy_config_type"
    [ "$proxy_config_type" = "subscription" ] || return 0

    ensure_subscription_cache_dir || true
    migrate_subscription_cache_from_tmp
    reap_legacy_subscription_cache_files "$section"

    urls_tmp="$(mktemp "${TMPDIR:-/tmp}/podkop-startup-urls.XXXXXX")" || {
        log "Failed to create temporary URL list for section '$section'" "error"
        return 0
    }
    get_subscription_urls_for_section "$section" > "$urls_tmp"
    url_count=0
    while IFS= read -r url || [ -n "$url" ]; do
        [ -n "$url" ] && url_count=$((url_count + 1))
    done < "$urls_tmp"

    if [ "$url_count" -eq 0 ]; then
        rm -f "$urls_tmp"
        mark_section_without_links "$section" "subscription URL (subscription_url)"
        return 0
    fi

    config_get_bool _download_lists_via_proxy "settings" "download_lists_via_proxy" 0
    if [ "$_download_lists_via_proxy" -eq 1 ]; then
        log "download_lists_via_proxy is set, but sing-box is not running yet during startup. Bootstrapping subscription for section '$section' over a direct connection" "info"
    fi

    section_any_usable=0
    while IFS= read -r url || [ -n "$url" ]; do
        [ -n "$url" ] || continue
        urlhash="$(get_subscription_url_hash "$url")"
        subscription_json_path="$(get_subscription_json_path "$section" "$urlhash")"
        subscription_url_cache_path="$(get_subscription_url_cache_path "$section" "$urlhash")"

        had_usable_cache=0
        if subscription_cache_is_usable "$subscription_json_path"; then
            had_usable_cache=1
        else
            rm -f "$subscription_json_path"
        fi

        cache_needs_refresh=0
        if [ "$had_usable_cache" -eq 0 ] || ! subscription_url_cache_matches "$subscription_url_cache_path" "$url"; then
            cache_needs_refresh=1
        fi

        if [ "$cache_needs_refresh" -eq 0 ]; then
            section_any_usable=1
            continue
        fi

        service_proxy_address=""
        if wait_for_subscription_connectivity "$section" "$url" "$service_proxy_address" 2 2 5 &&
            download_subscription_into_cache \
                "$section" "$url" "$subscription_json_path" "$subscription_url_cache_path" "$service_proxy_address" "$urlhash"; then
            section_any_usable=1
            continue
        fi

        if [ "$had_usable_cache" -eq 1 ]; then
            log "Keeping cached subscription feed for section '$section' (url=$(redact_url_for_log "$url")) until a fresh download succeeds" "warn"
            section_any_usable=1
        else
            log "Subscription feed for section '$section' (url=$(redact_url_for_log "$url")) is not reachable and has no usable cache yet" "warn"
        fi
    done < "$urls_tmp"
    rm -f "$urls_tmp"

    if [ "$section_any_usable" -eq 0 ]; then
        log "No usable subscription cache for any feed of section '$section'; startup will continue with a temporary blocked outbound until a subscription becomes reachable" "warn"
    fi

    return 0
}

# config_foreach over type "section" that skips disabled sections.
foreach_active_section() {
    local previous_callback="$_foreach_active_section_callback"
    local rc

    _foreach_active_section_callback="$1"
    shift
    config_foreach _foreach_active_section_dispatch "$@"
    rc=$?
    _foreach_active_section_callback="$previous_callback"
    return "$rc"
}

_foreach_active_section_dispatch() {
    section_is_disabled "$1" && return 0
    "$_foreach_active_section_callback" "$@"
}

prepare_subscription_caches_for_startup() {
    foreach_active_section prepare_subscription_cache_for_startup "section"
}

stop_subscription_startup_retry_worker() {
    local pidfile="$SUBSCRIPTION_RETRY_PIDFILE"
    local pid waited

    if [ -f "$pidfile" ]; then
        pid="$(cat "$pidfile" 2> /dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; then
            kill "$pid" 2> /dev/null
            waited=0
            while kill -0 "$pid" 2> /dev/null && [ "$waited" -lt 20 ]; do
                sleep 0.1 2> /dev/null || sleep 1
                waited=$((waited + 1))
            done
            if kill -0 "$pid" 2> /dev/null; then
                log "Deferred startup recovery worker $pid did not stop in time" "warn"
                return 0
            fi
            log "Stopped deferred startup recovery worker"
        fi
        if [ "$(cat "$pidfile" 2> /dev/null)" = "$pid" ]; then
            rm -f "$pidfile"
        fi
    fi
}

start_subscription_startup_retry_worker() {
    local pidfile="$SUBSCRIPTION_RETRY_PIDFILE"
    local pid waited

    if [ -f "$pidfile" ]; then
        pid="$(cat "$pidfile" 2> /dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; then
            log "Deferred startup recovery worker is already running" "debug"
            return 0
        fi
        rm -f "$pidfile"
    fi

    if command -v setsid > /dev/null 2>&1; then
        setsid /bin/sh -c 'exec 1000>&- 2>/dev/null; exec /usr/bin/podkop __subscription_retry' < /dev/null > /dev/null 2>&1 &
    else
        /bin/sh -c 'exec 1000>&- 2>/dev/null; exec /usr/bin/podkop __subscription_retry' < /dev/null > /dev/null 2>&1 &
    fi
    waited=0
    while [ ! -s "$pidfile" ] && [ "$waited" -lt 20 ]; do
        sleep 0.1 2> /dev/null || sleep 1
        waited=$((waited + 1))
    done
    pid="$(cat "$pidfile" 2> /dev/null)"
    if [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; then
        log "Started deferred startup recovery worker with PID $pid" "warn"
    else
        log "Deferred startup recovery worker did not publish its PID" "warn"
    fi
}

subscription_startup_retry_worker_cleanup() {
    local pidfile="$1" worker_pid="$2" sleep_pid="${3:-}"

    [ -z "$sleep_pid" ] || kill "$sleep_pid" 2> /dev/null
    if [ "$(cat "$pidfile" 2> /dev/null)" = "$worker_pid" ]; then
        rm -f "$pidfile"
    fi
}

subscription_startup_retry_worker_claim() {
    local pidfile="$1" pid

    pid="$(cat "$pidfile" 2> /dev/null)"
    if [ -n "$pid" ]; then
        kill -0 "$pid" 2> /dev/null && return 1
        rm -f "$pidfile"
    fi
    (
        set -C
        echo "$$" > "$pidfile"
    ) 2> /dev/null
}

subscription_startup_retry_worker() {
    local pidfile="$SUBSCRIPTION_RETRY_PIDFILE"
    local apply_failures=0 sleep_pid="" rc delay

    subscription_startup_retry_worker_claim "$pidfile" || return 0
    trap 'subscription_startup_retry_worker_cleanup "$pidfile" "$$" "$sleep_pid"' EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT

    sleep 10 &
    sleep_pid=$!
    wait "$sleep_pid"
    sleep_pid=""

    while true; do
        config_load "$PODKOP_CONFIG"

        /usr/bin/podkop subscription_update &
        wait "$!"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            log "Deferred subscription refresh succeeded; updated configuration is being applied" "info"
            exit 0
        fi

        delay="$SUBSCRIPTION_RETRY_INTERVAL"
        if [ "$rc" -eq "$SUBSCRIPTION_UPDATE_APPLY_FAILED" ]; then
            apply_failures=$((apply_failures + 1))
            if [ "$apply_failures" -ge "$SUBSCRIPTION_RETRY_MAX_APPLY_FAILURES" ]; then
                log "Deferred subscription refresh downloaded the feeds but could not apply them $apply_failures times in a row; leaving it to the scheduled subscription update" "error"
                exit 1
            fi
            delay=$((SUBSCRIPTION_RETRY_INTERVAL * (1 << (apply_failures - 1))))
            [ "$delay" -gt "$SUBSCRIPTION_RETRY_BACKOFF_MAX" ] && delay="$SUBSCRIPTION_RETRY_BACKOFF_MAX"
        fi

        log "Deferred subscription refresh has not completed yet; retrying in ${delay}s" "warn"
        sleep "$delay" &
        sleep_pid=$!
        wait "$sleep_pid"
        sleep_pid=""
    done
}

# --- Subscription update lock ------------------------------------------------

subscription_update_lock_process_start() {
    local stat_line

    stat_line="$(cat "/proc/$1/stat" 2> /dev/null)" || return 0
    stat_line="${stat_line##*) }"
    set -- $stat_line
    [ "$#" -ge 20 ] && printf '%s' "${20}"
}

subscription_update_lock_owner_alive() {
    local owner_pid="$1" owner_start="$2"

    case "$owner_pid" in
    '' | *[!0-9]*) return 1 ;;
    esac
    kill -0 "$owner_pid" 2> /dev/null || return 1
    if [ -n "$owner_start" ]; then
        [ "$(subscription_update_lock_process_start "$owner_pid")" = "$owner_start" ]
        return $?
    fi
    [ -r "/proc/$owner_pid/cmdline" ] || return 0
    tr '\000' ' ' < "/proc/$owner_pid/cmdline" 2> /dev/null | grep -q "podkop"
}

subscription_update_lock_take_over() {
    local owner_pid="$1"
    local stale_dir="$SUBSCRIPTION_UPDATE_LOCK_DIR.stale.$$"
    local moved_pid moved_start

    if [ -e "$stale_dir" ]; then
        moved_pid="$(cat "$stale_dir/pid" 2> /dev/null)"
        moved_start="$(cat "$stale_dir/start" 2> /dev/null)"
        subscription_update_lock_owner_alive "$moved_pid" "$moved_start" && return 0
        rm -rf "$stale_dir"
    fi

    mv "$SUBSCRIPTION_UPDATE_LOCK_DIR" "$stale_dir" 2> /dev/null || return 0
    moved_pid="$(cat "$stale_dir/pid" 2> /dev/null)"
    moved_start="$(cat "$stale_dir/start" 2> /dev/null)"
    if [ "$moved_pid" = "$owner_pid" ] &&
        ! subscription_update_lock_owner_alive "$moved_pid" "$moved_start"; then
        rm -rf "$stale_dir"
        return 0
    fi

    if [ ! -e "$SUBSCRIPTION_UPDATE_LOCK_DIR" ] &&
        mv "$stale_dir" "$SUBSCRIPTION_UPDATE_LOCK_DIR" 2> /dev/null; then
        return 0
    fi
    log "Subscription update lock changed hands (owner pid '${moved_pid:-unknown}') and could not be put back; left at '$stale_dir'" "warn"
}

subscription_update_lock_acquire() {
    local mode="${1:-wait}"
    local waited=0 owner_pid owner_start ownerless_checks=0
    local takeovers=0 create_failures=0

    mkdir -p "${SUBSCRIPTION_UPDATE_LOCK_DIR%/*}" 2> /dev/null
    while ! mkdir "$SUBSCRIPTION_UPDATE_LOCK_DIR" 2> /dev/null; do
        if [ ! -d "$SUBSCRIPTION_UPDATE_LOCK_DIR" ]; then
            create_failures=$((create_failures + 1))
            if [ "$create_failures" -ge "$SUBSCRIPTION_UPDATE_LOCK_RETRIES" ]; then
                log "Cannot create the subscription update lock '$SUBSCRIPTION_UPDATE_LOCK_DIR' (no space left or the directory is not writable)" "error"
                return 2
            fi
            sleep 1
            waited=$((waited + 1))
            continue
        fi

        owner_pid="$(cat "$SUBSCRIPTION_UPDATE_LOCK_DIR/pid" 2> /dev/null)"
        owner_start="$(cat "$SUBSCRIPTION_UPDATE_LOCK_DIR/start" 2> /dev/null)"
        if [ -z "$owner_pid" ] && [ "$ownerless_checks" -eq 0 ]; then
            ownerless_checks=1
            sleep 1
            waited=$((waited + 1))
            continue
        fi
        if ! subscription_update_lock_owner_alive "$owner_pid" "$owner_start"; then
            takeovers=$((takeovers + 1))
            if [ "$takeovers" -gt "$SUBSCRIPTION_UPDATE_LOCK_RETRIES" ]; then
                log "Subscription update lock '$SUBSCRIPTION_UPDATE_LOCK_DIR' is stale and could not be taken over; giving up" "error"
                return 2
            fi
            log "Subscription update lock is stale (owner pid '${owner_pid:-unknown}' is gone); taking it over" "warn"
            subscription_update_lock_take_over "$owner_pid"
            if [ "$takeovers" -gt 1 ]; then
                sleep 1
                waited=$((waited + 1))
            fi
            ownerless_checks=0
            continue
        fi

        [ "$mode" = "wait" ] || return 1
        [ "$waited" -lt "$SUBSCRIPTION_UPDATE_LOCK_WAIT" ] || return 1
        sleep 1
        waited=$((waited + 1))
        ownerless_checks=0
    done

    if ! echo "$$" > "$SUBSCRIPTION_UPDATE_LOCK_DIR/pid"; then
        log "Cannot write the owner of the subscription update lock '$SUBSCRIPTION_UPDATE_LOCK_DIR'" "error"
        rm -rf "$SUBSCRIPTION_UPDATE_LOCK_DIR"
        return 2
    fi
    subscription_update_lock_process_start "$$" > "$SUBSCRIPTION_UPDATE_LOCK_DIR/start" 2> /dev/null
    return 0
}

subscription_update_lock_release() {
    local owner_pid

    [ -e "$SUBSCRIPTION_UPDATE_LOCK_DIR" ] || return 0
    owner_pid="$(cat "$SUBSCRIPTION_UPDATE_LOCK_DIR/pid" 2> /dev/null)"
    if [ "$owner_pid" != "$$" ]; then
        log "Subscription update lock now belongs to pid '${owner_pid:-unknown}'; leaving it in place" "warn"
        return 0
    fi
    rm -rf "$SUBSCRIPTION_UPDATE_LOCK_DIR"
}

subscription_update_lock_refused() {
    if [ "$1" -eq 1 ]; then
        echolog "⚠️ Another subscription update is still running; this run is skipped" "warn"
        return "$SUBSCRIPTION_UPDATE_BUSY"
    fi
    echolog "❌ The subscription update lock could not be taken (see the log); this run is skipped" "error"
    return "$SUBSCRIPTION_UPDATE_LOCK_FAILED"
}

#######################################
# Parses a file line by line, validates entries as either domains or subnets,
# and returns a single comma-separated string of valid items.
# Arguments:
#   $1 - Path to the input file
#   $2 - Type of validation ("domains" or "subnets")
# Outputs:
#   Comma-separated string of valid domains or subnets
#######################################
parse_domain_or_subnet_file_to_comma_string() {
    local filepath="$1"
    local type="$2"

    local result
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        [ -z "$line" ] && continue

        case "$type" in
        domains)
            if ! is_domain_suffix "$line"; then
                log "'$line' is not a valid domain" "debug"
                continue
            fi
            ;;
        subnets)
            if ! is_ipv4 "$line" && ! is_ipv4_cidr "$line"; then
                log "'$line' is not IPv4 or IPv4 CIDR" "debug"
                continue
            fi
            ;;
        *)
            log "Unknown type: $type" "error"
            return 1
            ;;
        esac

        if [ -z "$result" ]; then
            result="$line"
        else
            result="$result,$line"
        fi
    done < "$filepath"

    echo "$result"
}