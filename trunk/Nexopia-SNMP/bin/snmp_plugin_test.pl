#!/usr/bin/perl -w
# $Id$

use Log::Log4perl;
use strict;

Log::Log4perl::init_once('/etc/log4perl.conf');
my $logger = Log::Log4perl->get_logger('interactive_script');

if (! scalar(@ARGV))
{
	print "List of SNMP Plugins Available for Testing:\n";
	foreach my $include_directory (@INC)
	{
		my $snmp_plugin_path = $include_directory . '/Nexopia/SNMP';
		next if (! -e $snmp_plugin_path);
		if (opendir(DIR, $snmp_plugin_path))
		{
			foreach my $snmp_plugin (grep { /\.pm$/ && -f $snmp_plugin_path . '/' . $_ } readdir(DIR))
			{
				$snmp_plugin =~ s/\.pm$//;
				print "\t" . $snmp_plugin . "\n";
			}
			closedir DIR;
		}
		else
		{
			$logger->error('Could not open directory ' . $snmp_plugin_path . ' for read: ' . $!);
		}
	}

	exit -1;
}

foreach my $snmp_plugin (@ARGV)
{
	my $snmp_plugin_arguments = undef;
	if ($snmp_plugin =~ /{.*}/)
	{
		($snmp_plugin, $snmp_plugin_arguments) = $snmp_plugin =~ /^(.*){(.*)}$/;
	}
	$snmp_plugin = 'Nexopia::SNMP::' . $snmp_plugin;
	my $snmp = undef;
	if ($snmp_plugin_arguments)
	{
		eval "require $snmp_plugin; \$snmp = $snmp_plugin->new( { logger => \$logger, $snmp_plugin_arguments } );";
	}
	else
	{
		eval "require $snmp_plugin; \$snmp = $snmp_plugin->new( { logger => \$logger } );";
	}
	if (defined $snmp)
	{
		$logger->info('Loading of ' . $snmp_plugin . ' succeeded');
		$snmp->dump(\*STDOUT);
		$logger->info('Test of ' . $snmp_plugin . ' completed');
	}
	else
	{
		$logger->error('Loading of ' . $snmp_plugin . ' failed');
	}
}
