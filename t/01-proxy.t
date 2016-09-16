use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;


my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::Mojo DBI utf8 strict warnings);
#~ my $dom_select = '#NAME ~ p';
my $dom_select = 'head title';
my $limit = 2;
my $delay = Mojo::IOLoop->delay;
my @done = ();

#~ $delay->on(finish => sub {say STDERR "\t\tDELAY FINISH";});

#~ 

sub test {
  my $che = shift;
  my $total = @modules;
  #~ $delay->on(finish => $delay->begin)
    #~ if $limit ==1; #);
  start($che) for 1..$limit;
  $delay->wait;
  say STDERR 'Module ', $_ for @done;

  is scalar @done, $total, 'proxying good';
  
  pass $base_url;
  
}

my $che = Mojo::UA::Che->new(proxy_module_has=>{max_try=>5, debug=>0,}, debug=>1, cookie_ignore=>1);

subtest 'mojolicious.org' => \&test, $che;

#~ pass 'proxying';

$base_url = 'https://metacpan.org/pod/';
@modules = qw(Scalar::Util Mojolicious Mojo::Pg Test::More DBI DBD::Pg AnyEvent);
@done = ();
#~ $limit = 3;

subtest 'metacpan.org' => \&test, $che;#->proxy_module(undef);

sub start {
  my $ua = shift;# || $ua->dequeue;
  my $module = shift() || shift @modules
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $ua->get( $url => sub {
    my ($mua, $tx) = @_;
    my $res = $tx->{_res} || $ua->process_tx($tx,);
    say STDERR "DONE: [$module]\t", $tx->req;
    push @done, process_res($res);
    #~ $end->();
    start($ua);
    #~ say STDERR "EXIT START CB";
    $end->();
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at($dom_select)->text;
  
}

done_testing();

