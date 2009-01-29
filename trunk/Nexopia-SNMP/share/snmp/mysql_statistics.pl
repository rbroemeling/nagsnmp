#!/usr/bin/perl
# $Id$

use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Nexopia::SNMP::MySQL;

# Setup logging for this SNMP plugin.
{
	my $logger_configuration = q/
		log4perl.logger = WARN, Syslog

		log4perl.appender.Syslog = Log::Dispatch::Syslog
		log4perl.appender.Syslog.Facility = user
		log4perl.appender.Syslog.layout = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.Syslog.layout.ConversionPattern =[%p] %F{1}:%L %m%n
	/;
	Log::Log4perl::init(\$logger_configuration);
}
my $logger = Log::Log4perl::get_logger('main');

# Register ourselves with the SNMP agent.
if ($agent)
{
	my $snmp = Nexopia::SNMP::MySQL->new;
	if (! $agent->register($snmp->{module_name}, $snmp->{source_oid}, sub { return $snmp->request_handler(@_); }))
	{
		$logger->error('Could not register with master SNMP agent, exiting');
	}
}
else
{
	$logger->error('Expected master agent to be defined in embedded perl environment, exiting');
}
