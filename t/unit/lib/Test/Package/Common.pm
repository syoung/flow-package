package Test::Package::Common;
use Moose::Role;
use Method::Signatures::Simple;

with 'Package::Main';
with 'Test::Table';
with 'Test::Common';
with 'Table::Main';
with 'Util::Logger';
with 'Table::Project';
with 'Table::Workflow';
with 'Web::Group::Privileges';
with 'Table::Stage';
with 'Table::App';
with 'Table::Parameter';
with 'Table::Common';
with 'Util::Main';

if ( 1 ) {
use Data::Dumper;
use Test::More;
use Test::DatabaseRow;
use DBase::Factory;
use Ops::Main;
use Engine::Instance;
use Conf::Yaml;
use FindBin qw($Bin);

# Int
has 'validated'		=> ( isa => 'Int', is => 'rw', default => 0 );

# String
has 'remoterepo'	=> ( isa => 'Str|Undef', is => 'rw' );
has 'sourcedir'		=> ( isa => 'Str|Undef', is => 'rw' );
has 'dumpfile'		=> ( isa => 'Str|Undef', is => 'rw' );
has 'rootpassword'  => ( isa => 'Str|Undef', is => 'rw' );
has 'dbuser'        => ( isa => 'Str|Undef', is => 'rw' );
has 'dbpass'        => ( isa => 'Str|Undef', is => 'rw' );

# Object
has 'json'			=> ( isa => 'HashRef', is => 'rw', required => 0 );
has 'head' 	=> (
	is =>	'rw',
	'isa' => 'Engine::Instance',
	default	=>	sub { Engine::Instance->new();	}
);
has 'master' 	=> (
	is =>	'rw',
	'isa' => 'Engine::Instance',
	default	=>	sub { Engine::Instance->new();	}
);

has 'ops' 	=> (
	is 		=>	'rw',
	isa 	=>	'Ops::Main',
	default	=>	sub { Ops::Main->new();	}
);

has 'conf' 	=> (
	is =>	'rw',
	isa => 'Conf::Yaml',
	default	=>	sub { Conf::Yaml->new(	memory	=>	1	);	}
);


}

method BUILD ($hash) {
	$self->logDebug("");
	
	if ( defined $self->logfile() ) {
		$self->head()->ops()->logfile($self->logfile());
		$self->head()->ops()->keyfile($self->keyfile());
		$self->head()->ops()->log($self->log());
		$self->head()->ops()->printlog($self->printlog());
	}
}

method copyDirs {
    $self->logDebug("");
	
	#### COPY OPSDIR AFRESH
	my $sourcedir	= "$Bin/inputs/repos";
	my $targetdir	= "$Bin/outputs/repos";
	$self->setUpDirs($sourcedir, $targetdir);
}

method cleanUpDirs {
#### CLEAN UP TARGET DIR
    $self->logDebug("");
	
	my $targetdir	= "$Bin/outputs/biorepository";
	`rm -fr $targetdir/*`;
}

method setSession ($login, $sessionid) {
	#### SET SESSION ID
	$self->sessionid($sessionid);

	#### INSERT USERNAME AND SESSION ID INTO DATABASE
	my $query = "SELECT 1 FROM sessions where username='$login' and sessionid='$sessionid'";
	my $present = $self->db()->query($query);
	if ( not $present ) {
		$query = qq{INSERT INTO sessions VALUES ('$login', '$sessionid', NOW())};
		$self->logDebug("query", $query);
		$self->db()->do($query);
	}	
}

#### REPOS
method setUpRepo {
	$self->branch("master");
	$self->repository("testversion");
	$self->package("testversion");
	$self->opsdir("$Bin/inputs/ops");
	$self->installdir("$Bin/outputs/target");	
	$self->sourcedir("$Bin/outputs/source");
	$self->privacy("public");
	
	$self->logGroup("");
	
    #### REPO VARIABLES
    my $remoterepo  = $self->remoterepo();
    my $sourcedir   = $self->sourcedir();
    my $login    	= $self->login();
    my $repository  = $self->repository();
    my $hubtype    	= $self->hubtype();
    my $branch      = $self->branch();
    my $privacy     = $self->privacy();
    
    #### CREATE TEMPORARY REPOSITORY ON GITHUB
    $self->deleteRepo($login, $repository);
    $self->createPublicRepo($login, $repository);

	#### PREPARE DIRECTORY
	if ( -d $sourcedir ) {
		$self->logDebug("Removing contents of sourcedir: $sourcedir");
		`rm -fr $sourcedir/* $sourcedir/.git`;	
	} else {
		$self->logDebug("Creating sourcedir: $sourcedir");
		my $command = "mkdir -p $sourcedir";
		$self->logDebug("command", $command);
		`$command`;
		$self->logError("Can't create sourcedir", $sourcedir) and exit if not -d $sourcedir;
	}
	$self->logCritical("Can't create sourcedir: $sourcedir") and exit if not -d $sourcedir;
	
	#### POPULATE LOCAL REPO
    $self->populateRepo();

    #### SET REMOTE
    $self->changeToRepo($sourcedir);
	my $isremote = $self->isRemote($login, $repository, $branch);
	$self->logDebug("isremote", $isremote);
	$self->addRemote($login, "github", $branch) if not $isremote;	

	#### SET SSH KEYFILE
	my $keyfile 	= $self->keyfile();

	#### PUSH TO REMOTE
	$self->logDebug("PUSHING TO REMOTE");
    $self->pushToRemote($login, "github", "github", $branch, $keyfile, $privacy);
    $self->pushTags($login, "github", "github", $branch, $keyfile, $privacy);

	$self->logGroupEnd("");
}

method populateRepo {
	$self->logGroup("");

    my $login    	=   $self->login();
    my $repository  =   $self->repository();
    my $sourcedir   =   $self->sourcedir();
    
    #### CHANGE INTO REPO DIR 
    $self->changeToRepo($sourcedir);

    #### INITIALISE REPO
    $self->initRepo($sourcedir);
    
    #### ADD REMOTE
    $self->addRemote($login, $repository, "github");

    #### POPULATE REPO WITH FILES AND TAGS    
    for ( 1 .. 5 ) {
        $self->toFile("$sourcedir/0.$_.0", "tag 0.$_.0");
        $self->addToRepo();
        $self->commitToRepo("Commit 0.$_.0");
        $self->addLocalTag("0.$_.0", "TAG 0.$_.0");
    }

	$self->logGroupEnd("");
}

#### DATABASE
method testInsertData {
    my $hash = {
        username    =>  $self->conf()->getKey("database:TESTUSER"),
        owner       =>  $self->conf()->getKey("database:TESTUSER"),
        package 	=>  "apps",
		opsdir		=>	"$Bin/inputs/ops",
		installdir	=>	"$Bin/outputs/target",
        version     =>  "0.3"
    };

	my $table = "package";

	$self->insertData($table, $hash);
}




1;
