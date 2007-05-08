use Test::Simple qw 'no_plan';
use strict;
use lib './lib';
use Metadata::ByInode;
use Cwd;



my $m;
ok ( $m = new Metadata::ByInode({ abs_dbfile => './t/mbitest.db' }), 'object instanced' );



ok( $m->index(cwd), 'index cwd');


### search tests...

my $RESULT;
ok( $RESULT = $m->search({'filename:exact' => 'file2.x', abs_loc=> cwd().'/t' }),'search exact one key');
ok( $m->results_count == 1 );


ok( $RESULT = $m->search({'filename:like' => 'pm', abs_loc=> cwd().'/lib' }),'search one key');
### $RESULT

my $count = $m->results_count;
ok($count == 3,"results count $count should be 3 pm files");
#ok($count);
ok($RESULT = $m->search_results,'search results in array form');
### $RESULT

ok( $RESULT = $m->search({filename => 'Index', abs_loc=>cwd().'/lib'}),'search one key');
### $RESULT

#ok($m->results_count);
ok( $m->results_count == 1,'results count, 1 pm file');
ok( $RESULT = $m->search_results,'search results in array form');
### $RESULT

rmdir './t/haha';

ok((mkdir './t/haha'), 'make test dir');
open(FILE,">./t/haha/hahaha");
close FILE;
ok( $m->index(cwd), 're index');

$m->search({ filename => 'hahaha'});

ok($m->results_count == 1, 'one file matching');


# NEED TO WAIT FOR INDEXER TO TAKE OUT , to recognize as old.
sleep 1; # sleeps for 1 sec

ok((unlink './t/haha/hahaha'), 'del test dir' );
ok( $m->index(cwd), 're index');

my $srch= $m->search({ filename => 'hahaha'});
### $srch
ok( $m->results_count == 0 , 'no file matching');


rmdir './t/haha';


unlink './t/mbitest.db';


