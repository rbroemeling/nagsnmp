#
# The MIT License (http://www.opensource.org/licenses/mit-license.php)
#
# Copyright (c) 2012 Themis Solutions, Inc.
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

#
# Example Usage (in snmpd.conf):
#   perl require NagSNMP::SNMP::Postfix; $nagsnmp_postfix = NagSNMP::SNMP::Postfix->new(); $nagsnmp_postfix->register_snmpd($agent);
#

package NagSNMP::SNMP::Postfix;

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
  $self->{module_name} .= '_Postfix';

  # Path to our `postqueue` binary.  Ideally, we would like to communicate directly with the showq daemon to retrieve
  # information about the queue (or suss it out ourselves by examining files in /var/spool/postfix).  At present there is
  # no good way to communicate with the showq daemon, however; and /var/spool/postfix is usually not accessible to the
  # user that this monitor will be running as (and typically *should not* be).  Therefore, we simply use postqueue
  # at the moment and leave "better" (i.e. more specific) queue monitoring for a future enhancement, perhaps when the
  # showq daemon is more accessible.
  $self->{postqueue_path} = defined($arg_ref->{postqueue_path}) ? $arg_ref->{postqueue_path} : '/usr/sbin/postqueue';

  # We handle the .7678349 (.POSTFIX) sub-tree of our parent OID.
  $self->{source_oid} .= '.7678349';

  bless $self, $class;

  $self->initialize_snmpwalk();

  return $self;
}


sub update_cache($)
{
  my ($self) = @_;

  $self->{cache_timestamp} = time();
  $self->{cache} = {};

  $self->{cache}->{$self->{source_oid} . '.0'} = { type => NetSNMP::ASN::ASN_GAUGE, value => undef }; # Postfix 'active' queue.
  $self->{cache}->{$self->{source_oid} . '.1'} = { type => NetSNMP::ASN::ASN_GAUGE, value => undef }; # Postfix 'deferred' queue.
  $self->{cache}->{$self->{source_oid} . '.2'} = { type => NetSNMP::ASN::ASN_GAUGE, value => undef }; # Postfix 'hold' queue.

  open(POSTQUEUE, $self->{postqueue_path} . ' -p|') or return;
  $self->{cache}->{$self->{source_oid} . '.0'}->{value} = 0;
  $self->{cache}->{$self->{source_oid} . '.1'}->{value} = 0;
  $self->{cache}->{$self->{source_oid} . '.2'}->{value} = 0;
  while (<POSTQUEUE>) {
    if (/^([0-9A-F]{11,})([*!]?)/) {
      if ($2 eq "*") {
        $self->{logger}->debug('Postfix Queue ID ' . $1 . ': ACTIVE QUEUE');
        $self->{cache}->{$self->{source_oid} . '.0'}->{value} += 1;
      } elsif ($2 eq "!") {
        $self->{logger}->debug('Postfix Queue ID ' . $1 . ': HOLD QUEUE');
        $self->{cache}->{$self->{source_oid} . '.2'}->{value} += 1;
      } else {
        $self->{logger}->debug('Postfix Queue ID ' . $1 . ': DEFERRED QUEUE');
        $self->{cache}->{$self->{source_oid} . '.1'}->{value} += 1;
      }
    }
  }
  close(POSTQUEUE);
}


1;
