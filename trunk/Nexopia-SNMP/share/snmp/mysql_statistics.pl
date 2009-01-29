#!/usr/bin/perl -w
# $Id$

use File::Basename;
use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use NetSNMP::agent;
use Nexopia::SNMP::MySQL;
use strict;

# Setup logging for this SNMP plugin.
my $logger = Log::Log4perl->get_logger;
{
	$logger->level($DEBUG);
	my $Syslog_Layout = Log::Log4perl::Layout::PatternLayout->new('[%L/%p] %m%n');

	my $Syslog = Log::Log4perl::Appender->new(
		'Log::Dispatch::Syslog',
		facility => 'user',
		ident => basename($0),
		logopt => 'nofatal',
		name => 'Syslog'
	);
	$Syslog->layout($Syslog_Layout);
	$Syslog->threshold($INFO);
	$logger->add_appender($Syslog);
}

# Start our own subagent to integrate with SNMPD and register ourselves.
my $snmp = Nexopia::SNMP::MySQL->new;
my $agent = new NetSNMP::agent('AgentX' => 1, 'Name' => $snmp->{module_name} . '_Agent');
if (! $agent)
{
	$logger->error('Could not connect to master SNMP agent, exiting');
	exit -2;
}
$agent->register($snmp->{module_name}, $snmp->{source_oid}, sub { return $snmp->request_handler(@_); });

my $running = 1;
$SIG{'INT'} = sub { $running = 0; };
$SIG{'QUIT'} = sub { $running = 0; };
while ($running)
{
	# The argument '1' to ->agent_check_and_process() configures it to block until an event occurs.
	$agent->agent_check_and_process(1);
}
$agent->shutdown();
