# $Id$

use Nexopia::SNMP::MySQL;

# Register ourselves with the SNMP agent.
if (! $agent)
{
	print STDERR $0 . " currently only supports embedded perl mode.\n";
	exit -1;
}
my $snmp = Nexopia::SNMP::MySQL->new;
$agent->register($snmp->{module_name}, $snmp->{source_oid}, sub { return $snmp->request_handler(@_); });
