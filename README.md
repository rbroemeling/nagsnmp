NagSNMP
=======
These are a set of PERL modules that are designed to be used with the
[net-snmp daemon](http://net-snmp.sourceforge.net/) and it's
[embedded PERL](http://www.net-snmp.org/wiki/index.php/Tut:Extending_snmpd_using_perl) mode.

Dependencies
------------
* log4perl (debian/ubuntu package: liblog-log4perl-perl)
* libsnmp (debian/ubuntu package: libsnmp-perl)

Installation
------------
Simply copy the files from lib/site_perl/* to somewhere on your system that
is within PERL's @INC search path.  Generally speaking, I like to use
/usr/local/lib/site_perl (so lib/site_perl/NagSNMP gets installed to
/usr/local/lib/site_perl/NagSNMP).

Usage
-----
Each individual plugin contains an example usage (i.e. configuration that you add to
snmpd.conf) showing how to use it.
