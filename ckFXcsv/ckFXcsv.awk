#!/usr/bin/awk -f
#
# ckFXcsv.awk:
# -----------
#
# Description:  This tool validates Caplin ProductGenerator product files
# ensuring that theyhave been produced, contain a header, footer and data.
# Otherwise an error code is printed. Output type: csv on stdout suitable for
# Geneos monitoring.
#
# Geneos env keys:  When run from Geneos, the following table is printed:
#
# _#, _expected:, _filename:, _filetype:, _errortype:
#
# Requires: access to the Caplin ProductGenerator "ProductSchedule.xml"
# configuration file

# unregex() -- Escape special chars from given string
function unregex(str,   special,chars,source,i,j,c) {

    special = "\\:;_,<>%#@!&='`´^$+.*()[]{}?|-/"

    split(special,chars,"")
    special= ""

    for (i in chars) {
        j = chars[i]
        chars[j] ; delete chars[i]
    }

    split(str,source,"")
    str = ""

    for (i in source)
        c++

    for (i=0; i<=c; i++) {
        if (source[i] in chars)
            source[i] = ("\\" source [i])
        str = (str source[i])
    }

    return str
}

# jtosnap() -- Java's $Date() function wrapper in AWK.
#              usage: jtosnap("$Date(javamask)",unixtime)"
function jtosnap(str,nixtime,
            strfdate,jdate,jmask,i,arr,j,n,mask,ftime) {

    # translate Java timestamp masks to C-style format specifiers
    strfdate["yyyy"] = strftime("%Y",nixtime) # four digits of year (00..99)
    strfdate["yy"]   = strftime("%y",nixtime) # two digits of year (00..99)
    strfdate["MM"]   = strftime("%m",nixtime) # month (01..12)
    strfdate["dd"]   = strftime("%d",nixtime) # day of month (e.g, 01)
    strfdate["HH"]   = strftime("%H",nixtime) # hour (00..23)
    strfdate["mm"]   = strftime("%M",nixtime) # minute (00..59)
    strfdate["ss"]   = strftime("%S",nixtime) # second (00..59)

    if (match(str,/\$Date\([^)]+\)/) < 1)
        return 0

    jdate = jmask = substr(str,RSTART,RLENGTH)

    gsub(/\$Date\(|\)$/,"",jmask)

    # separate time masks from other chars
    split(jmask,arr,"")

    n = i = 0
    while (i<=length(jmask)) {
        j = (i - 1)
        if (arr[j] && arr[j] != arr[i]) {
            n++
        }
        mask[n] = (mask[n] arr[i])
        i++
    }

    # convert time mask to current time
    for (i=0; i<=n; i++) {
        for (j in strfdate)
            if (mask[i] == j)
                mask[i] = strfdate[j]
        ftime = (ftime mask[i])
    }

    jdate = unregex(jdate)
    sub(jdate,ftime,str)

    return str
}

function logerr(errtype,    fmt_err) { # global function

    # track error count
    ERR_C++

    # define error codes:
    ERR[1] = "NOT_PRODUCED"
    ERR[2] = "BAD_HEADER"
    ERR[3] = "NO_DATA"
    ERR[4] = "BAD_DATA_FIELD_COUNT"
    ERR[5] = "DDS_XFER_FAIL"
    ERR[6] = "DDS_NOT_DELIVERED"

    fmt_err = "%s,%s,%s,%s,%s\n"
    expect = strftime("%F @%R",now)

    printf fmt_err, ERR_C, expect, fname, type, ERR[errtype]
}

BEGIN {

    now = systime()

    prodgenroot = "prodgen/"

    # Comment the following three lines for production:
    # prodgenroot = "prodgen_test/"
    # controldate = "2012 06 29 21 59 00"
    # now = mktime(controldate)

    mastercfg  = (prodgenroot "conf/productgenerator/ProductSchedule.xml")

    # The snap delay and eod delay provide a global mechanism
    # to accommodate extra time for file generation by a factor of
    # n * 15 minutes.

    snap_delay = -1      # Adjust SNAP delay factor +/-x
    eod_delay = 3        # Adjust EOD check delay factor
    eodsnap = "21 00 00" # Set the EOD snap time: HH MM SS

    # -- end of user config

    print "#,expected:,filename:,filetype:,errortype:"

    FS = "\""

    # Reset current minute to nearest previous quarter of an hour
    # starting at 00, 15 or 45:
    i = 60
    while (i <= 60) {
        i -= 15
        if (i <= strftime("%M",now)) {
            snapmin = sprintf("%.2d",i)
            break
        }
    }

    # Product scheduling:
    f = ("%Y %m %d %H " snapmin " 00")
    snaptime = mktime(strftime(f,now)) + snap_delay * 15 * 60
    eodtime  = mktime(strftime("%Y %m %d " eodsnap,now))
    eodcheck = eodtime + (eod_delay + snap_delay) * 15 * 60

    weekday = strftime("%w",snaptime)

    # SNAP file period:
    # Every 15 minutes between Sunday after 21:15 and
    # Friday 21:00
    if (!(weekday == 5 && snaptime > eodtime  ||
            weekday == 0 && snaptime <= eodtime ||
            weekday == 6)) {
            prefix["FXS"] = "SNAP"
    }

    # Do EOD checks except Saturday and Sunday:
    if (snaptime == eodcheck && weekday != 6 && weekday != 0)
            prefix["FXH"] = "EOD"

    # Read ProductSchedule.xml:
    while ((getline < mastercfg) > 0) {
        if ($1 ~ /<[ \t]*ProductFile\ Name=/) {
            pdtcfg = (prodgenroot $2)
            gsub(/.*\/|\..*$/,"",$2)
            productdefs[$2]
        }
        if ($1 ~ /<[ \t]*Output\ FileName=/) {
            split($2,field,/[$]/)
            sub(/.*\//,"",field[1])

            pdtname = field[1]

            # work out product type
            for (i in prefix) {
                regex = ("^" i)
                type = "UNKNOWN"
                if (pdtname ~ regex) {
                    type = prefix[i]
                    break
                }
            }

            if (type == "EOD") {
                $2 = jtosnap($2,eodtime)
            } else if (type == "SNAP") {
                $2 = jtosnap($2,snaptime)
            } else {
                continue
            }

            fname = outfile = (prodgenroot $2)
            sub(/^.*\//,"",fname)

            # check if file is in filesystem
            ckfs = ("[ -f " outfile " ]")
            if ((system(ckfs)) > 0) {
                logerr("1")
                continue
            }

            # product file integrity checks:
            if (pdtname in productdefs) {
                # read product file configuration
                while ((getline < pdtcfg) > 0) {
                    # consecutive <TextRow> entries before
                    # any <Field Name> define our heading
                    if (! headpos && /<TextRow.?>/) {
                        lno++ ; continue
                    }
                    if ($1 ~ /Name=/) {
                        (! headpos) && headpos = (lno + 1)
                        # construct the heading string
                        for (i=1; i<=NF; i++) {
                            if ($i ~ /Header=/) {
                                cols = sprintf("%s%s%s",cols,sep,$(i+1))
                                sep = ","
                            }
                        }
                    }
                    # save footer string
                    if (/<TextRow>X+<\/TextRow>/) {
                        match($0,/X+/)
                        footer = substr($0,RSTART,RLENGTH)
                        continue
                    }
                }
                # end of product file configuration
                close(pdtcfg)

                productdefs[pdtname] = (cols)

                sep = ""
                cols = ""

                # validate generated product
                pos = 0
                while ((getline < outfile) > 0) {
                    pos++
                    # check heading
                    if (pos == headpos &&
                          productdefs[pdtname] != $0) {
                        logerr("2")
                        continue
                    }

                    if (pos - headpos == 1 && $0 == footer) {
                        logerr("3")
                        break
                    }
                }

                close(outfile)

            }
        }
    }

    close(mastercfg)

    if (! ERR_C)
        printf "%s\n", "-,-,-,-,ALL_OK"
}
