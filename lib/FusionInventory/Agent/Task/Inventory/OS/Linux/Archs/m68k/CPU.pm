package FusionInventory::Agent::Task::Inventory::OS::Linux::Archs::m68k::CPU;

use strict;
use warnings;

use English qw(-no_match_vars);

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::Linux;

sub isInventoryEnabled { 
    return -r '/proc/cpuinfo';
}

sub doInventory {
    my $params = shift;
    my $inventory = $params->{inventory};

    foreach my $cpu (_getCPUsFromProc($params->{logger})) {
        $inventory->addCPU($cpu);
    }
}

sub _getCPUsFromProc {
    my ($logger, $file) = @_;

    my @cpus;
    foreach my $cpu (getCPUsFromProc(logger => $logger, file => $file)) {

        push @cpus, {
            ARCH  => 'm68k',
            TYPE  => $cpu->{'cpu'},
            SPEED => $cpu->{'clocking'}
        };
    }

    return @cpus;
}

1;
