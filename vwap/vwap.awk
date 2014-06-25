#!/usr/bin/awk -f

function calc_vwap()
{
    for (i=1; i<=idx; i++)
    {
        split(arr[i], data, ",")

        symbol  = data[1]
        qty     = data[2]
        price   = data[3]

        value[symbol] += (qty * price)
        volume[symbol] += qty
    }

    for (i in value)
    {
        vwap = sprintf("%.2f", (value[i] / volume[i]))
        print ("VWAP," o_day "," i "," volume[i] "," vwap)
    }

    idx = 0

    delete arr
    delete value
    delete volume
}

function f_exists(path,    cmd, ret)
{
    cmd = ("[ -r " path " ]")
    ret = system(cmd)
    close(cmd)
    return ret
}

BEGIN \
{
    if ((ARGC) < 1) exit 1

    for (f=1; f<ARGC; f++)
    {
        if ((ARGV[f] != "-" && f_exists(ARGV[f]) > 0))
        {
            printf "%s\n", ("vwap.awk: " ARGV[f] " - no such file") > \
                   "/dev/stderr"
            continue
        }

        while (getline < ARGV[f])
        {
            if (++line_c < 2) continue

            day = $1
            if (o_day && o_day != day) calc_vwap()

            o_day = day
            arr[++idx] = ($2 "," $3 "," $4)

            print ("TICK," day "," arr[idx])
        }

        calc_vwap()
        line_c = 0
        close(ARGV[f])
    }
}
