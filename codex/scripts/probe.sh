#!/bin/sh
# Artidex probe for Codex: appends one line per tool call to a local log with the tool name, the key
# names of its input and result, and the scheme, host and first path word of any web address in
# them. Never values, titles, prompts, file contents, queries or full paths. Sends nothing; exits 0.

log=${ARTIDEX_PROBE_LOG:-$HOME/.codex/artidex-probe.log}
max_bytes=1048576

quit() {
    cat >/dev/null 2>&1
    exit 0
}

usable() {
    found=$(command -v "$1" 2>/dev/null) || return 1
    # Apple's /usr/bin stubs open an install dialog when the developer tools are missing.
    case $found in
        /usr/bin/python3) [ "$(uname)" != Darwin ] || xcode-select -p >/dev/null 2>&1 ;;
    esac
}

if [ -f "$log" ] && [ "$(wc -c <"$log" | tr -d ' ')" -ge "$max_bytes" ]; then
    quit
fi

jq_program='
def word: if type == "string" and test("^[A-Za-z_][A-Za-z0-9_-]{0,40}$") then . else "*" end;
def segment: if type == "number" then tostring else word end;
def keys_of: if type == "object" then [keys[] | word] else null end;
def address:
  capture("^(?<scheme>https?)://(?:[^/?#@\\s]*@)?(?<host>[A-Za-z0-9.-]+)(?::[0-9]+)?(?<first>/[^/?#\\s]*)?")
  | "\(.scheme | ascii_downcase)://\(.host | ascii_downcase)"
    + (if (.first // "/") == "/" then "" elif (.first | test("^/[A-Za-z_-]{1,16}$")) then .first else "/*" end);
def urls($root; $name):
  [$root | path(.. | select(type == "string")) as $p
    | ($root | getpath($p)) as $text
    | [$text | scan("https?://[^\\s\"'"'"'<>()\\[\\]{}]+")][:5][]
    | {in: ([$name] + [$p[] | segment] | join(".")), url: address, whole: (. == $text)}];
{
  at: (now | todate),
  event: (.hook_event_name | word),
  tool_name: (.tool_name | if type == "string" and test("^[A-Za-z0-9_.:-]{1,128}$") then . else "*" end),
  tool_input_type: (.tool_input | type),
  tool_input_keys: (.tool_input | keys_of),
  tool_response_type: (.tool_response | type),
  tool_response_keys: (.tool_response | keys_of),
  urls: ((urls(.tool_input; "tool_input") + urls(.tool_response; "tool_response")) | unique | .[:50])
}
| tojson'

python_program='
import json, re, sys, datetime
e = json.load(sys.stdin.buffer)
if not isinstance(e, dict):
    sys.exit(0)
word = lambda v: v if isinstance(v, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]{0,40}", v) else "*"
label = lambda v: str(v) if isinstance(v, int) else word(v)
def kind(v):
    if v is None: return "null"
    if isinstance(v, bool): return "boolean"
    if isinstance(v, (int, float)): return "number"
    if isinstance(v, str): return "string"
    if isinstance(v, list): return "array"
    return "object"
keys_of = lambda v: sorted(word(k) for k in v) if isinstance(v, dict) else None
def address(u):
    m = re.match(r"(https?)://(?:[^/?#@\s]*@)?([A-Za-z0-9.-]+)(?::[0-9]+)?(/[^/?#\s]*)?", u)
    if not m:
        return None
    first = m.group(3) or "/"
    tail = "" if first == "/" else first if re.fullmatch(r"/[A-Za-z_-]{1,16}", first) else "/*"
    return m.group(1).lower() + "://" + m.group(2).lower() + tail
def strings(v, path):
    if isinstance(v, str):
        yield path, v
    elif isinstance(v, dict):
        for k, x in v.items():
            yield from strings(x, path + [label(k)])
    elif isinstance(v, list):
        for i, x in enumerate(v):
            yield from strings(x, path + [label(i)])
found = []
for name in ("tool_input", "tool_response"):
    for path, text in strings(e.get(name), [name]):
        for u in re.findall(r"https?://[^\s\"\x27<>()\[\]{}]+", text)[:5]:
            item = {"in": ".".join(path), "url": address(u), "whole": u == text}
            if item["url"] and item not in found:
                found.append(item)
found.sort(key=lambda i: json.dumps(i, sort_keys=True))
tool = e.get("tool_name")
line = {
    "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "event": word(e.get("hook_event_name")),
    "tool_name": tool if isinstance(tool, str) and re.fullmatch(r"[A-Za-z0-9_.:-]{1,128}", tool) else "*",
    "tool_input_type": kind(e.get("tool_input")),
    "tool_input_keys": keys_of(e.get("tool_input")),
    "tool_response_type": kind(e.get("tool_response")),
    "tool_response_keys": keys_of(e.get("tool_response")),
    "urls": found[:50],
}
sys.stdout.write(json.dumps(line, separators=(",", ":")))'

node_program='
const chunks = [];
process.stdin.on("data", (c) => chunks.push(c)).on("end", () => {
    const e = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (e === null || typeof e !== "object" || Array.isArray(e)) return;
    const word = (v) => (typeof v === "string" && /^[A-Za-z_][A-Za-z0-9_-]{0,40}$/.test(v) ? v : "*");
    const label = (v) => (typeof v === "number" ? String(v) : word(v));
    const kind = (v) => (v === null || v === undefined ? "null" : Array.isArray(v) ? "array" : typeof v);
    const keysOf = (v) => (kind(v) === "object" ? Object.keys(v).map(word).sort() : null);
    const address = (u) => {
        const m = /^(https?):\/\/(?:[^/?#@\s]*@)?([A-Za-z0-9.-]+)(?::[0-9]+)?(\/[^/?#\s]*)?/.exec(u);
        if (!m) return null;
        const first = m[3] || "/";
        const tail = first === "/" ? "" : /^\/[A-Za-z_-]{1,16}$/.test(first) ? first : "/*";
        return m[1].toLowerCase() + "://" + m[2].toLowerCase() + tail;
    };
    const found = [];
    const walk = (v, path) => {
        if (typeof v === "string") {
            for (const u of (v.match(/https?:\/\/[^\s"\x27<>()\[\]{}]+/g) || []).slice(0, 5)) {
                const item = { in: path.join("."), url: address(u), whole: u === v };
                if (item.url && !found.some((f) => JSON.stringify(f) === JSON.stringify(item))) found.push(item);
            }
        } else if (Array.isArray(v)) {
            v.forEach((x, i) => walk(x, [...path, label(i)]));
        } else if (v !== null && typeof v === "object") {
            for (const [k, x] of Object.entries(v)) walk(x, [...path, label(k)]);
        }
    };
    walk(e.tool_input, ["tool_input"]);
    walk(e.tool_response, ["tool_response"]);
    found.sort((a, b) => (JSON.stringify(a) < JSON.stringify(b) ? -1 : 1));
    const tool = e.tool_name;
    process.stdout.write(JSON.stringify({
        at: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"),
        event: word(e.hook_event_name),
        tool_name: typeof tool === "string" && /^[A-Za-z0-9_.:-]{1,128}$/.test(tool) ? tool : "*",
        tool_input_type: kind(e.tool_input),
        tool_input_keys: keysOf(e.tool_input),
        tool_response_type: kind(e.tool_response),
        tool_response_keys: keysOf(e.tool_response),
        urls: found.slice(0, 50),
    }));
});'

tool=${ARTIDEX_JSON_TOOL:-}
if [ -z "$tool" ]; then
    for candidate in jq python3 node; do
        usable "$candidate" && tool=$candidate && break
    done
fi
usable "${tool:-none}" || quit

case $tool in
    jq) line=$(jq -r "$jq_program" 2>/dev/null) ;;
    python3) line=$(python3 -I -c "$python_program" 2>/dev/null) ;;
    node) line=$(node -e "$node_program" 2>/dev/null) ;;
    *) quit ;;
esac
[ -n "$line" ] || exit 0

mkdir -p "$(dirname "$log")" 2>/dev/null
printf '%s\n' "$line" >>"$log" 2>/dev/null
exit 0
