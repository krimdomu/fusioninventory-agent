package FusionInventory::Agent::Targets;

use strict;
use warnings;

use threads::shared;

use FusionInventory::Agent::Target;

sub new {
    my ($class, $params) = @_;

    my $self = {
        config   => $params->{config},
        logger   => $params->{logger},
        deviceid => $params->{deviceid},
        targets  => []
    };

    bless $self, $class;

    $self->init();

    return $self;
}

sub init {
    my ($self) = @_;

    my $config = $self->{config};
    my $logger = $self->{logger};
    my $deviceid = $self->{deviceid};

    if ($config->{'stdout'}) {
        push
            @{$self->{targets}},
            FusionInventory::Agent::Target->new({
                logger   => $logger,
                config   => $config,
                type     => 'stdout',
                deviceid => $deviceid,
            });
    }

    if ($config->{'local'}) {
        push
            @{$self->{targets}},
            FusionInventory::Agent::Target->new({
                config   => $config,
                logger   => $logger,
                type     => 'local',
                path     => $config->{'local'},
                deviceid => $deviceid,
            });
    }

    foreach my $val (split(/,/, $config->{'server'})) {
        my $url;
        if ($val !~ /^https?:\/\//) {
            $logger->debug("the --server passed doesn't ".
                "have a protocole, ".
                "assume http as default");
            $url = "http://".$val.'/ocsinventory';
        } else {
            $url = $val;
        }
        push
            @{$self->{targets}},
            FusionInventory::Agent::Target->new({
                config   => $config,
                logger   => $logger,
                type     => 'server',
                path     => $url,
                deviceid => $deviceid,
            });
    }

}

sub getNext {
    my ($self) = @_;

    my $config = $self->{'config'};
    my $logger = $self->{'logger'};

    return unless @{$self->{targets}};

    if ($config->{'daemon'} or $config->{'daemon-no-fork'} or $config->{'winService'}) {
        while (1) {
            foreach my $target (@{$self->{targets}}) {
                if (time > $target->getNextRunDate()) {
                    return $target;
                }
            }
            sleep(10);
        }
    } elsif ($config->{'lazy'} && @{$self->{targets}}) {
        my $target = shift @{$self->{targets}};
        if (time > $target->getNextRunDate()) {
            $logger->debug("Processing ".$target->{'path'});
            return $target;
        } else {
            $logger->info("Nothing to do for ".$target->{'path'}.
		". Next server contact planned for ".
                localtime($target->getNextRunDate())
		);
        }
    } elsif ($config->{'wait'}) {
        my $wait = int rand($config->{'wait'});
        $logger->info("Going to sleep for $wait second(s) because of the".
            " wait parameter");
        sleep($wait);
        return shift @{$self->{targets}}
    } else {
        return shift @{$self->{targets}}
    }

    return;
}

sub numberOfTargets {
    my ($self) = @_;

    return @{$self->{targets}}
}

sub resetNextRunDate {
    my ($self) = @_;


    foreach my $target (@{$self->{targets}}) {
        $target->resetNextRunDate();
    }


}

1;
