# $Id$

package Nexopia::SNMP::Memcached;

use Cache::Memcached;
use Log::Log4perl;
use NetSNMP::ASN;
use Nexopia::SNMP;
use vars qw(@ISA);
@ISA = qw(Nexopia::SNMP);


sub new($)
{
	my $class = $_[0];

	my $self = Nexopia::SNMP->new(@_);
	bless $self, $class;

	# Update our logger-singleton with a new environment for this class.
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);

	# Append the appropriate suffix to our SNMP module name.
	$self->{module_name} .= '_Memcached';

	# Memcached hostname to monitor.
	$self->{memcached_hostname} = $self->get_environment_setting('memcached_hostname');
	if (! defined $self->{memcached_hostname})
	{
		$self->{memcached_hostname} = '127.0.0.1';
	}

	# Memcached port(s) to monitor.
	$self->{memcached_ports} = $self->get_environment_setting('memcached_ports');
	if (! defined $self->{memcached_ports})
	{
		$self->{memcached_ports} = [ 11212, 11213, 11222, 11223 ];
	}
	else
	{
		my @ports = split(/,/, $self->{memcached_ports});
		$self->{memcached_ports} = \@ports;
	}

	# We handle the .63623 (.MEMCD) sub-tree of our parent OID.
	$self->{source_oid} .= '.63623';

	$self->initialize_snmpwalk();
	return $self;
}


sub update_cache($)
{
	my ($self) = @_;

	$self->{cache_timestamp} = time();
	foreach my $port (@{$self->{memcached_ports}})
	{
		my $source_oid = $self->{source_oid} . '.' . $port;

		$self->{cache}->{$source_oid . '.0.0.0'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # network.bytes.in
		$self->{cache}->{$source_oid . '.0.0.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # network.bytes.out
		$self->{cache}->{$source_oid . '.0.1.0'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # network.connections.current
		$self->{cache}->{$source_oid . '.0.1.1'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # network.connections.structures
		$self->{cache}->{$source_oid . '.1.0.0'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # commands.get.hits
		$self->{cache}->{$source_oid . '.1.0.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # commands.get.misses
		$self->{cache}->{$source_oid . '.1.1'}   = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # commands.set
		$self->{cache}->{$source_oid . '.2.0.0'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # allocated.items.current
		$self->{cache}->{$source_oid . '.2.0.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # allocated.items.evictions
		$self->{cache}->{$source_oid . '.2.2.0'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # allocated.bytes.current
		$self->{cache}->{$source_oid . '.2.2.1'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # allocated.bytes.maximum

		my $memcached = new Cache::Memcached { 'servers' => [ $self->{memcached_hostname} . ':' . $port ] };
		if (! defined $memcached)
		{
			next;
		}
		my $stats = $memcached->stats('misc');
		if (defined $stats->{hosts}->{$self->{memcached_hostname} . ':' . $port}->{misc})
		{
			$stats = $stats->{hosts}->{$self->{memcached_hostname} . ':' . $port}->{misc};
		}
		if (defined $stats->{bytes_read})
		{
			$self->{cache}->{$source_oid . '.0.0.0'}->{value} = $stats->{bytes_read};
		}
		if (defined $stats->{bytes_written})
		{
			$self->{cache}->{$source_oid . '.0.0.1'}->{value} = $stats->{bytes_written};
		}
		if (defined $stats->{curr_connections})
		{
			$self->{cache}->{$source_oid . '.0.1.0'}->{value} = $stats->{curr_connections};
		}
		if (defined $stats->{connection_structures})
		{
			$self->{cache}->{$source_oid . '.0.1.1'}->{value} = $stats->{connection_structures};
		}
		if (defined $stats->{get_hits})
		{
			$self->{cache}->{$source_oid . '.1.0.0'}->{value} = $stats->{get_hits};
		}
		if (defined $stats->{get_misses})
		{
			$self->{cache}->{$source_oid . '.1.0.1'}->{value} = $stats->{get_misses};
		}
		if (defined $stats->{cmd_set})
		{
			$self->{cache}->{$source_oid . '.1.1'}->{value} = $stats->{cmd_set};
		}
		if (defined $stats->{curr_items})
		{
			$self->{cache}->{$source_oid . '.2.0.0'}->{value} = $stats->{curr_items};
		}
		if (defined $stats->{evictions})
		{
			$self->{cache}->{$source_oid . '.2.0.1'}->{value} = $stats->{evictions};
		}
		if (defined $stats->{bytes})
		{
			$self->{cache}->{$source_oid . '.2.2.0'}->{value} = $stats->{bytes};
		}
		if (defined $stats->{limit_maxbytes})
		{
			$self->{cache}->{$source_oid . '.2.2.1'}->{value} = $stats->{limit_maxbytes};
		}
	}
}


1;
