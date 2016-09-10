use Mojo::Base -strict;

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', max_try=>5);
my $base_url = 'https://metacpan.org/pod/';
my @modules = qw(Scalar::Util Mojolicious Mojo::Pg Mojo::Pg::Che DBI DBD::Pg DBIx::Mojo::Template AnyEvent);
#~ unshift @modules, 'http://foobaaar.com/';


=pod
my $cb = sub {
  my ($ua, $tx) = @_;
  my $success = $tx->success
    or die $tx->error->{message};
  my $code    = $tx->res->code;
  warn $ua, process_res($tx->res);
  Mojo::IOLoop->stop;
};

#~ my $res = $ua->request('get', $base_url . shift @modules);

#~ warn process_res($res);

$ua->request('get', $base_url . shift @modules, $cb) for 1..3;
Mojo::IOLoop->start;


=cut

my $delay = Mojo::IOLoop->delay;
my @success = ();
start() for 1..3;

$delay->wait;

warn $_ for @success;

sub start {
  my $module = shift() || shift @modules
    or return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  my $res = $ua->request('get'=> $url => sub {
    $end->();
    my ($mojo_ua, $tx) = @_;
    my $res = $ua->process_tx($tx, $mojo_ua);
    $ua->enqueue($mojo_ua);
    return start($module)
      unless  ref $res;
    push @success, "$module modified: ".process_res($res);
    #~ warn "$module modified: ", process_res($tx->res), $ua;
    #~ $end->();
    start();
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at('ul.slidepanel > li time[itemprop="dateModified"]')->text;
  
}





done_testing();