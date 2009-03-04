# $Id$

package Nexopia::SNMP::Memcached;

use Log::Log4perl;
use Net::Telnet;
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


sub telnet_read_variables($$)
{
	my ($self, $telnet) = @_;
	my %variables = ();

	my $line = $telnet->getline();
	while ((defined $line) && ($line =~ /^STAT /))
	{
		$line =~ s/\s+$//;
		my ($stat_prefix, $variable_name, $value) = grep(!/^\s*$/, split(/ /, $line));
		$variables{$variable_name} = $value;
		$line = $telnet->getline();
	}
	return \%variables;
}


sub update_cache($)
{
	my ($self) = @_;

	$self->{cache_timestamp} = time();

	$self->{cache}->{$self->{source_oid} . '.0'} = { type => NetSNMP::ASN::ASN_INTEGER, value => scalar @{$self->{memcached_ports}} };
	for (my $i = 0; $i <= $#{$self->{memcached_ports}}; $i++)
	{
		my $snmp_index = $i + 1;
		my $source_oid = $self->{source_oid} . '.3';

		$self->{cache}->{$self->{source_oid} . '.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_INTEGER,   value => $snmp_index };
		$self->{cache}->{$self->{source_oid} . '.2.' . $snmp_index} = { type => NetSNMP::ASN::ASN_OCTET_STR, value => $self->{memcached_ports}->[$i] };

		$self->{cache}->{$source_oid . '.0.0.0.' . $snmp_index} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # network.bytes.in
		$self->{cache}->{$source_oid . '.0.0.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # network.bytes.out
		$self->{cache}->{$source_oid . '.0.1.0.' . $snmp_index} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # network.connections.current
		$self->{cache}->{$source_oid . '.0.1.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # network.connections.structures
		$self->{cache}->{$source_oid . '.1.0.0.' . $snmp_index} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # commands.get.hits
		$self->{cache}->{$source_oid . '.1.0.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # commands.get.misses
		$self->{cache}->{$source_oid . '.1.1.'   . $snmp_index} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # commands.set
		$self->{cache}->{$source_oid . '.2.0.0.' . $snmp_index} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # allocated.items.current
		$self->{cache}->{$source_oid . '.2.0.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef }; # allocated.items.evictions
		$self->{cache}->{$source_oid . '.2.2.0.' . $snmp_index} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # allocated.bytes.current
		$self->{cache}->{$source_oid . '.2.2.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_GAUGE,   value => undef }; # allocated.bytes.maximum

		my $telnet = new Net::Telnet(Host => $self->{memcached_hostname}, Port => $self->{memcached_ports}->[$i], Timeout => 1, Errmode => 'return');
		if (! defined $telnet)
		{
			next;
		}
		$telnet->open() or return;
		$telnet->print('stats') or return;
		my $stats = $self->telnet_read_variables($telnet);
		$telnet->print('quit');

		if (defined $stats->{bytes_read})
		{
			$self->{cache}->{$source_oid . '.0.0.0.' . $snmp_index}->{value} = $stats->{bytes_read};
		}
		if (defined $stats->{bytes_written})
		{
			$self->{cache}->{$source_oid . '.0.0.1.' . $snmp_index}->{value} = $stats->{bytes_written};
		}
		if (defined $stats->{curr_connections})
		{
			$self->{cache}->{$source_oid . '.0.1.0.' . $snmp_index}->{value} = $stats->{curr_connections};
		}
		if (defined $stats->{connection_structures})
		{
			$self->{cache}->{$source_oid . '.0.1.1.' . $snmp_index}->{value} = $stats->{connection_structures};
		}
		if (defined $stats->{get_hits})
		{
			$self->{cache}->{$source_oid . '.1.0.0.' . $snmp_index}->{value} = $stats->{get_hits};
		}
		if (defined $stats->{get_misses})
		{
			$self->{cache}->{$source_oid . '.1.0.1.' . $snmp_index}->{value} = $stats->{get_misses};
		}
		if (defined $stats->{cmd_set})
		{
			$self->{cache}->{$source_oid . '.1.1.' . $snmp_index}->{value}   = $stats->{cmd_set};
		}
		if (defined $stats->{curr_items})
		{
			$self->{cache}->{$source_oid . '.2.0.0.' . $snmp_index}->{value} = $stats->{curr_items};
		}
		if (defined $stats->{evictions})
		{
			$self->{cache}->{$source_oid . '.2.0.1.' . $snmp_index}->{value} = $stats->{evictions};
		}
		if (defined $stats->{bytes})
		{
			$self->{cache}->{$source_oid . '.2.2.0.' . $snmp_index}->{value} = $stats->{bytes};
		}
		if (defined $stats->{limit_maxbytes})
		{
			$self->{cache}->{$source_oid . '.2.2.1.' . $snmp_index}->{value} = $stats->{limit_maxbytes};
		}
	}
}


1;
