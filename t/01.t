use Mojo::Base -strict;

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new;

my @modules = qw(Mojolicious Mojo::Pg Mojo::Pg::Che DBI DBD::Pg DBIx::Mojo::Template AnyEvent);
my $base_url = 'https://metacpan.org/pod/';

my $res = $ua->request($base_url . shift @modules);

warn $res;

done_testing();