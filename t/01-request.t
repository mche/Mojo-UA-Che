use Mojo::Base -strict;

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', max_try=>5);
#~ my $base_url = 'https://metacpan.org/pod/';
#~ my @modules = qw(CHI 0DBI 0DBD::Pg 00DBIx::Mojo::Template 00AnyEvent Ado);
#~ my $css = 'ul.slidepanel > li time[itemprop="dateModified"]';
my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent DBI Mojo::Pg Data::Dumper ojo);
my $css = '#NAME ~ p';
my $limit = 3;
my $total = @modules;
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
$delay->on(finish => $delay->begin);
my @ua; push @ua, $ua->dequeue for 1..$limit;
#~ push @{$delay->data->{ua} ||= []}, 
my @success = ();
#~ my @end = ();
start($_) for @ua;

($delay->wait || 1) and warn "WAIT!!!!" while @success < $total;

warn $_ for @success;

sub start {
  my $mojo_ua = shift;
  my $module = shift || shift @modules
  #~ $delay->begin
    #~ and return
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $mojo_ua->get( $url => sub {
    $end->();
    my ($mua, $tx) = @_;
    my $res = $ua->process_tx($tx, $mua);
    #~ $end->();
    warn "AGAIN: [$module] $res"
      and return start($mua, $module)
      unless  ref $res || $res =~ /404/;
    push @success, "$module: ".process_res($res);
    start($mua);
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at($css)->text;
  
}





done_testing();