package FusionInventory::Agent::Config;

use strict;
use warnings;

use Getopt::Long;
use Cwd qw(fast_abs_path abs_path);
use English qw(-no_match_vars);

my $basedir = $OSNAME eq 'MSWin32' ?
    $ENV{APPDATA}.'/fusioninventory-agent' : '';

my $default = {
    'backend-collect-timeout' => 180,   # timeOut of process : see Backend.pm
    'basevardir'              => $basedir . '/var/lib/fusioninventory-agent',
    'ca-cert-dir'             => '',
    'ca-cert-file'            => '',
    'conf-file'               => '',
    'color'                   => 0,
    'daemon'                  => 0,
    'no-fork'                 => 0,
    'delaytime'               => 3600, # max delay time (seconds)
    'debug'                   => 0,
    'devlib'                  => 0,
    'force'                   => 0,
    'help'                    => 0,
    'format'                  => 'xml',
    'info'                    => 1,
    'lazy'                    => 0,
    'local'                   => '',
    'logger'                  => 'Stderr',
    'logfile'                 => '',
    'logfile-maxsize'         => 0,
    'logfacility'             => 'LOG_USER',
    'no-ocsdeploy'            => 0,
    'no-inventory'            => 0,
    'no-printer'              => 0,
    'no-www'                  => 0,
    'no-software'             => 0,
    'no-wakeonlan'            => 0,
    'no-snmpquery'            => 0,
    'no-netdiscovery'         => 0,
    'no-ssl-check'            => 0,
    'password'                => '',
    'proxy'                   => '',
    'realm'                   => '',
    'share-dir'               => 0,
    'server'                  => '',
    'stdout'                  => 0,
    'tag'                     => '',
    'user'                    => '',
    'version'                 => 0,
    'wait'                    => '',
    'scan-homedirs'           => 0,
    'www-ip'                  => undef,
    'www-trust-localhost'     => 1
};

sub new {
    my ($class, $params) = @_;

    my $self = $default;
    bless $self, $class;

    $self->_loadDefaults();

    if ($OSNAME eq 'MSWin32') {
        $self->_loadFromWinRegistry();
    } else {
        $self->_loadFromCfgFile();
    }

    $self->_loadUserParams();
    $self->_loadCallerParams($params) if $params;

    $self->_checkContent();

    return $self;
}

sub _loadDefaults {
    my ($self) = @_;

    foreach my $key (keys %$default) {
        $self->{$key} = $default->{$key};
    }
}

sub _loadCallerParams {
    my ($self, $params) = @_;

    foreach my $key (keys %$params) {
        $self->{$key} = $params->{$key};
    }
}

sub _loadFromWinRegistry {
    my ($self) = @_;

    eval {
        require Encode;
        Encode->import('encode');
        require Win32::TieRegistry;
        Win32::TieRegistry->import(
            Delimiter   => "/",
            ArrayValues => 0
        );
    };
    if ($EVAL_ERROR) {
        print "[error] $EVAL_ERROR";
        return;
    }

    my $machKey = $Win32::TieRegistry::Registry->Open(
        "LMachine", {
            Access    => Win32::TieRegistry::KEY_READ(),
            Delimiter => "/"
        }
    );
    my $settings = $machKey->{"SOFTWARE/FusionInventory-Agent"};

    foreach my $rawKey (keys %$settings) {
        next unless $rawKey =~ /^\/(\S+)/;
        my $key = $1;
        my $val = $settings->{$rawKey};
        # Remove the quotes
        $val =~ s/\s+$//;
        $val =~ s/^'(.*)'$/$1/;
        $val =~ s/^"(.*)"$/$1/;
        $self->{lc($key)} = $val;
    }
}

sub _loadFromCfgFile {
    my ($self) = @_;

    $self->{etcdir} = [];

    my $file;

    my $in;
    foreach (@ARGV) {
        if (!$in && /^--conf-file=(.*)/) {
            $file = $1;
            $file =~ s/'(.*)'/$1/;
            $file =~ s/"(.*)"/$1/;
        } elsif (/^--conf-file$/) {
            $in = 1;
        } elsif ($in) {
            $file = $_;
            $in = 0;
        } else {
            $in = 0;
        }
    }

    push (@{$self->{etcdir}}, '/etc/fusioninventory');
    push (@{$self->{etcdir}}, '/usr/local/etc/fusioninventory');

    if (!$file || !-f $file) {
        foreach (@{$self->{etcdir}}) {
            $file = $_.'/agent.cfg';
            last if -f $file;
        }
        return unless -f $file;
    }

    my $handle;
    if (!open $handle, '<', $file) {
        warn "Config: Failed to open $file: $ERRNO";
        return;
    }

    $self->{'conf-file'} = $file;

    while (<$handle>) {
        s/#.+//;
        if (/([\w-]+)\s*=\s*(.+)/) {
            my $key = $1;
            my $val = $2;
            # Remove the quotes
            $val =~ s/\s+$//;
            $val =~ s/^'(.*)'$/$1/;
            $val =~ s/^"(.*)"$/$1/;
            $self->{$key} = $val;
        }
    }
    close $handle;
}

sub _loadUserParams {
    my ($self) = @_;

    Getopt::Long::Configure( "no_ignorecase" );

    my @options = (
        'backend-collect-timeout=s',
        'basevardir=s',
        'ca-cert-dir=s',
        'ca-cert-file=s',
        'conf-file=s',
        'daemon|d',
        'daemon-no-fork|D',
        'no-fork',
        'debug',
        'delaytime=s',
        'devlib',
        'force|f',
        'format=s',
        'help|h',
        'info|i',
        'lazy',
        'local|l=s',
        'logger=s',
        'logfile=s',
        'logfile-maxsize=i',
        'nosoft',
        'nosoftware',
        'no-ocsdeploy',
        'no-inventory',
        'no-printer',
        'no-socket',
        'no-www',
        'no-soft',
        'no-software',
        'no-ssl-check',
        'no-wakeonlan',
        'no-snmpquery',
        'no-netdiscovery',
        'password|p=s',
        'proxy|P=s',
        'realm|r=s',
        'rpc-ip=s',
        'rpc-trust-localhost',
        'remotedir|R=s',
        'scan-homedirs',
        'share-dir=s',
        'server|s=s',
        'stdout',
        'tag|t=s',
        'user|u=s',
        'version',
        'wait|w=s',
        'www-ip=s',
        'www-trust-localhost',
    );

    push(@options, 'color') if $OSNAME ne 'MSWin32';

    GetOptions(
        $self,
        @options
    ) or $self->help();

}

sub _checkContent {
    my ($self) = @_;

    # if a logfile is defined, use file logger
    if ($self->{logfile}) {
        $self->{logger} = 'File';
    }

    if ($self->{realm}) {
        print STDERR
            "the parameter --realm is deprecated, and will be ignored\n";
    }

    if (defined $self->{'no-socket'}) {
        print STDERR
            "the parameter --no-socket is deprecated, use --no-www instead\n";
        $self->{'no-www'} = $self->{'no-socket'};
    }

    if (defined $self->{'rpc-ip'}) {
        print STDERR
            "the parameter --rpc-ip is deprecated, use --www-ip instead\n";
        $self->{'www-ip'} = $self->{'rpc-ip'};
    }

    if (defined $self->{'rpc-trust-localhost'}) {
        print STDERR
            "the parameter --rpc-trust-localhost is deprecated, use --www-trust-localhost instead\n";
        $self->{'www-trust-localhost'} = $self->{'rpc-trust-localhost'};
    }

    if ($self->{'daemon-no-fork'}) {
        print STDERR
            "the parameter --daemon-no-fork is deprecated, use --daemon --no-fork instead\n";
        $self->{daemon} = 1;
        $self->{'no-fork'} = 1;
    }

    if ($self->{'share-dir'}) {
        $self->{'share-dir'} = abs_path($self->{'share-dir'});
    } else {
        if ($self->{devlib}) {
            $self->{'share-dir'} = abs_path('./share/');
        } else {
            eval { 
                require File::ShareDir;
                $self->{'share-dir'} =
                    File::ShareDir::dist_dir('FusionInventory-Agent');
            };
        }
    }

    # We want only canonical path
    $self->{basevardir} =
        abs_path($self->{basevardir}) if $self->{basevardir};
    $self->{'conf-file'} =
        abs_path($self->{'conf-file'}) if $self->{'conf-file'};
    $self->{'ca-cert-file'} =
        abs_path($self->{'ca-cert-file'}) if $self->{'ca-cert-file'};
    $self->{'ca-cert-dir'} =
        abs_path($self->{'ca-cert-dir'}) if $self->{'ca-cert-dir'};
    # On Windows abs_path fails if the file doesn't exist yet.
    # Win32::GetFullPathName is ok.
    if ($self->{'logfile'}) {
        $self->{'logfile'} = $OSNAME eq 'MSWin32' ?
            Win32::GetFullPathName($self->{'logfile'}) :
            abs_path($self->{'logfile'});
    }
}

sub help {
    my ($self) = @_;

    my $help;

    if ($self->{'conf-file'}) {
        $help .= <<EOF
Setting initialised with values retrieved from the config found at $self->{'conf-file'}
EOF
    }

    $help .= <<EOF;
Target selection options:
    -s --server=URI     server uri, e.g: http://server/ocsinventory ($self->{server})
    -l --local=DIR      write inventory in DIR
    --stdout            print inventory on STDOUT

Task disabling options:
    --no-inventory      do not use inventory task ($self->{'no-inventory'})
    --no-wakeonlan      do not use wakeonlan task ($self->{'no-wakeonlan'})
    --no-snmpquery      do not use snmpquery task ($self->{'no-snmpquery'})
    --no-netdiscovery   do not use snmpquery task ($self->{'no-netdiscovery'})
    --no-ocsdeploy      do not use deployment task ($self->{'no-ocsdeploy'})

Inventory task specific options:
    --no-printer        do not return printer list in inventory $self->{'no-printer'})
    --no-software       do not return installed software list ($self->{'no-software'})
    --scan-homedirs     permit to scan home user directories ($self->{'scan-homedirs'})
    --backend-collect-timeout set a max delay time of one inventory data
                        collect job ($self->{'backend-collect-timeout'})

Network connection options:
    -p --password=PWD   password for server auth
    -P --proxy=PROXY    proxy address. e.g: http://user:pass\@proxy:port ($self->{proxy})
    -u --user           user name to use for server auth
    --ca-cert-dir=D     SSL certificat directory ($self->{'ca-cert-dir'})
    --ca-cert-file=F    SSL certificat file ($self->{'ca-cert-file'})
    --no-ssl-check      do not check the SSL connexion with the server ($self->{'no-ssl-check'})


Web interface options:
    --no-www            do not use web interface ($self->{'no-www'})
    --www-ip=IP         network interface to listen to
    --www-trust-localhost      trust local requests without token

Logging options:
    --logfile=FILE      log message in FILE ($self->{logfile})
    --logfile-maxsize=X max size of the log file in MB ($self->{'logfile-maxsize'})
    --logger            logger you want to use (Stderr, File or Syslog) ($self->{logger})
    --color             use color in the console ($self->{color})
    --logfacility       syslog facility to use

Setup options:
    --basevardir=DIR    indicate the directory where should the agent store its
                        files ($self->{basevardir})
    --share-dir=DIR     path to the directory where are stored the shared files
                        ($self->{'share-dir'})
    --devlib            search for Backend mod in ./lib only ($self->{devlib})

Extra options:
    -d --daemon         detach the agent in background ($self->{daemon})
    --no-fork           don't fork in background ($self->{'no-fork'})
    --delaytime         set a max delay time (in second) if no PROLOG_FREQ is
                        set ($self->{delaytime})
    -f --force          always send data to server (Don't ask before) ($self->{force})
    -i --info           verbose mode ($self->{info})
    --debug             debug mode ($self->{debug})
    --lazy              do not contact the server more than one time during the
                        PROLOG_FREQ ($self->{lazy})
    -t --tag=TAG        use TAG as tag ($self->{tag})
    -w --wait=DURATION  wait during a random periode between 0 and DURATION
                        seconds before contacting server ($self->{wait})
    --format            export format (HTML or XML) ($self->{format})
    --version           print the version

Manpage:
    See man fusioninventory-agent

FusionInventory-Agent is released under GNU GPL 2 license
EOF

    if ($OSNAME eq 'MSWin32') {
        $help =~ s/.*--color.*\n//;
    }

    print STDERR $help;
}

1;

__END__

=head1 NAME

FusionInventory::Agent::Config - Agent configuration

=head1 DESCRIPTION

This is the object used by the agent to store its configuration.

=head1 METHODS

=head2 new($params)

The constructor. All configuration parameters can be passed.

=head2 help()

Display usage instructions on stderr.
