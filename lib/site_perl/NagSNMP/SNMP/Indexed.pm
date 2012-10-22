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

package NagSNMP::SNMP::Indexed;

use Log::Log4perl;
use NetSNMP::ASN;
use NagSNMP::SNMP;
use vars qw(@ISA);
@ISA = qw(NagSNMP::SNMP);


sub add_child($$$)
{
	my ($self, $child, $child_name) = @_;
	
	# Modify child's module name so that it is obvious that it is
	# a child of a NagSNMP::SNMP::Indexed object.
	$child->{module_name} .= '_Indexed';

	# Reverse-inherit our child's module name if we don't have one.
	if (! $self->{module_name})
	{
		$self->{module_name} = $child->{module_name};
		$self->{logger}->debug('Reverse-inherited the name ' . $self->{module_name} . ' from my child.');
	}
	
	# Reverse-inherit our child's source OID if we don't have one.
	if (! $self->{source_oid})
	{
		$self->{source_oid} = $child->{source_oid};
		$self->{logger}->debug('Reverse-inherited the root OID ' . $self->{source_oid} . ' from my child.');
	}
	
	# Modify the child's OID root so that it is within the indexed
	# root data section (.3).
	$child->{source_oid} .= '.3';

	# We have changed the child's OID root, so we need to expire it's
	# cache so that data in the old OID hierarchy is not used.
	$child->{cache_timestamp} = 0;

	# Add the new child to our list of children.
	push(@{$self->{children}}, $child);
	push(@{$self->{children_names}}, $child_name);
	$self->{logger}->debug('Added the child ' . $child . ', labelled "' . $child_name . '".');
	
	# Update our snmpwalk settings, now that we have more children than we
	# did before (as our list of available OIDs will have changed).
	$self->initialize_snmpwalk();
}


sub new($$$;$)
{
	my ($class, $first_child, $first_child_name, $arg_ref) = @_;

	my $self = NagSNMP::SNMP->new($arg_ref);

	# Severely limit caching of data at this "virtualized" layer, leave the
	# actual/real data caching to our children, who have to make costly
	# network connections to refresh their data.
	$self->{cache_time} = 5;

	# Initialize a new (empty) list of children.
	$self->{children} = [];

	# Initialize a new (empty) list of child names (labels).
	$self->{children_names} = [];

	# Null out our module name so that it will be reverse-inherited
	# when we add the child.
	$self->{module_name} = '';
	
	# Null out our source OID so that it will be reverse-inherited
	# when we add the child.
	$self->{source_oid} = '';

	bless $self, $class;
	
	# Add our first child to this indexed OID root.
	$self->add_child($first_child, $first_child_name);
	
	return $self;
}


sub register($$$)
{
	my ($class, $child, $child_name) = @_;

	if (! $NagSNMP::SNMP::Indexed::children)
	{
		$NagSNMP::SNMP::Indexed::children = {};
	}
	if (! $NagSNMP::SNMP::Indexed::children->{$child->{source_oid}})
	{
		# We do not have an indexed child registered for this OID
		# tree, so create one.
		my $indexed_root = NagSNMP::SNMP::Indexed->new($child, $child_name);
		$NagSNMP::SNMP::Indexed::children->{$indexed_root->{source_oid}} = $indexed_root;
	}
	else
	{
		$NagSNMP::SNMP::Indexed::children->{$child->{source_oid}}->add_child($child, $child_name);
	}
}


sub register_snmpd($$)
{
	my ($class_or_ref, $snmpd) = @_;

	if (ref($class_or_ref))
	{
		# We are being called as an instance method.
		return $class_or_ref->SUPER::register_snmpd($snmpd);
	}
	else
	{
		# We are being called as a class method.
		if (! $NagSNMP::SNMP::Indexed::children)
		{
			$NagSNMP::SNMP::Indexed::children = {};
		}
		foreach my $oid_root (keys %{$NagSNMP::SNMP::Indexed::children})
		{
			$NagSNMP::SNMP::Indexed::children->{$oid_root}->register_snmpd($snmpd);
		}
	}
}


sub update_cache($)
{
	my ($self) = @_;
	
	$self->{cache_timestamp} = time();
	$self->{cache} = {};
	
	# .0 is a count of the number of indexed children we have.
	$self->{cache}->{$self->{source_oid} . '.0'} = { type => NetSNMP::ASN::ASN_INTEGER, value => scalar @{$self->{children}} };
	
	for (my $i = 0; $i <= $#{$self->{children}}; $i++)
	{
		$child = $self->{children}->[$i];
		$child_name = $self->{children_names}->[$i];
		$snmp_index = $i + 1;

		# .1.x is the numeric index of the x'th indexed child that we have.
		$self->{cache}->{$self->{source_oid} . '.1.' . $snmp_index} = { type => NetSNMP::ASN::ASN_INTEGER, value => $snmp_index };
		
		# .2.x is the label (a string) of the x'th indexed child that we have.
		$self->{cache}->{$self->{source_oid} . '.2.' . $snmp_index} = { type => NetSNMP::ASN::ASN_OCTET_STR, value => $child_name };

		# .3.<intermediaries>.x is the value of the x'th indexed child for <intermediaries>.
		if ($child->cache_expired())
		{
			$child->update_cache();
		}
		foreach my $oid (keys %{$child->{cache}})
		{
			$self->{cache}->{$oid . '.' . $snmp_index} = $child->{cache}->{$oid};
		}
	}
}


1;
