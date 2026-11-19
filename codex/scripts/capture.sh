#!/bin/sh
# Artidex capture for Codex (off by default): after a ChatGPT Sites deploy, posts the site's address
# and title to Artidex, and nothing about the folder or the session. The Sites tool's name and result are not
# documented, so the settings below must be filled in from the probe before this can work.

# ---- Capture settings: fill in from the probe (plugin/README.md, "Verification sheet") ----------
capture_enabled=${ARTIDEX_CAPTURE_ENABLED:-0}
tool_name_pattern=${ARTIDEX_TOOL_NAME_PATTERN:-'^ARTIDEX_SET_AFTER_PROBE$'}
url_path=${ARTIDEX_URL_PATH:-tool_response.structuredContent.url}
title_path=${ARTIDEX_TITLE_PATH:-tool_response.structuredContent.title}
# ---- End of capture settings; hooks/capture.json carries the same tool name as its matcher ------

# The address is built in; ARTIDEX_DEV_URL points a development copy at a local site (README, "For developers").
base_url=${ARTIDEX_DEV_URL:-https://artidex.app}
base_url=${base_url%/}
token=${ARTIDEX_TOKEN:-}
# Which of Artidex's clients sends the request: shown on its Connect page, never what decides access.
version=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$(dirname "$(dirname "$0")")/plugin.json" 2>/dev/null | head -n 1)
client=${version:+codex-plugin/$version}

quit() {
    cat >/dev/null 2>&1
    exit 0
}

usable() {
    found=$(command -v "$1" 2>/dev/null) || return 1
    # Apple's /usr/bin stubs open an install dialog when the developer tools are missing.
    case $found in
        /usr/bin/python3 | /usr/bin/git) [ "$(uname)" != Darwin ] || xcode-select -p >/dev/null 2>&1 ;;
    esac
}

[ "$capture_enabled" = 1 ] || quit
[ -n "$token" ] || quit

# What the hook remembers between runs, and never the token: that Artidex refused the token entered (a checksum
# tells another token apart), and until when Artidex asked it to wait. While either holds, nothing is sent.
state_dir=${PLUGIN_DATA:-$HOME/.codex/artidex}
token_mark=$(printf '%s' "$token" | cksum 2>/dev/null | tr -cd '0-9')

remember() {
    (umask 077 && mkdir -p "$state_dir" && printf '%s\n' "$2" >"$state_dir/$1") 2>/dev/null
}

if [ -r "$state_dir/refused" ] && [ "$(cat "$state_dir/refused" 2>/dev/null)" = "$token_mark" ]; then
    quit
fi

# Each reducer prints nothing unless the tool matches and a *.chatgpt.site address is found at the
# configured path, else the allowlisted JSON body; only the site's origin is kept.
jq_program='
def at($path): getpath($path | split(".") | map(if test("^[0-9]+$") then tonumber else . end));
def s: if type == "string" then . else null end;
select((.tool_name | s // "") | test($tool_pattern))
| (try at($url_path) catch null | s // "") as $text
| ([$text | capture("https://(?<host>(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+chatgpt\\.site)(?![a-z0-9-]|\\.[a-z0-9])"; "i")][0].host) as $host
| select($host != null)
| {
    url: "https://\($host | ascii_downcase)",
    title: (try at($title_path) catch null | s)
  }
| with_entries(select(.value != null))
| tojson'

python_program='
import json, os, re, sys
e = json.load(sys.stdin.buffer)
def at(path):
    v = e
    for part in path.split("."):
        if isinstance(v, dict):
            v = v.get(part)
        elif isinstance(v, list) and part.isdigit() and int(part) < len(v):
            v = v[int(part)]
        else:
            return None
    return v
s = lambda v: v if isinstance(v, str) else None
tool = s(e.get("tool_name")) if isinstance(e, dict) else None
if tool is not None and re.search(os.environ["ARTIDEX_TOOL_PATTERN"], tool):
    m = re.search(r"https://((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+chatgpt\.site)(?![a-z0-9-]|\.[a-z0-9])", s(at(os.environ["ARTIDEX_URL_PATH"])) or "", re.I)
    if m:
        body = {
            "url": "https://" + m.group(1).lower(),
            "title": s(at(os.environ["ARTIDEX_TITLE_PATH"])),
        }
        body = {k: v for k, v in body.items() if v is not None}
        sys.stdout.buffer.write(json.dumps(body, separators=(",", ":")).encode("utf-8"))'

node_program='
const chunks = [];
process.stdin.on("data", (c) => chunks.push(c)).on("end", () => {
    const e = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    const at = (path) => path.split(".").reduce((v, part) => {
        if (Array.isArray(v)) return /^[0-9]+$/.test(part) ? v[Number(part)] : undefined;
        return v !== null && typeof v === "object" ? v[part] : undefined;
    }, e);
    const s = (v) => (typeof v === "string" ? v : undefined);
    const tool = e !== null && typeof e === "object" ? s(e.tool_name) : undefined;
    if (tool === undefined || !new RegExp(process.env.ARTIDEX_TOOL_PATTERN).test(tool)) return;
    const m = /https:\/\/((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+chatgpt\.site)(?![a-z0-9-]|\.[a-z0-9])/i.exec(s(at(process.env.ARTIDEX_URL_PATH)) || "");
    if (!m) return;
    const body = {
        url: "https://" + m[1].toLowerCase(),
        title: s(at(process.env.ARTIDEX_TITLE_PATH)),
    };
    process.stdout.write(JSON.stringify(body));
});'

tool=${ARTIDEX_JSON_TOOL:-}
if [ -z "$tool" ]; then
    for candidate in jq python3 node; do
        usable "$candidate" && tool=$candidate && break
    done
fi
usable "${tool:-none}" || quit

case $tool in
    jq) reduced=$(jq -r --arg tool_pattern "$tool_name_pattern" --arg url_path "$url_path" --arg title_path "$title_path" "$jq_program" 2>/dev/null) ;;
    python3) reduced=$(ARTIDEX_TOOL_PATTERN=$tool_name_pattern ARTIDEX_URL_PATH=$url_path ARTIDEX_TITLE_PATH=$title_path python3 -I -c "$python_program" 2>/dev/null) ;;
    node) reduced=$(ARTIDEX_TOOL_PATTERN=$tool_name_pattern ARTIDEX_URL_PATH=$url_path ARTIDEX_TITLE_PATH=$title_path node -e "$node_program" 2>/dev/null) ;;
    *) quit ;;
esac
[ -n "$reduced" ] || quit

newline='
'
body=$reduced
endpoint=$base_url/api/tools/v1/ingest/chatgpt/capture

# Extension point (docs/plan.md 11.1): print "<header>: <HMAC-SHA256 hex>" to send the account fingerprint.
# Empty on purpose: the only candidate source (app-server account/read) is not known to be acceptable to read.
account_fingerprint_header() {
    :
}
fingerprint=$(account_fingerprint_header)

# Artidex said "too many requests" and when to come back: not before.
wait_until=$(cat "$state_dir/wait-publish" 2>/dev/null)
case $wait_until in
    '' | *[!0-9]*) ;;
    *) [ "$(date +%s)" -ge "$wait_until" ] || exit 0 ;;
esac

if [ "${ARTIDEX_DRY_RUN:-}" = 1 ]; then
    printf '%s\nPOST %s\nX-Artidex-Client: %s\n' "$body" "$endpoint" "$client"
    exit 0
fi

usable curl || exit 0

curl_quote() {
    printf '%s' "$1" | tr -d '\r\n' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

config=$(printf 'url = "%s"\nheader = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\nheader = "Accept: application/json"\ndata-raw = "%s"' \
    "$(curl_quote "$endpoint")" "$(curl_quote "$token")" "$(curl_quote "$body")")
[ -z "$fingerprint" ] || config="$config${newline}header = \"$(curl_quote "$fingerprint")\""
[ -z "$client" ] || config="$config${newline}header = \"X-Artidex-Client: $(curl_quote "$client")\""

# curl reads the token and the body from a config on stdin, so neither appears in `ps`.
send() {
    response=$(printf '%s\n' "$config" | curl --config - --silent --include --max-time 2 --write-out '\n%{http_code}' 2>/dev/null)
    gave_up=$?
    status=${response##*"$newline"}
}

send

# A server error or no answer gets one more try a moment later, and no third; a request that already waited out its
# two seconds gets none. The next attempt is the person's next publish.
case $status in
    5[0-9][0-9] | 000 | '')
        if [ "$gave_up" != 28 ]; then
            sleep 1
            send
        fi
        ;;
esac

headers=$(printf '%s' "$response" | tr -d '\r' | sed -n '1,/^$/p')
answer=$(printf '%s' "${response%"$newline"*}" | tr -d '\r' | sed '1,/^$/d')

# Shown once, as one sentence: a refusal the person can act on. A refused token (401, 403) also stops the hook until
# another token is entered; "too many requests" stops it for as long as Artidex says; anything else stays silent.
case $status in
    2[0-9][0-9])
        rm -f "$state_dir/refused" "$state_dir/wait-publish" 2>/dev/null
        exit 0
        ;;
    401)
        remember refused "$token_mark"
        default=unauthorized
        ;;
    403)
        remember refused "$token_mark"
        default=forbidden
        ;;
    409) default= ;;
    429)
        retry_after=$(printf '%s\n' "$headers" | sed -n 's/^[Rr]etry-[Aa]fter:[[:space:]]*\([0-9][0-9]*\)[[:space:]]*$/\1/p' | head -n 1)
        case ${retry_after:-} in
            '' | ??????*) retry_after=60 ;;
        esac
        remember "wait-publish" "$(($(date +%s) + retry_after))"
        exit 0
        ;;
    *) exit 0 ;;
esac

stopped=
[ -z "$default" ] || stopped=' Nothing more is sent until another token is entered.'

fallbacks='{"other_account_linked":"Artidex recorded nothing: your Artidex account is linked to another ChatGPT account; unlink it in Artidex first.","switch_too_soon":"Artidex recorded nothing: your Artidex account switched ChatGPT accounts recently and cannot switch again yet.","wrong_provider":"Artidex recorded nothing: this access token was made for another tool; create a token for Codex in Artidex.","wrong_entry_point":"Artidex recorded nothing: this access token is not a Codex capture token; create one in Artidex under Connect, ChatGPT.","unauthorized":"Artidex recorded nothing: the access token was refused; it may have expired or been revoked. Create a new one in Artidex under Connect, ChatGPT, and export it as ARTIDEX_TOKEN.","forbidden":"Artidex recorded nothing: it refused this access token. Create a new one in Artidex under Connect, ChatGPT."}'

# The answer's own sentence when it names a refusal known here, else the sentence for `default`, else nothing.
# A token of the wrong kind gets the sentence written here, which says where to make the right one, and that page.
connect=$base_url/app/connect/chatgpt
refusal_jq='
def one_line: gsub("[\\s]+"; " ") | sub("^ "; "") | sub(" $"; "");
(try fromjson catch {}) | (if type == "object" then . else {} end) as $a
| (($a.code | type) == "string" and ($fallbacks | has($a.code))) as $known
| (if $known then $a.code else $default end) as $code
| select($code != "")
| ($code == "wrong_provider" or $code == "wrong_entry_point") as $own
| ((if $known and ($own | not) and ($a.message | type) == "string" then ($a.message | one_line) else "" end) as $m
    | if ($m | length) > 0 and ($m | length) <= 300 then $m else $fallbacks[$code] end) as $sentence
| ((if $known and ($a.url | type) == "string" then $a.url else "" end) as $u
    | if ($u | test("^https?://[^\\s]{1,500}$")) then $u elif $own then $connect else "" end) as $url
| {systemMessage: ((if $url == "" or ($sentence | contains($url)) then $sentence else "\($sentence) \($url)" end) + $stopped)}
| tojson'

refusal_python='
import json, os, re, sys
try:
    a = json.load(sys.stdin.buffer)
except ValueError:
    a = {}
a = a if isinstance(a, dict) else {}
fallbacks = json.loads(os.environ["ARTIDEX_FALLBACKS"])
known = isinstance(a.get("code"), str) and a["code"] in fallbacks
code = a["code"] if known else os.environ["ARTIDEX_DEFAULT"]
if code:
    own = code in ("wrong_provider", "wrong_entry_point")
    m = " ".join(a["message"].split()) if known and not own and isinstance(a.get("message"), str) else ""
    sentence = m if 0 < len(m) <= 300 else fallbacks[code]
    u = a.get("url") if known and isinstance(a.get("url"), str) else ""
    url = u if re.fullmatch(r"https?://\S{1,500}", u) else (os.environ["ARTIDEX_CONNECT"] if own else "")
    text = sentence if url == "" or url in sentence else sentence + " " + url
    sys.stdout.write(json.dumps({"systemMessage": text + os.environ["ARTIDEX_STOPPED"]}))'

refusal_node='
const chunks = [];
process.stdin.on("data", (c) => chunks.push(c)).on("end", () => {
    let a = {};
    try {
        a = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch {}
    if (a === null || typeof a !== "object" || Array.isArray(a)) a = {};
    const fallbacks = JSON.parse(process.env.ARTIDEX_FALLBACKS);
    const known = typeof a.code === "string" && Object.hasOwn(fallbacks, a.code);
    const code = known ? a.code : process.env.ARTIDEX_DEFAULT;
    if (!code) return;
    const own = code === "wrong_provider" || code === "wrong_entry_point";
    const m = known && !own && typeof a.message === "string" ? a.message.split(/\s+/).filter(Boolean).join(" ") : "";
    const sentence = m.length > 0 && m.length <= 300 ? m : fallbacks[code];
    const u = known && typeof a.url === "string" ? a.url : "";
    const url = /^https?:\/\/\S{1,500}$/.test(u) ? u : own ? process.env.ARTIDEX_CONNECT : "";
    process.stdout.write(JSON.stringify({ systemMessage: (url === "" || sentence.includes(url) ? sentence : sentence + " " + url) + process.env.ARTIDEX_STOPPED }));
});'

case $tool in
    jq) printf '%s' "$answer" | jq -Rrs --argjson fallbacks "$fallbacks" --arg default "$default" --arg stopped "$stopped" --arg connect "$connect" "$refusal_jq" 2>/dev/null ;;
    python3) printf '%s' "$answer" | ARTIDEX_FALLBACKS=$fallbacks ARTIDEX_DEFAULT=$default ARTIDEX_STOPPED=$stopped ARTIDEX_CONNECT=$connect python3 -I -c "$refusal_python" 2>/dev/null ;;
    node) printf '%s' "$answer" | ARTIDEX_FALLBACKS=$fallbacks ARTIDEX_DEFAULT=$default ARTIDEX_STOPPED=$stopped ARTIDEX_CONNECT=$connect node -e "$refusal_node" 2>/dev/null ;;
esac

exit 0
