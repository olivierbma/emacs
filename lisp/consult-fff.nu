# Persistent JSON-lines bridge to Nushell's FFF-backed idx commands.
# Use /dev/stdin rather than `nu --stdin`: the latter buffers before main.
def main [root: string] {
    cd $root
    try {
        idx init . --wait | ignore
        print ({ready: true} | to json --raw)
        open /dev/stdin --raw | lines | each { |line|
            let request = $line | from json
            try {
                if (($request | get --optional op) == "grep") {
                    let mode = $request | get --optional mode | default "plain"
                    let matches = if ($request.query | is-empty) {
                        []
                    } else {
                        match $mode {
                            "plain" => { idx search $request.query --limit $request.limit }
                            "regex" => { idx search --regex $request.query --limit $request.limit }
                            "fuzzy" => { idx search --fuzzy $request.query --limit $request.limit }
                            _ => { error make {msg: $"Unknown search mode: ($mode)"} }
                        }
                    }
                    print ({id: $request.id, matches: $matches} | to json --raw)
                } else {
                    let paths = idx find $request.query --files --limit $request.limit
                        | get relative_path
                    print ({id: $request.id, paths: $paths} | to json --raw)
                }
            } catch { |error|
                print ({id: $request.id, error: $error.msg} | to json --raw)
            }
        } | ignore
    } catch { |error|
        print ({error: $error.msg} | to json --raw)
        exit 1
    }
}
