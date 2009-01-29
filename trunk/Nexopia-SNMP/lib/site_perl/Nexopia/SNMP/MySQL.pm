# $Id$

package Nexopia::SNMP::MySQL;

use DBI;
use Log::Log4perl;
use NetSNMP::ASN;
use Nexopia::SNMP;
use vars qw(@ISA);
@ISA = qw(Nexopia::SNMP);


sub new($)
{
	my $class = $_[0];

	my $self = Nexopia::SNMP->new(@_);

	# Update our logger-singleton with a new environment for this class.
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);

	# Append the appropriate suffix to our SNMP module name.
	$self->{module_name} .= '_MySQL';

	# MySQL hostname to monitor.
	$self->{mysql_hostname} = '127.0.0.1';

	# MySQL user password used to monitor.
	$self->{mysql_password} = '';

	# MySQL port used to monitor.
	$self->{mysql_port} = 3306;

	# MySQL user used to monitor.
	$self->{mysql_username} = 'monitor';

	# We handle the .69775 (.MYSQL) sub-tree of our parent OID.
	$self->{source_oid} .= '.69775';

	bless $self, $class;

	$self->initialize_snmpwalk();
	return $self;
}


sub update_cache($)
{
	my ($self) = @_;

	Nexopia::SNMP->update_cache(@_);
	$self->{cache}->{$self->{source_oid} . '.0.0'} = { type => NetSNMP::ASN::ASN_GAUGE, value => undef };
	$self->{cache}->{$self->{source_oid} . '.0.1'} = { type => NetSNMP::ASN::ASN_GAUGE, value => undef };
	$self->{cache}->{$self->{source_oid} . '.0.2'} = { type => NetSNMP::ASN::ASN_GAUGE, value => undef };
	$self->{cache}->{$self->{source_oid} . '.1.0'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };
	$self->{cache}->{$self->{source_oid} . '.1.1'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };
	$self->{cache}->{$self->{source_oid} . '.1.2'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };
	$self->{cache}->{$self->{source_oid} . '.1.3'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };
	$self->{cache}->{$self->{source_oid} . '.1.4'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };
	$self->{cache}->{$self->{source_oid} . '.1.5'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };
	$self->{cache}->{$self->{source_oid} . '.2.0'} = { type => NetSNMP::ASN::ASN_COUNTER, value => undef };

	my %vars = ();
	my $dbh = DBI->connect('dbi:mysql:' . join(':', '', $self->{mysql_hostname}, $self->{mysql_port}), $self->{mysql_username}, $self->{mysql_password}, { mysql_auto_reconnect => 1, mysql_connect_timeout => 1, PrintError => 0, RaiseError => 0 }) or return;
	my $sth = $dbh->prepare('SHOW GLOBAL STATUS') or return;
	$sth->execute() or return;
	while (my $row = $sth->fetchrow_hashref())
	{
		$vars{$row->{Variable_name}} = $row->{Value};
	}
	$sth->finish();
	$dbh->disconnect();

	$self->{cache}->{$self->{source_oid} . '.0.0'}->{value} = $vars{Threads_cached};
	$self->{cache}->{$self->{source_oid} . '.0.1'}->{value} = $vars{Threads_connected};
	$self->{cache}->{$self->{source_oid} . '.0.2'}->{value} = $vars{Threads_running};
	$self->{cache}->{$self->{source_oid} . '.1.0'}->{value} = 0;
	foreach (grep(/^Com_/, keys %vars))
	{
		next if /^Com_delete(_multi)?$/;
		next if /^Com_insert(_select)?$/;
		next if /^Com_replace(_select)?$/;
		next if /^Com_select$/;
		next if /^Com_update(_multi)?$/;
		$self->{cache}->{$self->{source_oid} . '.1.0'}->{value} += $vars{$_};
	}
	$self->{cache}->{$self->{source_oid} . '.1.1'}->{value} = $vars{Com_delete} + $vars{Com_delete_multi};
	$self->{cache}->{$self->{source_oid} . '.1.2'}->{value} = $vars{Com_insert} + $vars{Com_insert_select};
	$self->{cache}->{$self->{source_oid} . '.1.3'}->{value} = $vars{Com_replace} + $vars{Com_replace_select};
	$self->{cache}->{$self->{source_oid} . '.1.4'}->{value} = $vars{Com_select};
	$self->{cache}->{$self->{source_oid} . '.1.5'}->{value} = $vars{Com_update} + $vars{Com_update_multi};
	$self->{cache}->{$self->{source_oid} . '.2.0'}->{value} = $vars{Slow_queries};
}


1;
