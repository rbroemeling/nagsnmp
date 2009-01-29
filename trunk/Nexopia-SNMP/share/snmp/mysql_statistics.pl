#!/usr/bin/perl -w
# $Id$

use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use NetSNMP::agent;
use Nexopia::SNMP::MySQL;
use strict;

# Setup logging for this SNMP plugin.
{
	my $logger_configuration = q/
		log4perl.logger = DEBUG, Syslog

		log4perl.appender.Syslog = Log::Dispatch::Syslog
		log4perl.appender.Syslog.Facility = user
		log4perl.appender.Syslog.layout = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.Syslog.layout.ConversionPattern =[%p] %F{1}:%L %m%n
	/;
	Log::Log4perl::init(\$logger_configuration);
}
my $logger = Log::Log4perl::get_logger('main');

# Start our own subagent to integrate with SNMPD and register ourselves.
my $snmp = Nexopia::SNMP::MySQL->new;
my $agent = new NetSNMP::agent('AgentX' => 1, 'Name' => $snmp->{module_name} . '_Agent');
if (! $agent)
{
	$logger->error('Could not connect to master SNMP agent, exiting');
	exit -1;
}
if (! $agent->register($snmp->{module_name}, $snmp->{source_oid}, sub { return $snmp->request_handler(@_); }))
{
	$logger->error('Could not register with master SNMP agent, exiting');
	exit -2;
}

my $running = 1;
$SIG{'INT'} = sub { $running = 0; };
$SIG{'QUIT'} = sub { $running = 0; };
while ($running)
{
	# The argument '1' to ->agent_check_and_process() configures it to block until an event occurs.
	$agent->agent_check_and_process(1);
}
$agent->shutdown();
