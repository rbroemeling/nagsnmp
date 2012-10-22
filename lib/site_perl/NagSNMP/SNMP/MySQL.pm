#
# The MIT License (http://www.opensource.org/licenses/mit-license.php)
# 
# Copyright (c) 2010 Nexopia.com, Inc.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

package NagSNMP::SNMP::MySQL;

use DBI;
use Log::Log4perl;
use NetSNMP::ASN;
use NagSNMP::SNMP;
use vars qw(@ISA);
@ISA = qw(NagSNMP::SNMP);


sub new($;$)
{
	my ($class, $arg_ref) = @_;

	my $self = NagSNMP::SNMP->new($arg_ref);

	# Append the appropriate suffix to our SNMP module name.
	$self->{module_name} .= '_MySQL';

	# MySQL hostname to monitor.
	$self->{mysql_hostname} = defined($arg_ref->{mysql_hostname}) ? $arg_ref->{mysql_hostname} : '127.0.0.1';

	# MySQL user password used to monitor.
	$self->{mysql_password} = defined($arg_ref->{mysql_password}) ? $arg_ref->{mysql_password} : '';

	# MySQL port used to monitor.
	$self->{mysql_port} = defined($arg_ref->{mysql_port}) ? $arg_ref->{mysql_port} : 3306;

	# MySQL user used to monitor.
	$self->{mysql_username} = defined($arg_ref->{mysql_username}) ? $arg_ref->{mysql_username} : 'monitor';

	# We handle the .69775 (.MYSQL) sub-tree of our parent OID.
	$self->{source_oid} .= '.69775';

	bless $self, $class;

	$self->initialize_snmpwalk();

	return $self;
}


sub update_cache($)
{
	my ($self) = @_;

	$self->{cache_timestamp} = time();
	$self->{cache} = {};

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
