#!/usr/local/bin/awk -f

# sortattr.awk -- Extracts and prints a sorted list of Geneos attributes
#                 when not null, empty or undefined
#
# $Version: 1.00.004
#
# Description: sortattr.awk was written as a supporting function
#              of envdump.sh

BEGIN {

    # Define all recognisable Geneos
    # attribute keys. This list must
    # be kept current. Priority decides
    # in which order are attributes sorted
    # in the final email

    # Priority: Geneos Attribute:
    # --------- -----------------
      key[10]  = "_SEVERITY"
      key[20]  = "Service"
      key[30]  = "Environment"
      key[40]  = "_REALHOSTID"
      key[50]  = "Primary"
      key[60]  = "Component"
      key[70]  = "_SAMPLER"
      key[72]  = "_daysleft:"
      key[73]  = "_expirydate:"
      key[79]  = "_expected:"
      key[80]  = "_filename:"
      key[81]  = "_filetype:"
      key[82]  = "_errortype:"
      key[110] = "_KBA_URLS"
      key[120] = "Comment"
    # --------- -----------------

    for (i in key) {
        i = (i + 0)
        if (i > max)
            max = i
        key[i] = humanise_key(key[i])
    }
}

function humanise_key(str) { # redefine Geneos attributes

     # Geneos Attribute:
     # -----------------
     (str == "_SEVERITY")   && str = "Severity:"
     (str == "Service")     && str = "Service:"
     (str == "Environment") && str = "Environment:"
     (str == "_REALHOSTID") && str = "Host Machine:"
     (str == "Primary")     && str = "Primary:"
     (str == "Component")   && str = "Component:"
     (str == "_SAMPLER")    && str = "Monitoring Task:"
     (str == "_expected:")  && str = "Expected Date/Time:"
     (str == "_filename:")  && str = "File Name:"
     (str == "_filetype:")  && str = "File Type:"
     (str == "_errortype:") && str = "Error Type:"
     (str == "_KBA_URLS")   && str = "Knowledge Base:"

     return str
}

{
    var = val = $0

    sub(/=.*$/,"",var)
    gsub(/[\[\]]|[\(\)]|[\{\}]/,"\\\\&",var)
    sub(var,"",val)

    var = humanise_key(var)

    env[var] = val
}

END {
    for (i in env) {
        for (j in key) {
            if (key[j] == i) {
                out[j] = (i env[i])
                break
            }
        }
    }

    for (i=0; i<=max; i++) {
        if (i in out)
            printf "%s\n", out[i]
    }
}
