# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;

=head1 NAME

TransMan - a gay translation manager to manage our forked translation files

=DESCRIPTION

Imports .po-files from Koha to our version control, also updating translation key changes to .po-files
Exports our translation to Koha
Installs new languages to Koha, so they are available to Koha's language management tools.

Due to our rolling way of pushing new updates, we cannot keep the translation files under the same version control repository as Koha.
This would make git history very cumbersome.
This script manages the translation files we maintain ourselves in another git repo.

=cut

use Params::Validate qw(:all);
use IPC::Cmd;
use Cwd;
use Git;

use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger');

use TransMan::POs;
use TransMan::Filters;
use TransMan::Importer;
use TransMan::Exportain;
use TransMan::Installer;

=item new

  my $tm = new TransMan({
    kohaPoFilesDir => $ENV{KOHA_PATH}.'/misc/translator/po',                              #Where to install .po-files
    kohaTranslationsPoDir => $ENV{KOHA_PATH}.'/misc/translator/Koha-translations/po',     #From where to pull our translated files
    dryRun => 1||0,                                                                       #Do stuff or just report what would be done?
    languages => ['fi'],                                                                  #Language code, just like they are in the .po-files' Language-metafield
    projects => ['17.05'],                                                                #Project code, just like they are in the Pootle project url
    credentials => 'username:password'||'credentials.txt'                                 #Credentials to login to Pootle-server, mandatory if installing/downloading .po-files
    baseUrl => 'http://translate.pootle.com',                                             #url to the Pootle server we are downloading translation files from
  });

TODO:: support for multiple languages and projects doesn't really work in practice. It is better to just pass single values and run this module multiple times for different
combinations of language and project

=cut

sub new($class, @params) {
  $l->debug("New ".$class.": ".$l->flatten(@params)) if $l->is_debug();
  my %self = validate(@params, {
    kohaPoFilesDir => 1,
    kohaTranslationsPoDir => 1,
    dryRun    => 1,
    languages => { type => ARRAYREF },
    projects  => { type => ARRAYREF },
    credentials => 0,
    baseUrl     => 0,
  });

  my $s = \%self;
  bless($s, $class);

  $s->{kohaTranslationsGitRepoDir} = $s->{kohaCleanedPoDir};
  $s->{kohaTranslationsGitRepo}    = Git->repository(Directory => $s->{kohaCleanedPoDir});

  bless($s, __PACKAGE__);
  return $s;
}
sub kohaPoFilesDir($s)           { return $s->{kohaPoFilesDir} };
sub kohaTranslationsPoDir($s)    { return $s->{kohaTranslationsPoDir} };
sub dryRun($s)                   { return $s->{dryRun} };
sub languages($s)                { return $s->{languages} };
sub projects($s)                 { return $s->{projects} };
sub credentials($s)              { return $s->{credentials} };
sub baseUrl($s)                  { return $s->{baseUrl} };


=item makeLanguageFilter

=cut

sub makeLanguageFilter($s) {
  my @langs = map {"($_)"} @{$s->languages};
  my $regexp = join('|',@langs);
  $regexp = qr/^$regexp$/; #  qr/^(fi-FI)|(sv)|(ru-RU)/
  my %filters = ( Language => $regexp);
  return new TransMan::Filters({filters => \%filters});
}

=item validatePo

=cut

sub validatePo {
  my ($self, $outFile) = @_;
  my $msgcatalogTempFile = '/tmp/messages.mo';

  try {
    my $output = $self->_shell('/usr/bin/msgfmt', '-c', '-o', $msgcatalogTempFile, $outFile); #Does most possible validity checks
    $l->warn("\n".
             "##################################\n".
             "## .po-file validation warnings ##\n".
             "##################################\n".
             $output."\n".
             "##################################\n".
             "##  end of validation warnings  ##\n".
             "##################################\n".
    "") if $output;
  } catch {
    $l->logdie("\n".
               "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n".
               "!! .po-file validation errors !!\n".
               "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n".
               $_."\n".
               "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n".
               "!!  end of validation errors  !!\n".
               "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n".
    "");
  };
  unlink $msgcatalogTempFile;
}

=item exportPOs

Overwrite Koha's .po-files with these

=cut

sub exportPOs($s) {
  return TransMan::Exportain::exportPOs($s);
}

=item importPOs

Import Koha's .po-files to version control, along with all code updates.

=cut

sub importPOs($s) {
  return TransMan::Importer::importPOs($s);
}

=item installPOs

Download new .po-files to Koha, making them available for Koha's translation tools

 @PARAM1 Boolean, force downloading .po-files over existing ones.
 @RETURNS ARRAYRef of TransMan::PO, files just downloaded

=cut

sub installPOs($s, $force) {
  return TransMan::Installer::installPOs($s, $force);
}










=head2 _shell

Execute a shell program, and collect results extensively, dying if trooble

=cut

sub _shell {
  my ($self, $program, @params) = @_;
  my $programPath = IPC::Cmd::can_run($program) or die "$program is not installed!";
  my $cmd = "$programPath @params";

  if ($self->dryRun) {
    print "$cmd\n";
    return '';
  }
  else {
    my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
        IPC::Cmd::run( command => $cmd, verbose => 0 );
    my $exitCode = ${^CHILD_ERROR_NATIVE} >> 8;
    my $killSignal = ${^CHILD_ERROR_NATIVE} & 127;
    my $coreDumpTriggered = ${^CHILD_ERROR_NATIVE} & 128;
    $l->logdie("Shell command: $cmd\n  exited with code '$exitCode'. Killed by signal '$killSignal'.".(($coreDumpTriggered) ? ' Core dumped.' : '')."\nERROR MESSAGE: $error_message\nSTDOUT:\n@$stdout_buf\nSTDERR:\n@$stderr_buf\nCWD:".Cwd::getcwd())
        if $exitCode != 0;
    $l->debug("=====SHELL DUMP===============\nCMD: $cmd\nERROR MESSAGE: ".($error_message // '')."\nSTDOUT:\n@$stdout_buf\nSTDERR:\n@$stderr_buf\nCWD:".Cwd::getcwd()."\n===============SHELL DUMPED===");
    return "@$full_buf";
  }
}

1;
