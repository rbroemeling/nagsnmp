# $Id$

package Nexopia::SNMP::Memcached;

use Log::Log4perl;
use Net::Telnet;
use NetSNMP::ASN;
use Nexopia::SNMP;
use vars qw(@ISA);
@ISA = qw(Nexopia::SNMP);


sub new($;$)
{
	my ($class, $arg_ref) = @_;

	my $self = Nexopia::SNMP->new($arg_ref);

	# Append the appropriate suffix to our SNMP module name.
	$self->{module_name} .= '_Memcached';

	# Memcached hostname to monitor.
	$self->{memcached_hostname} = defined($arg_ref->{memcached_hostname}) ? $arg_ref->{memcached_hostname} : '127.0.0.1';

	# Memcached port to monitor.
	$self->{memcached_port} = defined($arg_ref->{memcached_port}) ? $arg_ref->{memcached_port} : 11212;

	# We handle the .63623 (.MEMCD) sub-tree of our parent OID.
	$self->{source_oid} .= '.63623';

	bless $self, $class;

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
		$line =~ s/(^\s+|\s+$)//g;
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
	$self->{cache} = {};

	my $stats = {};
	my $telnet = new Net::Telnet(Host => $self->{memcached_hostname}, Port => $self->{memcached_port}, Timeout => 1, Errmode => 'return');
	if (defined $telnet && $telnet->open() && $telnet->print('stats'))
	{
		$stats = $self->telnet_read_variables($telnet);
		$telnet->print('quit');
		$telnet->close();
	}

	$self->{cache}->{$self->{source_oid} . '.0.0.0'} = { type => NetSNMP::ASN::ASN_COUNTER, value => defined($stats->{bytes_read}) ? $stats->{bytes_read} : undef };                       # network.bytes.in 
	$self->{cache}->{$self->{source_oid} . '.0.0.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => defined($stats->{bytes_written}) ? $stats->{bytes_written} : undef };                 # network.bytes.out
	$self->{cache}->{$self->{source_oid} . '.0.1.0'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => defined($stats->{curr_connections}) ? $stats->{curr_connections} : undef };           # network.connections.current
	$self->{cache}->{$self->{source_oid} . '.0.1.1'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => defined($stats->{connection_structures}) ? $stats->{connection_structures} : undef }; # network.connections.structures
	$self->{cache}->{$self->{source_oid} . '.1.0.0'} = { type => NetSNMP::ASN::ASN_COUNTER, value => defined($stats->{get_hits}) ? $stats->{get_hits} : undef };                           # commands.get.hits
	$self->{cache}->{$self->{source_oid} . '.1.0.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => defined($stats->{get_misses}) ? $stats->{get_misses} : undef };                       # commands.get.misses
	$self->{cache}->{$self->{source_oid} . '.1.1'  } = { type => NetSNMP::ASN::ASN_COUNTER, value => defined($stats->{cmd_set}) ? $stats->{cmd_set} : undef };                             # commands.set
	$self->{cache}->{$self->{source_oid} . '.2.0.0'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => defined($stats->{curr_items}) ? $stats->{curr_items} : undef };                       # allocated.items.current
	$self->{cache}->{$self->{source_oid} . '.2.0.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => defined($stats->{evictions}) ? $stats->{evictions} : undef };                         # allocated.items.evictions
	$self->{cache}->{$self->{source_oid} . '.2.2.0'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => defined($stats->{bytes}) ? $stats->{bytes} : undef };                                 # allocated.bytes.current
	$self->{cache}->{$self->{source_oid} . '.2.2.1'} = { type => NetSNMP::ASN::ASN_GAUGE,   value => defined($stats->{limit_maxbytes}) ? $stats->{limit_maxbytes} : undef };               # allocated.bytes.maximum
}


1;
