# copied verbatim from the Tcl'ers Wiki, http://mini.net/tcl/2879

# autoproxy.tcl - Copyright (C) 2002 Pat Thoyts <Pat.Thoyts@bigfoot.com>
#
# On Unix an emerging standard for identifying the local HTTP proxy server
# seems to be to use the environment variable http_proxy or ftp_proxy and
# no_proxy to list those domains to be excluded from proxying.
#
# On Windows we can retrieve the Internet Settings values from the registry
# to obtain pretty much the same information.
#
# With this information we can setup a suitable filter procedure for the
# Tcl http package and arrange for automatic use of the proxy.
#
# @(#)$Id: autoproxy.tcl 1097 2006-01-12 09:00:23Z jcw $

namespace eval autoproxy {
    variable proxy
    variable no_proxy {}

    array set proxy {host "" port 80}

    variable winregkey
    set winregkey [join {
	HKEY_CURRENT_USER
	Software Microsoft Windows
	CurrentVersion "Internet Settings"
    } \\]
}

proc autoproxy::init {} {
    package require uri
    global tcl_platform
    global env
    variable winregkey
    variable proxy
    variable no_proxy
    set httpproxy {}

    # Look for environment variables.
    if {[info exists env(http_proxy)]} {
	set httpproxy $env(http_proxy)
	catch { set no_proxy $env(no_proxy) }
    } else {
	if {$tcl_platform(platform) == "windows"} {
	    #puts "b"
	    package require registry 1.0

	    if {[registry get $winregkey "ProxyEnable"] eq "1"} {
		set httpproxy [registry get $winregkey "ProxyServer"]
		catch { set no_proxy [registry get $winregkey "ProxyOverride"] }
	    }
	}
    }

    # If we found something ...
    if {$httpproxy != {}} {
	# The http_proxy is supposed to be a URL - lets make sure.
	if {![regexp {\w://.*} $httpproxy]} {
	    # Dec 2002, jcw: also deal with "...;http=...;..." cases
	    foreach x [split $httpproxy {;}] {
		regsub {http=} $x {} x
		if {![string match *=* $x]} {
		    set httpproxy "http://$x"
		    break
		}
	    }
	}

	# decompose the string.
	array set proxy [uri::split $httpproxy]

	# turn the no_proxy value into a tcl list
	set no_proxy [string map {; " " , " "} $no_proxy]

	# setup the http package
	package require http
	http::config -proxyfilter [namespace origin filter]
    }
}

proc autoproxy::filter {host} {
    variable proxy
    variable no_proxy

    if {$proxy(host) == {}} {
	return {}
    }

    foreach domain $no_proxy {
	if {[string match $domain $host]} {
	    return {}
	}
    }
    return [list $proxy(host) $proxy(port)]
}

# 2002-12-11 jcw: a few tweaks to make Windows registry lookup more robust
package provide autoproxy 1.0.1

#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
