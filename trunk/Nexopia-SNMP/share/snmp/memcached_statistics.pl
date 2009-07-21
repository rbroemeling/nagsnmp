#!/usr/bin/perl
# $Id$

use Log::Log4perl;
use Nexopia::SNMP::Memcached;

# Setup logging for this SNMP plugin.
Log::Log4perl::init('/etc/log4perl.conf');
my $logger = Log::Log4perl::get_logger('daemon');

my $snmp = Nexopia::SNMP::Memcached->new;
# Register ourselves with the SNMP agent.
if ($agent)
{
	if (! $agent->register($snmp->{module_name}, $snmp->{source_oid}, sub { return $snmp->request_handler(@_); }))
	{
		$logger->error('Could not register with master SNMP agent, exiting');
	}
}
else
{
	# The SNMP agent does not exist (i.e. we are not in embedded PERL, but are being executed externally).
	# Assume that we are debugging.
	$snmp->dump(\*STDOUT);
}
