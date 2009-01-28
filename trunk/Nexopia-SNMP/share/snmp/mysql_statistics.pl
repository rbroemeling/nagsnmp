# $Id$

use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Nexopia::SNMP::MySQL;

# Setup logging for this SNMP plugin.
{
	my $logger = Log::Log4perl->get_logger;
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

# Register ourselves with the SNMP agent.
if (! $agent)
{
	print STDERR $0 . " currently only supports embedded perl mode.\n";
	exit -1;
}
my $snmp = Nexopia::SNMP::MySQL->new;
$agent->register($snmp->{module_name}, $snmp->{source_oid}, sub { return $snmp->request_handler(@_); });
