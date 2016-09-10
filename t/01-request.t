use Mojo::Base -strict;

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', max_try=>5);
my $base_url = 'https://metacpan.org/pod/';
my @modules = qw(CHI 0DBI 0DBD::Pg 00DBIx::Mojo::Template 00AnyEvent Ado);
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
start() for 1..4;



$delay->wait and warn "WAIT!!!!" while @success < 6;

warn $_ for @success;

sub start {
  my $mojo_ua = shift || $ua->dequeue;
  my $module = shift || shift @modules
    || return;
  my $url = $base_url.$module;
  
  push @{$delay->data->{ua} ||= []}, $mojo_ua;
  #~ $delay->data($url=>);
  my $end = $delay->begin;
  $mojo_ua->get( $url => sub {
    #~ $end->();
    my ($mua, $tx) = @_;
    my $res = $ua->process_tx($tx, $mua);
    #~ $ua->enqueue($mua);
    #~ delete $delay->data->{$url};
    #~ pop @{$delay->data->{ua}};
    $end->();
    warn "AGAIN: [$module] $res"
      and return start($mua, $module)
      unless  ref $res || $res =~ /404/;
    push @success, "$module modified: ".process_res($res);
    #~ warn "$module modified: ", process_res($tx->res), $ua;
    #~ $end->();
    start($mua);
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at('ul.slidepanel > li time[itemprop="dateModified"]')->text;
  
}





done_testing();