PODKOP_LIB="/usr/lib/podkop"
. "$PODKOP_LIB/helpers.sh"
. "$PODKOP_LIB/sing_box_config_manager.sh"

sing_box_cf_add_dns_server() {
    local config="$1"
    local type="$2"
    local tag="$3"
    local server="$4"
    local domain_resolver="$5"
    local detour="$6"

    local server_address server_port
    server_address=$(url_get_host "$server")
    server_port=$(url_get_port "$server")

    case "$type" in
    udp)
        [ -z "$server_port" ] && server_port=53
        config=$(sing_box_cm_add_udp_dns_server "$config" "$tag" "$server_address" "$server_port" "$domain_resolver" \
            "$detour")
        ;;
    dot)
        [ -z "$server_port" ] && server_port=853
        config=$(sing_box_cm_add_tls_dns_server "$config" "$tag" "$server_address" "$server_port" "$domain_resolver" \
            "$detour")
        ;;
    doh)
        [ -z "$server_port" ] && server_port=443
        local path headers
        path=$(url_get_path "$server")
        headers="" # TODO(ampetelin): implement it if necessary
        config=$(sing_box_cm_add_https_dns_server "$config" "$tag" "$server_address" "$server_port" "$path" "$headers" \
            "$domain_resolver" "$detour")
        ;;
    *)
        log "Unsupported DNS server type: $type. Aborted." "fatal"
        exit 1
        ;;
    esac

    echo "$config"
}

sing_box_cf_add_mixed_inbound_and_route_rule() {
    local config="$1"
    local tag="$2"
    local listen_address="$3"
    local listen_port="$4"
    local outbound="$5"

    config=$(sing_box_cm_add_mixed_inbound "$config" "$tag" "$listen_address" "$listen_port")
    config=$(sing_box_cm_add_route_rule "$config" "" "$tag" "$outbound")

    echo "$config"
}

sing_box_cf_add_proxy_outbound() {
    local config="$1"
    local section="$2"
    local url="$3"
    local udp_over_tcp="$4"

    # A link with the xhttp transport is decoded by sing-box itself, before any
    # decoding here: its "extra" parameter is URL-encoded JSON
    case "$(url_get_scheme "$url")" in
    vless | trojan)
        case "$(url_get_query_param "$(url_strip_fragment "$url")" "type")" in
        xhttp | splithttp)
            _add_decoded_proxy_outbound "$config" "$section" "$url"
            return
            ;;
        esac
        ;;
    esac

    url=$(url_decode "$url")
    url=$(url_strip_fragment "$url")

    local scheme
    scheme="$(url_get_scheme "$url")"
    case "$scheme" in
    socks4 | socks4a | socks5)
        local tag host port version userinfo username password udp_over_tcp

        tag=$(get_outbound_tag_by_section "$section")
        host=$(url_get_host "$url")
        port=$(url_get_port "$url")
        version="${scheme#socks}"
        if [ "$scheme" = "socks5" ]; then
            userinfo=$(url_get_userinfo "$url")
            if [ -n "$userinfo" ]; then
                username="${userinfo%%:*}"
                password="${userinfo#*:}"
            fi
        fi
        config="$(sing_box_cm_add_socks_outbound \
            "$config" \
            "$tag" \
            "$host" \
            "$port" \
            "$version" \
            "$username" \
            "$password" \
            "" \
            "$([ "$udp_over_tcp" == "1" ] && echo 2)" # if udp_over_tcp is enabled, enable version 2
        )"
        ;;
    vless)
        local tag host port uuid flow packet_encoding
        tag=$(get_outbound_tag_by_section "$section")
        host=$(url_get_host "$url")
        port=$(url_get_port "$url")
        uuid=$(url_get_userinfo "$url")
        flow=$(url_get_query_param "$url" "flow")
        packet_encoding=$(url_get_query_param "$url" "packetEncoding")

        config=$(sing_box_cm_add_vless_outbound "$config" "$tag" "$host" "$port" "$uuid" "$flow" "" "$packet_encoding")
        config=$(_add_outbound_security "$config" "$tag" "$url")
        config=$(_add_outbound_transport "$config" "$tag" "$url")
        ;;
    ss)
        local userinfo tag host port method password udp_over_tcp

        userinfo=$(url_get_userinfo "$url")
        if ! is_shadowsocks_userinfo_format "$userinfo"; then
            userinfo=$(base64_decode "$userinfo")
            if [ $? -ne 0 ]; then
                log "Cannot decode shadowsocks userinfo or it does not match the expected format. Aborted." "fatal"
                exit 1
            fi
        fi

        tag=$(get_outbound_tag_by_section "$section")
        host=$(url_get_host "$url")
        port=$(url_get_port "$url")
        method="${userinfo%%:*}"
        password="${userinfo#*:}"

        config=$(
            sing_box_cm_add_shadowsocks_outbound \
                "$config" \
                "$tag" \
                "$host" \
                "$port" \
                "$method" \
                "$password" \
                "" \
                "$([ "$udp_over_tcp" == "1" ] && echo 2)" # if udp_over_tcp is enabled, enable version 2
        )
        ;;
    trojan)
        local tag host port password
        tag=$(get_outbound_tag_by_section "$section")
        host=$(url_get_host "$url")
        port=$(url_get_port "$url")
        password=$(url_get_userinfo "$url")

        config=$(sing_box_cm_add_trojan_outbound "$config" "$tag" "$host" "$port" "$password")
        config=$(_add_outbound_security "$config" "$tag" "$url")
        config=$(_add_outbound_transport "$config" "$tag" "$url")
        ;;
    hysteria2 | hy2)
        local tag host port password obfuscator_type obfuscator_password upload_mbps download_mbps
        tag=$(get_outbound_tag_by_section "$section")
        host=$(url_get_host "$url")
        port="$(url_get_port "$url")"
        password=$(url_get_userinfo "$url")
        obfuscator_type=$(url_get_query_param "$url" "obfs")
        obfuscator_password=$(url_get_query_param "$url" "obfs-password")
        upload_mbps=$(url_get_query_param "$url" "upmbps")
        download_mbps=$(url_get_query_param "$url" "downmbps")

        config=$(sing_box_cm_add_hysteria2_outbound "$config" "$tag" "$host" "$port" "$password" "$obfuscator_type" \
            "$obfuscator_password" "$upload_mbps" "$download_mbps")
        config=$(_add_outbound_security "$config" "$tag" "$url")
        ;;
    *)
        log "Unsupported proxy $scheme type. Aborted." "fatal"
        exit 1
        ;;
    esac

    echo "$config"
}

#######################################
# Add a proxy outbound decoded from the link by "sing-box tools decode-link".
# Arguments:
#   config: string (JSON), sing-box configuration to modify
#   section: string, the section the outbound tag is derived from
#   url: string, the link as written in the configuration (not URL-decoded)
# Outputs:
#   Writes updated JSON configuration to stdout
#######################################
_add_decoded_proxy_outbound() {
    local config="$1"
    local section="$2"
    local url="$3"

    if ! sing_box_has_feature "tools.decode-link"; then
        log "The xhttp transport is not supported by the installed sing-box (podkop-engine r11 or later is required). Aborted." "fatal"
        exit 1
    fi

    local tag outbound status messages message
    tag=$(get_outbound_tag_by_section "$section")
    messages="/tmp/podkop-decode-link.$$"
    outbound=$(sing-box tools decode-link --compact "$url" 2> "$messages")
    status=$?

    if [ "$status" -ne 0 ]; then
        log "Cannot use the proxy link of $section: $(head -n 1 "$messages"). Aborted." "fatal"
        rm -f "$messages"
        exit 1
    fi

    while read -r message; do
        [ -n "$message" ] && log "Proxy link of $section: $message" "warn"
    done < "$messages"
    rm -f "$messages"

    sing_box_cm_add_raw_outbound "$config" "$tag" "$outbound"
}

_add_outbound_security() {
    local config="$1"
    local outbound_tag="$2"
    local url="$3"

    local security scheme
    security=$(url_get_query_param "$url" "security")
    scheme="$(url_get_scheme "$url")"

    if [ -z "$security" ]; then
        if [ "$scheme" = "hysteria2" ] || [ "$scheme" = "hy2" ]; then
            security="tls"
        fi
    fi

    case "$security" in
    tls | reality)
        local sni insecure alpn fingerprint public_key short_id
        sni=$(url_get_query_param "$url" "sni")
        insecure=$(_get_insecure_query_param_from_url "$url")
        alpn=$(comma_string_to_json_array "$(url_get_query_param "$url" "alpn")")
        fingerprint=$(url_get_query_param "$url" "fp")
        public_key=$(url_get_query_param "$url" "pbk")
        short_id=$(url_get_query_param "$url" "sid")

        if [ "$scheme" = "hysteria2" ] || [ "$scheme" = "hy2" ]; then
                fingerprint=""
        fi

        config=$(
            sing_box_cm_set_tls_for_outbound \
                "$config" \
                "$outbound_tag" \
                "$sni" \
                "$([ "$insecure" == "1" ] && echo true)" \
                "$([ "$alpn" == "[]" ] && echo null || echo "$alpn")" \
                "$fingerprint" \
                "$public_key" \
                "$short_id"
        )
        ;;
    none) ;;
    *)
        log "Unknown security '$security' detected." "error"
        ;;
    esac

    echo "$config"
}

_get_insecure_query_param_from_url() {
    local url="$1"

    local insecure
    insecure=$(url_get_query_param "$url" "allowInsecure")
    if [ -z "$insecure" ]; then
        insecure=$(url_get_query_param "$url" "insecure")
    fi

    echo "$insecure"
}

_add_outbound_transport() {
    local config="$1"
    local outbound_tag="$2"
    local url="$3"

    local transport
    transport=$(url_get_query_param "$url" "type")
    case "$transport" in
    tcp | raw) ;;
    ws)
        local ws_path ws_host ws_early_data
        ws_path=$(url_get_query_param "$url" "path")
        ws_host=$(url_get_query_param "$url" "host")
        ws_early_data=$(url_get_query_param "$url" "ed")

        config=$(
            sing_box_cm_set_ws_transport_for_outbound "$config" "$outbound_tag" "$ws_path" "$ws_host" "$ws_early_data"
        )
        ;;
    grpc)
        # TODO(ampetelin): Add handling of optional gRPC parameters; example links are needed.
        local grpc_service_name
        grpc_service_name=$(url_get_query_param "$url" "serviceName")

        config=$(
            sing_box_cm_set_grpc_transport_for_outbound "$config" "$outbound_tag" "$grpc_service_name"
        )
        ;;
    *)
        log "Unknown transport '$transport' detected." "error"
        ;;
    esac

    echo "$config"
}

sing_box_cf_add_json_outbound() {
    local config="$1"
    local section="$2"
    local json_outbound="$3"

    local tag
    tag=$(get_outbound_tag_by_section "$section")

    config=$(sing_box_cm_add_raw_outbound "$config" "$tag" "$json_outbound")

    echo "$config"
}

sing_box_cf_add_interface_outbound() {
    local config="$1"
    local section="$2"
    local interface_name="$3"

    local tag
    tag=$(get_outbound_tag_by_section "$section")

    config=$(sing_box_cm_add_interface_outbound "$config" "$tag" "$interface_name")

    echo "$config"
}

sing_box_cf_proxy_domain() {
    local config="$1"
    local inbound="$2"
    local domain="$3"
    local outbound="$4"

    tag="$(gen_id)"
    config=$(sing_box_cm_add_route_rule "$config" "$tag" "$inbound" "$outbound")
    config=$(sing_box_cm_patch_route_rule "$config" "$tag" "domain" "$domain")

    echo "$config"
}

sing_box_cf_override_domain_port() {
    local config="$1"
    local domain="$2"
    local port="$3"

    tag="$(gen_id)"
    config=$(sing_box_cm_add_options_route_rule "$config" "$tag")
    config=$(sing_box_cm_patch_route_rule "$config" "$tag" "domain" "$domain")
    config=$(sing_box_cm_patch_route_rule "$config" "$tag" "override_port" "$port")

    echo "$config"
}

sing_box_cf_add_single_key_reject_rule() {
    local config="$1"
    local inbound="$2"
    local key="$3"
    local value="$4"

    tag="$(gen_id)"
    config=$(sing_box_cm_add_reject_route_rule "$config" "$tag" "$inbound")
    config=$(sing_box_cm_patch_route_rule "$config" "$tag" "$key" "$value")

    echo "$config"
}

###############################################################################
# Subscription batch support (ported from netshift)
###############################################################################

# Build a prepared subscription batch in a SINGLE jq pass.
# Filters out non-proxy types (selector, urltest, direct, dns, block), statically
# drops outbounds unsupported by the current sing-box build, assigns a unique tag
# to each outbound and records a human-readable display name.
# Arguments:
#   config: string (JSON), sing-box configuration the batch will be merged into
#   subscription_json_path: string, path to the downloaded subscription JSON file
#   include_keywords_json: string (JSON array), keep only nodes whose display name
#       contains at least one of these (OR). Empty array ([]) = keep all.
#   exclude_keywords_json: string (JSON array), drop any node whose display name
#       contains at least one of these (OR). Empty array ([]) = no exclusion.
# Outputs:
#   Writes a JSON object to stdout:
#     { outbounds: [ {type,...,tag} ... ], tags: [..], names: [..],
#       feeds: [..], count: <kept>, skipped: <statically dropped> }
sing_box_cf_prepare_subscription_batch() {
    local config="$1"
    local subscription_json_path="$2"
    local include_keywords_json="${3:-[]}"
    local exclude_keywords_json="${4:-[]}"
    local sing_box_extended="false"
    local reality_mlkem="false"
    local reality_mlkem_core="false"
    local param_filter="${SUBSCRIPTION_PARAM_FILTER:-}"

    [ -n "$include_keywords_json" ] || include_keywords_json="[]"
    [ -n "$exclude_keywords_json" ] || exclude_keywords_json="[]"
    [ -n "$param_filter" ] || param_filter="{}"

    is_sing_box_extended && sing_box_extended="true"
    [ "${NETSHIFT_REALITY_MLKEM:-0}" = "1" ] && reality_mlkem="true"
    if [ "$reality_mlkem" = "true" ] || _reality_mlkem_core_ok; then
        reality_mlkem_core="true"
    fi

    printf '%s' "$config" | jq -c \
        --slurpfile sub "$subscription_json_path" \
        --arg feed_key "$SUBSCRIPTION_FEED_MARKER_KEY" \
        --argjson extended "$sing_box_extended" \
        --argjson reality_mlkem "$reality_mlkem" \
        --argjson reality_mlkem_core "$reality_mlkem_core" \
        --argjson include_keywords "$include_keywords_json" \
        --argjson exclude_keywords "$exclude_keywords_json" \
        --argjson param_filter "$param_filter" '
        def ucfold:
          explode
          | map(
              if   (. >= 65   and . <= 90)   then . + 32
              elif (. >= 1040 and . <= 1071) then . + 32
              elif (. == 1025)               then 1105
              else . end)
          | implode;
        ([$include_keywords[]? | tostring | select(length > 0) | ucfold]) as $inc
        | ([$exclude_keywords[]? | tostring | select(length > 0) | ucfold]) as $exc
        | def name_passes_keywords($lc):
            (($inc | length) == 0 or any($inc[]; . as $kw | ($lc | index($kw)) != null))
            and (($exc | length) == 0 or all($exc[]; . as $kw | ($lc | index($kw)) == null));
        def node_protocol: (.type // "" | tostring | ascii_downcase);
        def node_security:
            if ((.tls | type) != "object") then "none"
            elif (((.tls.reality | type) == "object") and ((.tls.reality.enabled // false) == true)) then "reality"
            elif ((.tls.enabled // false) == true) then "tls"
            else "none" end;
        def node_transport: (if ((.transport | type) == "object") then (.transport.type // "tcp") else "tcp" end | tostring | ascii_downcase);
        def param_ok($kind; $value):
            (($param_filter.include[$kind] // []) as $inc
              | ($inc | length) == 0 or any($inc[]; . == $value))
            and (($param_filter.exclude[$kind] // []) as $exc
              | all($exc[]; . != $value));
        def passes_params:
            param_ok("protocols"; node_protocol)
            and param_ok("transports"; node_transport)
            and param_ok("security"; node_security);
        ([.outbounds[]?.tag // empty]) as $existing
        | [$sub[0].outbounds[]? | select(
            .type != "selector" and
            .type != "urltest" and
            .type != "direct" and
            .type != "dns" and
            .type != "block"
          )] as $all_candidates
        | [$all_candidates[]
            | . as $ob
            | (($ob.remark // $ob.tag // "") | tostring) as $name
            | select(name_passes_keywords($name | ucfold))
            | select($ob | passes_params)
          ] as $candidates
        | ($candidates | length) as $total
        | [ $candidates[]
            | . as $ob
            | (($ob.remark // $ob.tag // "") | tostring) as $name
            | if ($ob.type == "shadowsocks" and ($ob.tls.enabled == true)) then
                empty
              elif (($ob.transport.type // "") == "xhttp" and ($extended | not)) then
                empty
              else
                {ob: $ob, name: $name}
              end
          ] as $kept
        | reduce range(0; ($kept | length)) as $i (
            {used: ($existing | map({(.): true}) | add // {}), out: []};
            . as $state
            | $kept[$i] as $entry
            | ($entry.ob) as $ob
            | (($ob.tag // $ob.remark // "") | tostring) as $raw
            | (if ($raw | length) > 0 then $raw else ("server-" + (($i + 1) | tostring)) end) as $base
            | (
                if ($state.used[$base] | not) then $base
                else
                    (label $found
                        | (range(1; 1000001)
                            | ($base + "-" + (. | tostring)) as $cand
                            | if ($state.used[$cand] | not) then $cand, break $found else empty end))
                end
              ) as $tag
            | .used[$tag] = true
            | .out += [{
                tag: $tag,
                name: (if ($entry.name | length) > 0 then $entry.name else $tag end),
                feed: ($ob[$feed_key] // null),
                outbound: (
                    $ob | del(.tag) | del(.remark) | del(.[$feed_key]) | . + {tag: $tag}
                    | if ((.tls | type) == "object") and ((.tls.reality | type) == "object")
                      then (if $reality_mlkem_core
                                and ((.tls.reality.enabled // false) == true)
                                and (((.tls.utls | type) == "object") and ((.tls.utls.fingerprint // "") == "chrome"))
                            then (if (.tls.reality.support_x25519mlkem768 == false) then .
                                  elif ($reality_mlkem or (.tls.reality.support_x25519mlkem768 == true))
                                  then .tls.reality.support_x25519mlkem768 = true
                                  else del(.tls.reality.support_x25519mlkem768) end)
                              else del(.tls.reality.support_x25519mlkem768) end)
                      else . end
                )
              }]
          ) as $resolved
        | {
            outbounds: [$resolved.out[].outbound],
            tags: [$resolved.out[].tag],
            names: [$resolved.out[].name],
            feeds: [$resolved.out[].feed],
            count: ($resolved.out | length),
            skipped: ($total - ($resolved.out | length))
          }
    ' 2>/dev/null
}

# Try to append a slice of prepared outbounds to the config and validate it once
# with a single `sing-box check`.
sing_box_cf_try_subscription_batch() {
    local config="$1"
    local outbounds_json="$2"
    local updated_config validation_tmp

    SING_BOX_CF_TRY_CONFIG=""

    updated_config=$(printf '%s' "$config" | jq -c --argjson new "$outbounds_json" '.outbounds += $new' 2>/dev/null)
    if [ -z "$updated_config" ]; then
        return 1
    fi

    validation_tmp="$(mktemp)" || return 1
    sing_box_cm_save_config_to_file "$updated_config" "$validation_tmp"
    if ! sing_box_oneshot -c "$validation_tmp" check > /dev/null 2>&1; then
        rm -f "$validation_tmp"
        return 1
    fi
    rm -f "$validation_tmp"

    SING_BOX_CF_TRY_CONFIG="$updated_config"
    return 0
}

# Recursively validate a range of prepared outbounds, isolating and skipping the
# ones the current sing-box build rejects.
sing_box_cf_apply_subscription_range() {
    local start="$1"
    local count="$2"
    local slice

    [ "$count" -gt 0 ] || return 0

    slice=$(printf '%s' "$SING_BOX_CF_BATCH_OUTBOUNDS" |
        jq -c --argjson start "$start" --argjson count "$count" '.[$start:($start + $count)]' 2>/dev/null)
    if [ -z "$slice" ] || [ "$slice" = "[]" ]; then
        SING_BOX_CF_BATCH_SKIPPED=$((SING_BOX_CF_BATCH_SKIPPED + count))
        return 0
    fi

    if sing_box_cf_try_subscription_batch "$SING_BOX_CF_BATCH_CONFIG" "$slice"; then
        SING_BOX_CF_BATCH_CONFIG="$SING_BOX_CF_TRY_CONFIG"
        SING_BOX_CF_BATCH_KEPT=$((SING_BOX_CF_BATCH_KEPT + count))
        SING_BOX_CF_BATCH_KEPT_RANGES="$SING_BOX_CF_BATCH_KEPT_RANGES $start:$count"
        return 0
    fi

    if [ "$count" -eq 1 ]; then
        local display_name
        display_name=$(printf '%s' "$SING_BOX_CF_BATCH_NAMES" |
            jq -r --argjson start "$start" '.[$start] // "unknown"' 2>/dev/null)
        [ -n "$display_name" ] || display_name="unknown"
        log "Skip unsupported outbound for current sing-box: '$display_name'" "warn"
        SING_BOX_CF_BATCH_SKIPPED=$((SING_BOX_CF_BATCH_SKIPPED + 1))
        return 0
    fi

    if [ "$count" -le 8 ]; then
        local index=0
        while [ "$index" -lt "$count" ]; do
            sing_box_cf_apply_subscription_range $((start + index)) 1
            index=$((index + 1))
        done
        return 0
    fi

    local half rest
    half=$((count / 2))
    [ "$half" -gt 0 ] || half=1
    rest=$((count - half))
    sing_box_cf_apply_subscription_range "$start" "$half"
    sing_box_cf_apply_subscription_range $((start + half)) "$rest"
}

# Parse a sing-box subscription JSON and add all proxy outbounds to the configuration.
# Arguments:
#   config: string (JSON), sing-box configuration to modify
#   section: string, the UCI section name
#   subscription_json_path: string, path to the downloaded subscription JSON file
#   include_keywords_json: string (JSON array, optional), keyword whitelist (OR)
#   exclude_keywords_json: string (JSON array, optional), keyword blacklist (OR)
# Outputs:
#   Writes updated JSON configuration to stdout
#   Sets SUBSCRIPTION_OUTBOUND_TAGS, SUBSCRIPTION_OUTBOUND_TAGS_JSON,
#   SUBSCRIPTION_OUTBOUND_FEEDS_JSON, SUBSCRIPTION_OUTBOUND_NAMES
sing_box_cf_add_subscription_outbounds() {
    local config="$1"
    local section="$2"
    local subscription_json_path="$3"
    local include_keywords_json="${4:-[]}"
    local exclude_keywords_json="${5:-[]}"

    [ -n "$include_keywords_json" ] || include_keywords_json="[]"
    [ -n "$exclude_keywords_json" ] || exclude_keywords_json="[]"

    SUBSCRIPTION_OUTBOUND_TAGS=""
    SUBSCRIPTION_OUTBOUND_TAGS_JSON="[]"
    SUBSCRIPTION_OUTBOUND_FEEDS_JSON="[]"
    SUBSCRIPTION_OUTBOUND_NAMES=""
    SING_BOX_CF_LAST_CONFIG="$config"

    if [ ! -f "$subscription_json_path" ]; then
        log "Subscription JSON file not found: $subscription_json_path" "error"
        echo "$config"
        return 1
    fi

    local keyword_filter_active=0 filter_kind=""
    if [ "$include_keywords_json" != "[]" ] || [ "$exclude_keywords_json" != "[]" ]; then
        filter_kind="keyword"
    fi
    if [ -n "${SUBSCRIPTION_PARAM_FILTER:-}" ] && [ "$SUBSCRIPTION_PARAM_FILTER" != "{}" ]; then
        filter_kind="${filter_kind:+$filter_kind and }parameter"
    fi
    [ -z "$filter_kind" ] || keyword_filter_active=1

    local prepared
    prepared=$(sing_box_cf_prepare_subscription_batch "$config" "$subscription_json_path" \
        "$include_keywords_json" "$exclude_keywords_json")
    if [ -z "$prepared" ]; then
        log "Failed to parse subscription outbounds JSON" "error"
        echo "$config"
        return 1
    fi

    local candidate_total kept_count statically_skipped
    candidate_total=$(printf '%s' "$prepared" | jq -r '(.count // 0) + (.skipped // 0)' 2>/dev/null)
    kept_count=$(printf '%s' "$prepared" | jq -r '.count // 0' 2>/dev/null)
    statically_skipped=$(printf '%s' "$prepared" | jq -r '.skipped // 0' 2>/dev/null)

    if [ "$keyword_filter_active" -eq 1 ]; then
        local raw_candidate_total filtered_out
        raw_candidate_total=$(printf '%s' "$config" | jq -c \
            --slurpfile sub "$subscription_json_path" \
            '[$sub[0].outbounds[]? | select(.type != "selector" and .type != "urltest" and .type != "direct" and .type != "dns" and .type != "block")] | length' 2>/dev/null)
        [ -n "$raw_candidate_total" ] || raw_candidate_total=0
        filtered_out=$((raw_candidate_total - candidate_total))
        [ "$filtered_out" -ge 0 ] || filtered_out=0
        log "Subscription $filter_kind filter for section '$section': kept=$candidate_total, filtered_out=$filtered_out" "info"
    fi

    if [ -z "$candidate_total" ] || [ "$candidate_total" -eq 0 ]; then
        if [ "$keyword_filter_active" -eq 1 ]; then
            log "Subscription $filter_kind filter for section '$section' removed all nodes; using a temporary blocked outbound" "warn"
        fi
        log "No proxy outbounds found in subscription JSON" "error"
        echo "$config"
        return 1
    fi

    log "Found $candidate_total proxy outbounds in subscription" "info"

    if [ "${statically_skipped:-0}" -gt 0 ]; then
        log "Skip $statically_skipped subscription outbound(s) unsupported by current sing-box build" "warn"
    fi

    if [ -z "$kept_count" ] || [ "$kept_count" -eq 0 ]; then
        log "No supported proxy outbounds remained in subscription JSON" "error"
        echo "$config"
        return 1
    fi

    SING_BOX_CF_BATCH_CONFIG="$config"
    SING_BOX_CF_BATCH_OUTBOUNDS=$(printf '%s' "$prepared" | jq -c '.outbounds' 2>/dev/null)
    SING_BOX_CF_BATCH_NAMES=$(printf '%s' "$prepared" | jq -c '.names' 2>/dev/null)
    SING_BOX_CF_BATCH_KEPT=0
    SING_BOX_CF_BATCH_SKIPPED=0
    SING_BOX_CF_BATCH_KEPT_RANGES=""

    sing_box_cf_apply_subscription_range 0 "$kept_count"

    if [ "$SING_BOX_CF_BATCH_KEPT" -eq 0 ]; then
        log "No valid subscription outbounds remained after validation for section '$section'" "error"
        echo "$config"
        return 1
    fi

    config="$SING_BOX_CF_BATCH_CONFIG"

    if [ "$SING_BOX_CF_BATCH_SKIPPED" -gt 0 ]; then
        log "Skipped $SING_BOX_CF_BATCH_SKIPPED unsupported subscription outbound(s) during validation" "warn"
    fi

    local kept_ranges_json
    kept_ranges_json=$(
        printf '%s' "$SING_BOX_CF_BATCH_KEPT_RANGES" |
            tr ' ' '\n' |
            jq -R 'select(length > 0) | split(":") | {start: (.[0] | tonumber), count: (.[1] | tonumber)}' |
            jq -sc '.'
    )
    [ -n "$kept_ranges_json" ] || kept_ranges_json="[]"

    SUBSCRIPTION_OUTBOUND_TAGS_JSON=$(
        printf '%s' "$prepared" | jq -c --argjson ranges "$kept_ranges_json" \
            '[.tags as $t | $ranges[] | range(.start; .start + .count) | $t[.]]' 2>/dev/null
    )
    [ -n "$SUBSCRIPTION_OUTBOUND_TAGS_JSON" ] || SUBSCRIPTION_OUTBOUND_TAGS_JSON="[]"

    SUBSCRIPTION_OUTBOUND_FEEDS_JSON=$(
        printf '%s' "$prepared" | jq -c --argjson ranges "$kept_ranges_json" \
            '[.feeds as $f | $ranges[] | range(.start; .start + .count) | $f[.]]' 2>/dev/null
    )
    [ -n "$SUBSCRIPTION_OUTBOUND_FEEDS_JSON" ] || SUBSCRIPTION_OUTBOUND_FEEDS_JSON="[]"

    SUBSCRIPTION_OUTBOUND_TAGS=$(
        printf '%s' "$SUBSCRIPTION_OUTBOUND_TAGS_JSON" | jq -r 'join(",")' 2>/dev/null
    )

    SUBSCRIPTION_OUTBOUND_NAMES=$(
        printf '%s' "$prepared" | jq -r --argjson ranges "$kept_ranges_json" \
            '[.names as $n | $ranges[] | range(.start; .start + .count) | $n[.]] | join("\n")' 2>/dev/null
    )

    log "Added $SING_BOX_CF_BATCH_KEPT subscription outbounds for section '$section'" "info"
    SING_BOX_CF_LAST_CONFIG="$config"

    echo "$config"
}

# Whether the core knows the support_x25519mlkem768 field at all.
_reality_mlkem_core_ok() {
    [ "${NETSHIFT_REALITY_MLKEM_HINT_UNGATED:-0}" = "1" ] && return 0
    is_sing_box_extended_at_least "$SB_EXTENDED_REALITY_MLKEM_MIN"
}
