function valid_port(value) {
    if (value !~ /^[1-9][0-9]*$/ || length(value) > 5) return 0
    return value + 0 <= 65535
}

function valid_dns_name(value, labels, count, part) {
    if (value !~ /^[A-Za-z0-9.-]+$/ || value ~ /\.\./ || value ~ /^\./ || value ~ /\.$/) return 0
    count = split(value, labels, ".")
    for (part = 1; part <= count; part++) {
        if (labels[part] == "" || length(labels[part]) > 63 || labels[part] ~ /^-/ || labels[part] ~ /-$/) return 0
    }
    if (value ~ /^[0-9.]+$/) {
        if (count != 4) return 0
        for (part = 1; part <= count; part++) {
            if (labels[part] !~ /^[0-9][0-9]?[0-9]?$/ || labels[part] + 0 > 255) return 0
        }
    }
    return 1
}

{
    url = $0
    if (url ~ /[[:space:]?#@]/) exit 1

    if (tolower(substr(url, 1, 8)) == "https://") {
        scheme = "https"
        url = substr(url, 9)
        default_port = 443
    } else if (tolower(substr(url, 1, 7)) == "http://") {
        scheme = "http"
        url = substr(url, 8)
        default_port = 80
    } else {
        exit 1
    }

    sub(/\/$/, "", url)
    if (url == "" || url ~ /\//) exit 1
    count = split(url, pieces, ":")
    if (count > 2) exit 1
    host = pieces[1]
    if (!valid_dns_name(host)) exit 1
    port = count == 2 ? pieces[2] : default_port
    if (!valid_port(port)) exit 1
    if (host == "0.0.0.0") exit 1

    printf "%s|%s|%d\n", scheme, host, port + 0
}
