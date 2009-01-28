# $Id$

package Nexopia::SNMP;

use Log::Log4perl;
use NetSNMP::OID;

sub new($)
{
	my $class = shift;

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

		# Get our logger-singleton and setup it's environment for this class.
		logger => Log::Log4perl->get_logger(__PACKAGE__),

		# The lowest OID that this module handles.
		lowest_oid => undef,

		# The SNMP module name that should represent this module.
		module_name => 'Nexopia_SNMP',

		# A sorted list of OIDs that this module handles, needed to answer a GETNEXT request.
		sorted_oid_list => [],

		# The OID prefix that this module is responsible for.
		#  .iso.org.dod.internet.private.enterprises.6396742
		#  .iso.org.dod.internet.private.enterprises.NEXOPIA
		source_oid => new NetSNMP::OID('.1.3.6.1.4.1.6396742')
	};
	bless $self, $class;
	return $self;
}


sub assign_result($$$)
{
	my ($self, $request, $requested_oid) = @_;


	if (! defined $self->{cache}->{$requested_oid})
	{
		$self->{logger}->warn('assign_result called with an undefined OID ' . $requested_oid);
		return;
	}
	if (! defined $self->{cache}->{$requested_oid}->{value})
	{
		$self->{logger}->info('assign_result does not have a value to report for requested OID ' . $requested_oid);
		return;
	}
	$self->{logger}->debug('assign_result OID ' . $requested_oid . " is assigned the value '" . $self->{cache}->{$requested_oid}->{value} . "' (type " . $self->{cache}->{$requested_oid}->{type} . ")");
	$request->setOID($requested_oid);
	$request->setValue($self->{cache}->{$requested_oid}->{type}, $self->{cache}->{$requested_oid}->{value});
}


sub initialize_snmpwalk($)
{
	my ($self) = @_;

	$self->update_cache();
	foreach (sort {$a <=> $b} map { $_ = new NetSNMP::OID($_) } keys %{$self->{cache}})
	{
		push(@{$self->{sorted_oid_list}}, $_);
	}
	$self->{logger}->debug('initialize_snmpwalk determined sorted OID list [ ' . join(', ', @{$self->{sorted_oid_list}}) . ' ]');
	if (scalar(@{$self->{sorted_oid_list}}) > -1)
	{
		$self->{highest_oid} = $self->{sorted_oid_list}->[scalar(@{$self->{sorted_oid_list}})];
		$self->{lowest_oid} = $self->{sorted_oid_list}->[0];
		$self->{logger}->debug('initialize_snmpwalk determined lowest/highest OID to be ' . $self->{lowest_oid} . '/' . $self->{highest_oid})
	}
	else
	{
		$self->{logger}->warn('initialize_snmpwalk unable to determine lowest/highest OID from empty sorted OID list');
		$self->{highest_oid} = undef;
		$self->{lowest_oid} = undef;
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
				# The requested OID is somewhere within the range $self->{lowest_oid}:$self->{highest_oid},
				# so return the first one after it.
				my $i = 0;
				my $next_oid = undef;

				# Carry out a linear search of $self->{sorted_oid_list}.
				do
				{
					$next_oid = $self->{sorted_oid_list}->[$i];
					$i++;
				} while ((NetSNMP::OID::compare($requested_oid, $next_oid) > -1) and ($i < scalar(@{$self->{sorted_oid_list}})));
				$self->{logger}->debug('Next OID after ' . $requested_oid . ' is ' . $next_oid);

				if (defined $next_oid)
				{
					# We found the next OID successfully, so we return it.
					$self->assign_result($request, $next_oid);
				}
			}
		}
	}
}


sub update_cache($)
{
	my ($self) = @_;

	$self->{cache_timestamp} = time();
}


1;
