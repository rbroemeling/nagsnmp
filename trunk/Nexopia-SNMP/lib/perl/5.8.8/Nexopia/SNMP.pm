# $Id$

package Nexopia::SNMP;

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

	if ((defined $self->{cache}->{$requested_oid}) && (defined $self->{cache}->{$requested_oid}->{value}))
	{
		$request->setOID($requested_oid);
		$request->setValue($self->{cache}->{$requested_oid}->{type}, $self->{cache}->{$requested_oid}->{value});
	}
}


sub initialize_snmpwalk($)
{
	my ($self) = @_;

	my @sorted_oid_list = @{$self->{sorted_oid_list}};

	$self->update_cache();
	foreach (sort {$a <=> $b} map { $_ = new NetSNMP::OID($_) } keys %{$self->{cache}})
	{
		$sorted_oid_list[++$#sorted_oid_list] = $_;
	}
	if ($#sorted_oid_list > -1)
	{
		$self->{highest_oid} = $sorted_oid_list[$#sorted_oid_list];
		$self->{lowest_oid} = $sorted_oid_list[0];
	}
	else
	{
		$self->{highest_oid} = undef;
		$self->{lowest_oid} = undef;
	}
}


sub request_handler($$$$$)
{
	my ($self, $handler, $registration_info, $request_info, $requests) = @_;

	if ((time() - $self->{cache_timestamp}) > $self->{cache_time})
	{
		$self->update_cache();
	}
	for ($request = $requests; $request; $request = $request->next())
	{
		my $requested_oid = $request->getOID();
		if ($request_info->getMode() == NetSNMP::agent::MODE_GET)
		{
			$self->assign_result($request, $requested_oid);
		}
		elsif ($request_info->getMode() == NetSNMP::agent::MODE_GETNEXT)
		{
			if ($requested_oid < $self->{lowest_oid})
			{
				# The requested OID is lower than ours, so just return ours.
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
				} while (NetSNMP::OID::compare($requested_oid, $next_oid) > -1 and $i < scalar @{$self->{sorted_oid_list}});

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
