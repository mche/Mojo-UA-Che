use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;

plan skip_all => 'skiping: IO::Socket::SSL require'
  unless eval {require IO::Socket::SSL};

#~ plan skip_all => 'skiping: IO::Socket::Socks require'
  #~ unless eval {require IO::Socket::Socks};

plan skip_all => 'skiping: $ENV{Mojo_UA_Che_Config} require, see ./example/... configs'
  unless $ENV{Mojo_UA_Che_Config};

use Mojo::UA::Che;
use Mojolicious::Plugin::Config;

my $config = $ENV{Mojo_UA_Che_Config};

my $base_url = 'https://raw.githubusercontent.com/kraih/mojo/master/lib/Mojo/';
my @modules = qw(UserAgent.pm IOLoop.pm DOM.pm Asset.pm Util.pm Base.pm Home.pm);
my $limit = 1;
my $delay = Mojo::IOLoop->delay;
#~ $delay->on(error => sub {
  #~ my ($delay, $err) = @_;
  #~ say STDERR $err;
#~ });
my @done = ();
my $che = Mojo::UA::Che->new(%{Mojolicious::Plugin::Config->new->load($config)}, cookie_ignore=>1);

subtest 'github' => \&test;

sub test {
  my $total = @modules;
  #~ $delay->on(finish => $delay->begin)
    #~ if $limit ==1; #);
  request() for 1..$limit;
  $delay->wait;
  say STDERR 'Module ', $_ for @done;

  is scalar @done, $total, 'proxying good';
  
  pass $base_url;
  
}

sub request {
  my $module = shift() || shift @modules
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $che->get( $url => sub {
    my ($ua, $tx) = @_;
    #~ my $res = $tx->{_res} || $che->process_tx($tx,);
    
    say STDERR "DONE: [$module]";
    push @done, "$module=".process_res($tx->res);
    #~ push @done, $tx->res->code."\t".$tx->res->content->asset->size;
    request();
    #~ say STDERR "EXIT request CB";
    $end->();
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  my $size = $res->content->asset->size;
  $res->content->asset->move_to('/dev/null');
  return $size;
  
}

done_testing();

