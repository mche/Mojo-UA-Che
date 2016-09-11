use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', max_try=>5);
my $base_url = 'https://metacpan.org/pod/';
my @modules = qw(Scalar::Util Mojolicious Mojo::Pg Mojo::Pg::Che DBI DBD::Pg DBIx::Mojo::Template AnyEvent);
my $limit = 3;
my $total = @modules;

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at('ul.slidepanel > li time[itemprop="dateModified"]')->text;
  
}

my @success = ();

while (@modules) {
  my @mod = splice @modules, 0, $limit;
  say STDERR "BATCH: @mod";
  my @res = $ua->batch(map ['get', $base_url.$_], @mod);
  for my $res (@res) {
    my $mod = shift @mod;
    unshift @modules, $mod
      and next
      unless  ref $res;
    push @success, "$mod modified: ".process_res($res);
  }
}

say STDERR 'DONE ', $_ for @success;

is scalar @success, $total;

done_testing();