#!/bin/sh
# What the Artidex plugin keeps on this machine: the project a folder is tied to and, as a fallback to the browser
# sign-in, an access token. Nothing here calls Artidex; the project's id and the token leave only as headers of the
# plugin's own connection. A token Artidex refused is not sent again until the person saves one again.
#   headers <data> <folder>     the connection's extra headers as JSON; Claude Code runs this when it connects
#   tie <data> <folder> <id>    what is published from this folder is filed in that project
#   untie <data> <folder>
#   tied <data> <folder>        prints the project's id, or nothing
#   token <data>                asks for a token in the terminal and keeps it; an empty answer removes it

command=${1:-}
data=${2:-}
folder=${3:-}

# A value that needs no escaping in JSON or in a header.
plain() {
    [ -n "$1" ] && [ -z "$(printf '%s' "$1" | tr -d "$2")" ]
}

# A folder is remembered by a checksum of its path, never by the path. A placeholder left unfilled is no folder.
key() {
    case $folder in
        '' | *'${'*) return 1 ;;
    esac
    sum=$(printf '%s' "$folder" | cksum 2>/dev/null | tr -cd '0-9')
    [ -n "$sum" ] && printf '%s' "$sum"
}

tied() {
    name=$(key) || return 0
    id=$(head -n 1 "$data/ties/$name" 2>/dev/null | tr -d '\r\n')
    if plain "$id" 'A-Za-z0-9_-'; then
        printf '%s' "$id"
    fi
}

case $data in
    '' | *'${'*) data= ;;
esac

keep() {
    (umask 077 && mkdir -p "$data" && printf '%s\n' "$2" >"$data/$1") 2>/dev/null
}

# The program that asked for the headers: the nearest ancestor that is no shell. Nothing where `ps` cannot tell.
caller() {
    pid=$PPID
    for step in 1 2 3; do
        set -- $(ps -o ppid= -o comm= -p "$pid" 2>/dev/null)
        if [ $# -lt 2 ]; then
            pid=
            break
        fi
        case ${2##*/} in
            sh | bash | dash | ash | zsh | -sh | -bash | -zsh) pid=$1 ;;
            *) break ;;
        esac
    done
    printf '%s' "${pid:--}"
}

# Claude Code runs the helper again when the server refuses its credential, so the same program asking again within
# this many seconds, for the same token, is that refusal. Only a checksum of the token is kept, never the token.
retry_window=30

refused() {
    [ "$(cat "$data/refused" 2>/dev/null)" != "$1" ] || return 0
    now=$(date +%s)
    who=$(caller)
    was_sum= was_who= was_at=
    [ ! -r "$data/offered" ] || read -r was_sum was_who was_at <"$data/offered"
    case $was_at in
        '' | *[!0-9]*) was_at=0 ;;
    esac
    if [ "$was_sum" = "$1" ] && [ "$was_who" = "$who" ] && [ $((now - was_at)) -lt "$retry_window" ]; then
        keep refused "$1"
        rm -f "$data/offered"
        return 0
    fi
    keep offered "$1 $who $now"
    return 1
}

case $command in
    headers)
        out=
        if [ -n "$data" ]; then
            project=$(tied)
            token=$(head -n 1 "$data/token" 2>/dev/null | tr -d '\r\n')
            [ -z "$project" ] || out="\"X-Artidex-Project\":\"$project\""
            if plain "$token" 'A-Za-z0-9._~+/=|-' && ! refused "$(printf '%s' "$token" | cksum 2>/dev/null | tr -cd '0-9')"; then
                out="${out:+$out,}\"Authorization\":\"Bearer $token\""
            fi
        fi
        printf '{%s}\n' "$out"
        ;;
    tie)
        id=${4:-}
        # A project is named by the short text `list-projects` gives (two letters, then letters and digits), never a number.
        if [ -z "$data" ] || ! name=$(key) || ! plain "$id" 'A-Za-z0-9' || [ ${#id} -gt 40 ] || plain "$id" '0-9'; then
            echo 'Nothing tied: the folder or the project id is missing. The id is the text list-projects gives.' >&2
            exit 1
        fi
        (umask 077 && mkdir -p "$data/ties" && printf '%s\n' "$id" >"$data/ties/$name") || exit 1
        rm -f "$data/offered"
        echo "Tied to project $id. It takes effect when the Artidex server reconnects."
        ;;
    untie)
        if [ -n "$data" ] && name=$(key); then
            rm -f "$data/ties/$name" "$data/offered"
        fi
        echo 'This folder is tied to no project.'
        ;;
    tied)
        [ -z "$data" ] || tied
        ;;
    token)
        # Only from a terminal of the person's own, so a token never passes through a session.
        if [ -z "$data" ] || ! [ -t 0 ]; then
            echo 'Run this in your own terminal, outside a Claude Code session.' >&2
            exit 1
        fi
        printf 'Paste the Artidex access token and press Enter (empty removes the saved one): ' >&2
        stty -echo 2>/dev/null
        IFS= read -r token
        stty echo 2>/dev/null
        printf '\n' >&2
        rm -f "$data/refused" "$data/offered"
        if [ -z "$token" ]; then
            rm -f "$data/token"
            echo 'No token is saved. The Artidex server signs in through the browser.'
        elif plain "$token" 'A-Za-z0-9._~+/=|-'; then
            (umask 077 && mkdir -p "$data" && printf '%s\n' "$token" >"$data/token") || exit 1
            echo 'Saved. Reconnect the Artidex server under /mcp, or start a new session.'
        else
            echo 'That is not an Artidex access token; nothing was saved.' >&2
            exit 1
        fi
        ;;
    *)
        exit 1
        ;;
esac
