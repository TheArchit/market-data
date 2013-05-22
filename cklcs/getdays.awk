#!/usr/local/bin/awk -f

# getdays.awk -- Caplin and SSL certificates license expiry tracker
#
# Usage:
#
#   getdays.awk < caplin-lic1.conf sslcert.crt caplin-lic[n].conf...
#   ./getdays.awk caplin-lic1.conf sslcert.crt caplin-lic[n].conf...
#   awk -f getdays.awk caplin-lic1.conf sslcert.crt caplin-lic[n].conf...
#   cat caplin-lic1.conf sslcert.crt caplin-lic[n].conf... | ./getdays.awk
#

BEGIN {

    now = systime()

    monthname[1]  = "Jan"
    monthname[2]  = "Feb"
    monthname[3]  = "Mar"
    monthname[4]  = "Apr"
    monthname[5]  = "May"
    monthname[6]  = "Jun"
    monthname[7]  = "Jul"
    monthname[8]  = "Aug"
    monthname[9]  = "Sep"
    monthname[10] = "Oct"
    monthname[11] = "Nov"
    monthname[12] = "Dec"

    print "component:,daysleft:,expirydate:"
}

# process caplin licenses
/^start-license/,/^end-license/ {
    if ($1 == "product-name")
        component = $2

    if ($1 == "expire") {
        str = $2

        # break down caplin expiry date string and
        # convert it to UNIX time
        y = substr(str,1,4)
        m = substr(str,5,2)
        d = substr(str,7,2)
        l = (substr(str,9) * 24 * 60 * 60)

        # add the number of days left (in seconds)
        expiry = (mktime(y" "m" "d" 00 00 00") + l)
        date   = strftime("%Y-%m-%d",expiry)

        secsleft = ((expiry - now) / 60 / 60 / 24)
        daysleft = sprintf("%d",secsleft)

        print component","daysleft","date
    }
}

# process .crt certificates
/^[ \t]+Not After[ \t]+:/ {

    component = "ssl_cert"
    day = $5

    for (i in monthname) {
        if ($4 == monthname[i]) {
            month = sprintf("%.2d", i)
        }
    }

    split($6,time,":")

    expiry = mktime($7" "month" "day" "time[1]" "time[2]" "time[3])

    date   = strftime("%Y-%m-%d", expiry)

    secsleft = ((expiry - now) / 60 / 60 / 24)
    daysleft = sprintf("%d", secsleft)

    print component","daysleft","date
}
