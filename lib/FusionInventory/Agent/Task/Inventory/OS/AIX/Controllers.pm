package FusionInventory::Agent::Task::Inventory::OS::AIX::Controllers;

use strict;
use warnings;

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::AIX;

sub isInventoryEnabled {
    return can_run('lsdev');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    foreach my $controller (_getControllers(
        logger  => $logger,
    )) {
        $inventory->addEntry(
            section => 'CONTROLLERS',
            entry   => $controller
        );
    }
}

sub _getControllers {
    my @adapters = getAdaptersFromLsdev(@_);

    my @controllers;
    foreach my $adapter (@adapters) {
        push @controllers, {
            NAME => $adapter->{NAME},
        };
    }

    return @controllers;
}

1;
