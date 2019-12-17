#!/usr/bin/perl -w

use Test::More tests => 3;     #  qw(no_plan);
use FindBin qw($Bin);
BEGIN
{
    my $installdir = $ENV{'installdir'} || "/a";
    unshift(@INC, "$installdir/extlib/lib/perl5");
    unshift(@INC, "$installdir/extlib/lib/perl5/x86_64-linux-gnu-thread-multi/");
    unshift(@INC, "$installdir/lib");
    unshift(@INC, "$installdir/t/common/lib");
    unshift(@INC, "$installdir/t/unit/lib");
}

use Test::Common::Hub;
use Getopt::Long;
use Conf::Yaml;

#### SET DUMPFILE
my $dumpfile    =   "$Bin/../../../../dump/create.dump";

#### SET CONF FILE
my $installdir  =   $ENV{'installdir'} || "/a";
my $configfile    =   "$installdir/conf/config.yml";

#### SET $Bin
$Bin =~ s/^.+t\/bin/$installdir\/t\/unit\/bin/;

#### SET LOG
my $log     =   2;
my $printlog    =   5;
my $logfile     =   "$Bin/outputs/install.log";

#### GET OPTIONS
my $pwd = $Bin;
my $login;
my $showreport = 1;
my $token;
my $password;
my $keyfile;
my $help;
GetOptions (
    'log=i'     => \$log,
    'printlog=i'    => \$printlog,
    'login=s'       => \$login,
    'showreport=s'  => \$showreport,
    'token=s'       => \$token,
    'password=s'    => \$password,
    'keyfile=s'     => \$keyfile,
    'help'          => \$help
) or die "No options specified. Try '--help'\n";
usage() if defined $help;

#### LOAD LOGIN, ETC. FROM ENVIRONMENT VARIABLES
$login      =   $ENV{'login'} if not defined $login or not $login;
$token      =   $ENV{'token'} if not defined $token;
$password   =   $ENV{'password'} if not defined $password;
$keyfile    =   $ENV{'keyfile'} if not defined $keyfile;

if ( not defined $login or not defined $token
    or not defined $keyfile ) {
    plan 'skip_all' => "Missing login, token or keyfile. Run this script manually and provide GitHub login and token credentials and SSH private keyfile";
}

my $whoami = `whoami`;
$whoami =~ s/\s+//g;
print "Hub.t    Must run as root\n" and exit if $whoami ne "root";

my $conf = Conf::Yaml->new(
    memory      =>  1,
    inputfile	=>	$configfile,
    log     =>  2,
    printlog    =>  2,
    logfile     =>  $logfile
);

my $username = $conf->getKey("database:TESTUSER");

my $object = new Test::Common::Hub (
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile,
    dumpfile    =>  $dumpfile,
    conf        =>  $conf,
    showreport  =>  $showreport,
    pwd         =>  $pwd,
    username    =>  $username,
    
    login       =>  $login,
    token       =>  $token,
    password    =>  $password,
    keyfile     =>  $keyfile
);


#### TEST GET HUB
$object->testGetHub();

#### TEST ADD HUB TOKEN
$object->testAddRemoveHubToken();

#### CLEAN UP
`rm -fr $Bin/outputs/*`
