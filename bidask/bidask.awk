#!/usr/local/bin/awk -f

#  bidask.awk -- measure Caplin's FeedHandler latency by timing how long it
#                takes to process incoming FX rates

BEGIN {

    # print heading
    heading = 1

    # formatting and precision
    fmt_round   = "%.4f"
    fmt_symbol  = "%-9s"
    fmt_stamp   = "%-25s"
    fmt_diff    = "%8s\n"
    fmt_latency = "%8.3f\n"

    if (heading == "1") {
        printf fmt_symbol, "Symbol:"
        printf fmt_stamp,  "In:"
        printf fmt_stamp,  "Out:"
        printf fmt_diff,   "Diff(ms):"
    }
}

# -- gettms converts Caplin timestamps to absolute UNIX milliseconds
function gettms(str,   a, res) {
    split(str, a, "[.:/-]")

    res = mktime(a[1]" "a[2]" "a[3]" "a[4]" "a[5]" "a[6])
    res = (res * 1000) + a[7]

    return res
}

($6 !~ /0(7|3)$/) { next }

($9 ~ /^\/I/ && $12 ~ /^DS/) {
    for (i = 12; i <= NF; i++) {
        if ($i ~ /^BID=/) {
            gsub(/(^\/I\/|=$)/,"", $9)
            ric = $9

            sub(/^BID=\+/,"", $i)
            bid = sprintf(fmt_round, $i)

            i++

            sub(/^ASK=\+/,"", $i)
            ask = sprintf(fmt_round, $i)

            ricbidask = (ric bid ask)
            incoming[ricbidask] = $1

            next
        }
    }
}

$9 ~ /^\/FX/ {
    sub(/^\/FX\/RDF\//, "", $9)
    sub(/^EqMajorValue=/, "", $12)
    sub(/^MajorValue=/, "", $13)

    fx    = $9
    eqmaj = sprintf(fmt_round, $12)
    maj   = sprintf(fmt_round, $13)

    outgoing = (fx eqmaj maj)

    if (outgoing in incoming) {

        out_time = gettms($1)
        in_time  = gettms(incoming[outgoing])
        latency  = (out_time - in_time) / 1000

        printf fmt_symbol,  fx
        printf fmt_stamp,   incoming[outgoing]
        printf fmt_stamp,   $1
        printf fmt_latency, latency

        delete incoming[outgoing]
    }
}
