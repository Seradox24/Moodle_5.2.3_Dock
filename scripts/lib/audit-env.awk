function contains(item, csv, entries, count, idx) {
    count = split(csv, entries, ",")
    for (idx = 1; idx <= count; idx++) {
        if (tolower(entries[idx]) == tolower(item)) return 1
    }
    return 0
}

{
    line = $0
    sub(/\r$/, "", line)
    if (NR == 1) sub(/^\357\273\277/, "", line)
    if (line ~ /^[[:space:]]*(#|$)/) next

    sub(/^[[:space:]]*export[[:space:]]+/, "", line)
    if (!match(line, /^[A-Za-z_][A-Za-z0-9_]*([[:space:]]*=|[[:space:]]*$)/)) next

    key = substr(line, RSTART, RLENGTH)
    sub(/[[:space:]]*=.*/, "", key)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)

    normalized_key = tolower(key)
    if (++seen[normalized_key] == 2) print "DUPLICATE|" key
    if (contains(key, forbidden)) print "FORBIDDEN|" key
    else if (contains(key, obsolete)) print "OBSOLETE|" key
    else if (!contains(key, known)) print "UNKNOWN|" key
}
