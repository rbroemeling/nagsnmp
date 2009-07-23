# $Id$

package Nexopia::SNMP;

use Log::Log4perl;
use NetSNMP::OID;


sub new($;$)
{
	my ($class, $arg_ref) = @_;

	my $self =
	{
		# Our results cache.
		cache => {},

		# How long to cache our results for.
		cache_time => 15,

		# Keeps track of the last time that our results cache was updated.
		cache_timestamp => 0,

		# The highest OID that this module handles.
		highest_oid => undef,

		# The lowest OID that this module handles.
		lowest_oid => undef,

		# The SNMP module name that should represent this module.
		module_name => 'Nexopia_SNMP',

		# An array of OIDs sorted from lowest to highest.  Needed to answer a GETNEXT request.
		sorted_oid => [],

		# The OID prefix that this module is responsible for.
		#  .iso.org.dod.internet.private.enterprises.6396742
		#  .iso.org.dod.internet.private.enterprises.NEXOPIA
		source_oid => '.1.3.6.1.4.1.6396742'
	};

	# Update our logger-singleton with a new environment for this class unless we have been
	# instructed to use a specific logger.
	Log::Log4perl::init_once('/etc/log4perl.conf');
	$self->{logger} = defined($arg_ref->{logger}) ? $arg_ref->{logger} : Log::Log4perl->get_logger('daemon');

	bless $self, $class;
	return $self;
}


sub assign_result($$$)
{
	my ($self, $request, $requested_oid) = @_;

	$requested_oid = '.' . join('.', $requested_oid->to_array());
	if (! defined $self->{cache}->{$requested_oid})
	{
		$self->{logger}->warn('assign_result called with an undefined OID ' . $requested_oid);
		return;
	}
	if (! defined $self->{cache}->{$requested_oid}->{value})
	{
		$self->{logger}->warn('assign_result does not have a value to report for requested OID ' . $requested_oid);
		return;
	}
	$self->{logger}->debug('assign_result OID ' . $requested_oid . " is assigned the value '" . $self->{cache}->{$requested_oid}->{value} . "' (type " . $self->{cache}->{$requested_oid}->{type} . ")");
	$request->setOID($requested_oid);
	$request->setValue($self->{cache}->{$requested_oid}->{type}, $self->{cache}->{$requested_oid}->{value});
}


sub dump($$)
{
	my ($self, $fh) = @_;

	my $count = 0;
	print $fh $self->{module_name} . " OID Cache\n";
	foreach my $oid (keys %{$self->{cache}})
	{
		my $type = $self->{cache}->{$oid}->{type};
		my $value = $self->{cache}->{$oid}->{value};

		print $fh "\tOID " . $oid . "\t";
		print $fh '[Type ' . $type . "]\t";
		if (! defined $value)
		{
			print $fh 'undefined';
		}
		else
		{
			print $fh '"' . $value . '"';
		}
		print $fh "\n";
		$count++;
	}
	print $fh $count . " elements in OID cache.\n";
}


sub initialize_snmpwalk($)
{
	my ($self) = @_;

	$self->update_cache();
	foreach (sort {$a <=> $b} map { $_ = new NetSNMP::OID($_) } keys %{$self->{cache}})
	{
		push(@{$self->{sorted_oid}}, $_);
	}
	$self->{logger}->debug('initialize_snmpwalk determined sorted OID list [ ' . join(', ', @{$self->{sorted_oid}}) . ' ]');
	if ($#{$self->{sorted_oid}} > -1)
	{
		$self->{lowest_oid} = $self->{sorted_oid}->[0];
		$self->{logger}->debug('initialize_snmpwalk determined lowest OID to be ' . $self->{lowest_oid});
		$self->{highest_oid} = $self->{sorted_oid}->[$#{$self->{sorted_oid}}];
		$self->{logger}->debug('initialize_snmpwalk determined highest OID to be ' . $self->{highest_oid});
	}
}


sub register_snmpd($$)
{
	my ($self, $snmpd) = @_;

	if ($snmpd)
	{
		if (! $snmpd->register($self->{module_name}, $self->{source_oid}, sub { return $self->request_handler(@_); }))
		{
			$self->{logger}->error('register_snmpd failed: registration with existing agent failed');
		}
	}
	else
	{
		$self->{logger}->warn('register_snmpd failed: no existing agent could be found');
	}
}


sub request_handler($$$$$)
{
	my ($self, $handler, $registration_info, $request_info, $requests) = @_;

	if ((time() - $self->{cache_timestamp}) > $self->{cache_time})
	{
		$self->{logger}->debug('Cache timestamp ' . $self->{cache_timestamp} . ' has expired, updating cache');
		$self->update_cache();
	}
	for ($request = $requests; $request; $request = $request->next())
	{
		my $requested_oid = $request->getOID();
		if ($request_info->getMode() == NetSNMP::agent::MODE_GET)
		{
			$self->{logger}->debug('Processing GET request for OID ' . $requested_oid);
			$self->assign_result($request, $requested_oid);
		}
		elsif ($request_info->getMode() == NetSNMP::agent::MODE_GETNEXT)
		{
			$self->{logger}->debug('Processing GETNEXT request for OID ' . $requested_oid);
			if ($requested_oid < $self->{lowest_oid})
			{
				# The requested OID is lower than our lowest OID, so just return our lowest OID.
				$self->{logger}->debug($requested_oid . ' < ' . $self->{lowest_oid} . ', returning ' . $self->{lowest_oid});
				$self->assign_result($request, $self->{lowest_oid});
			}
			elsif ($requested_oid < $self->{highest_oid})
			{
				# The requested OID is lower than our highest OID, so return the next OID after it.
				for (my $i = 0; $i <= $#{$self->{sorted_oid}}; $i++)
				{
					if ($self->{sorted_oid}->[$i] > $requested_oid)
					{
						$self->assign_result($request, $self->{sorted_oid}->[$i]);
						last;
					}
				}
			}
			else
			{
				# The OID is >= our highest OID, and we have no idea what the next OID after it is.
				# Therefore we don't return anything specific.
			}
		}
	}
}


1;
