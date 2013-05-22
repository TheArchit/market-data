#!/bin/bash
#
# envdump.sh -- Geneos email agent
#
# $Version: 1.00.007
#
# $Requisites: Supporting AWK filter "sortattr.awk"
#
# TODO: * plain text variant for Supporworks ticket auto-raiser
#       * implement alert colours
#       * write alert history in xhtml to webserver location
#       * add date/time, SLA, response time, auto-raised fields

DEF_RCPT=( "address1@example.com" \
           "address2@example.com" \
           "address3@example.com" )

TRUE="0"  # <-- Do not change
FALSE="1" # <-- Do not change

# --- For production set all to "FALSE"

in_debug="${FALSE}"
in_dev="${FALSE}"
def_rcpt="${FALSE}"

# --- Do not change from this point below

function debug()    { return "${in_debug}" ; }
function in_dev()   { return "${in_dev}"   ; }
function def_rcpt() { return "${def_rcpt}" ; }

function _xhtml_doctype() { # called by: _docgen()

    cat <<EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
EOF

}

function _xhtml_head() { # called by: _docgen()

    cat <<EOF
    <head>
EOF

    while [ "${#}" -gt 0 ] ; do
        case "${1}" in
            "--title")
                cat <<EOF
        <title>"${2}"</title>
EOF
                shift 2
            ;;

            "--includecss")
                [ -f "${2}" ] || return 1
                cat <<EOF
        <link rel="stylesheet" type="text/css" href="${2}" />
EOF

                shift 2
            ;;

            "--embedcss")
                [ -f "${2}" ] || return 1
                cat <<EOF
        <style type="text/css">
$(cat "${2}")
        </style>
EOF

                shift 2
            ;;

            *)
                cat <<EOF
Usage: ${FUNCNAME} --title [title]
                   [ --embedcss | --includecss ] file.css
EOF
                return 1
            ;;
        esac
    done

    cat <<EOF
    </head>
EOF

}

function _xhtml_body() { # called by: _docgen()

    cat <<EOF
    <body>
EOF

}

function _thprint {

    local attr="${1}"
    local val="${2}"

    # format specifiers
    local th="<th>%s</th>\n"

    printf "<tr>\n"
    printf "${th}" "${attr}" "${val}"
    printf "</tr>\n"
}

function _xhtml_table() { # called by: _docgen()

    # creates a table and invokes specified
    # row generator program or function which
    # must be capable of producing well-formed
    # XHTML table rows and data

    local rowcmd=

    case "${1}" in
        "--trgen")
            rowcmd="${2}"
            shift 2
        ;;

        *)
            printf "%s\n" "Usage: ${FUNCNAME} --trgen \"row command\""
            return 1
        ;;
    esac

    [ -n "${rowcmd}" ] || return 1

    cat <<EOF
        <table id="attr_tbl">
        <!--Begin script generated rows-->
EOF

${rowcmd}

    cat <<EOF
        <!--End script generated rows-->
        </table>
EOF

}

function _xhtml_close() { # called by: _docgen()

    cat <<EOF
    </body>
</html>

EOF

}

function _tdprint() { # called by: _trprint()

    local attr="${1}"
    local val="${2}"

    [ -n "${val}" ] || val="<i>Undefined</i>"

    # format specifiers
    local td_val="<td class=\"val\">%s</td>\n"
    local td_attr="<td class=\"attr\">%s</td>\n"
    local td_warn="<td class=\"warn\">%s</td>\n"
    local td_crit="<td class=\"crit\">%s</td>\n"

    [ "${attr}" == "Severity" ] && [ "${val}" == "WARNING" ] && {
        printf "${td_attr}" "${attr}"
        printf "${td_warn}" "${val}"
        return 0
    }
    [ "${attr}" == "Severity" ] && [ "${val}" == "CRITICAL" ] && {
        printf "${td_attr}" "${attr}"
        printf "${td_crit}" "${val}"
        return 0
    }
        printf "${td_attr}" "${attr}"
        printf "${td_val}"  "${val}"
        return 0

}

function _trprint() { # called by: _getvars()

    local attr="${1%%=*}"
    local val="${1#*=}"

    printf "<tr>\n"
        _tdprint "${attr}" "${val}"
    printf "</tr>\n"

}

function _rowgen() { # called by: _xhtml_table

    # parses the shell environment and extracts
    # and sorts variables from Geneos
    # If a file is specified with the --infile
    # option, we use that for development when
    # $in_dev=TRUE

    local filter=
    local infile=
    local line=


    while [ "${#}" -gt 0 ] ; do
        case "${1}" in
            "--filter")
                filter="${2}"
                shift 2
            ;;

            "--infile")
                infile="${2}"
                shift 2
            ;;

            *)
                cat <<EOF
Usage: ${FUNCNAME} --filter [awkscript]"
                   --infile [envfile]"
EOF

                return 1
        esac
    done

    [ -f "${filter}" ] || return 1

    if in_dev ; then
        if [ ! -f "${infile}" ] ; then
            cat <<EOF
${FUNCNAME} --infile: "${infile}" does not exist
EOF
            return 1
        fi

        _thprint "Attribute:" "Value:"

        "${filter}" < "${infile}" | \
            while read line ; do
                _trprint "${line}"
            done
        return 0
    fi

    _thprint "Geneos Attribute:" "Value:"

    set | "${filter}" | \
        while read line ; do
            _trprint "${line}"
        done
    return 0

}

function _setdefaults() { # called by: _sendmail{} ; _docgen()

    # sets email subject defaults if undeclared
    # or null

    [[ $_SEVERITY ]]   || _SEVERITY="\$_SEVERITY"
    [[ $Service ]]     || Service="\$_Service"
    [[ $Environment ]] || Environment="\$_Environment"
    [[ $Component ]]   || Component="\$_Component"

}

function _mime_head() { # called by: _sendmail()

    local primary="${Primary}"

    [ "${primary}" == "Yes" ] && primary="Primary"

    cat <<EOF
To: ${1}
Subject: ${_SEVERITY}: ${Service}@${Environment} ${primary} ${Component}
Content-Type: text/html

EOF

}

function _docgen() { # called by: _sendmail()

    # this function pieces our final
    # XHTML document together

    local rundir="${0%/*}"
    local program=${0##*/}
    local program=${program%%.*}

    _xhtml_doctype

    if in_dev ; then
        _xhtml_head --title "Geneos Alert" \
                    --includecss "${PWD}/css/${program}.css"
    else
        _xhtml_head --title "Geneos Alert" \
                    --embedcss "${rundir}/css/${program}.css"
    fi

    _xhtml_body
    _xhtml_table --trgen "_rowgen --filter ${rundir}/sortattr.awk
                                  --infile ${rundir}/sampledata/dev_05"
    _xhtml_close

}

function _sendmail() { # called by: main()

    # pipes the output of our mail header
    # and XHTML generator functions to sendmail
    # for delivery

    local mailto="${BASH_ARGV[@]}"

    def_rcpt && mailto="${@}"

    _setdefaults

    if [ -n "${mailto}" ] ; then

        {
            _mime_head "${mailto}"
            _docgen

        } | /usr/sbin/sendmail -t

    return 0
    fi

    _docgen || return 1

}

function main() {

    # default action is to email Geneos
    # alerts. Any error handling occurs
    # recursively from this point below

    _sendmail "${DEF_RCPT[@]}"

    return "${?}"

}

function _do_debug() {

    local logfile=
    local rundir="${0%/*}"

    case "${1}" in
        "--log")
            logfile="${rundir}/${2}"
            shift 2
        ;;

        *)
            printf "%s" "Usage: ${FUNCNAME} --log [logfile]"
        ;;
    esac

    { set -x ; main ; set +x ; } > "${logfile}" 2>&1

    exit "${?}"

}

debug && _do_debug --log "sampledata/debug"

# Send Geneos email alerts. if recipients are ommited
# fail and print the generated XHTML that would have
# been otherwise sent
main || exit "${?}"
