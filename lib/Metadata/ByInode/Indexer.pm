package Metadata::ByInode::Indexer;
use warnings;
use strict;
use Carp;
use Cwd;
#use Smart::Comments '###';

our $VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)/g;

=pod

=head1 NAME

Metadata::ByInode::Indexer - customizable file and directory indexer

=head1 DESCRIPTION 

part of Metadata::ByInode
not meant to be used alone!

=head1 index()

First argument is an absolute file path.

If this is a dir, will recurse - NON inclusive
that means the dir *itself* will NOT be indexed

if it is a file, will do just that one.

returns indexed files count

by default the indexer does not index hidden files
to index hidden files,

 $m = new Metadata::ByInode::Indexer({ 
   abs_dbfile => '/tmp/mbi_test.db', 
   index_hidden_files => 1 
 });
 
 $m->index('/path/to/what'); # dir or file
 		

=cut

sub index {
	my $self = shift;
	my $arg = shift; $arg or croak('missing argument to index');

	### index start
	### $arg
	# if this is an inode, should we look up in the db already?? :)	
	my $abs_path = Cwd::abs_path($arg);

	$self->{index_hidden_files} ||=0;	

	
	# index hidden? follow symlinks?	
	my $files_indexed = 0;	
	#$self->dbh->do("DELETE FROM files WHERE abs_loc LIKE '$abs_path%'");
	# for ( split /\n/, `find -L $abs_path -mindepth 1 -printf "\%h:\%f:\%i\\n"` ){ # -L is to follow symlinks
	# TODO: use 'file find rule' from cpan instead.. 	
	# make sure if this is a dir, we use mindepth so we do NOT index itself
	my $mindepth = (-d $abs_path) ? '-mindepth 1' : '';
	my $ondisk = time;


	$self->_delete_treeslice($abs_path);

	# QUOTING!!!!
	for ( split /\n/, `find "$abs_path" $mindepth -printf "\%h##\%f##\%i\\n"` ){  #### Working===[%]     done
		
		$_=~/^([^#]+)##([^\/]+)##(\d+)/ or die("cant match abs loc and filename in [$_]");
		my ($abs_loc, $filename, $inode) = ($1, $2, $3);
	
		$self->_reset;

		unless( $self->{index_hidden_files} ){
#no Smart::Comments;
			if ($abs_loc=~/\/\./ or $filename=~/^\./){ next; } # /. anywhere
		}	
		
		
		$self->_set('abs_loc',$abs_loc);
		$self->_set('filename',$filename);
		$self->_set('ondisk',$ondisk);
		
		$self->index_extra;	

		$self->set($inode,$self->_record);
		$files_indexed++;
	}
	
		
	my $seconds_elapsed = int(time - $ondisk);
	### $seconds_elapsed
	### $files_indexed

	
	return $files_indexed;	
}


















sub _reset {
	my $self = shift;	
	$self->{_current_record} = undef;
	return 1;
}

sub _set {
	my $self = shift;	
	my ($key,$val)=(shift,shift); (defined $key and defined $val) 
		or croak("_set() missing [key:$key] or [val:$val]");
	$self->{_current_record}->{$key} = $val;
	return 1;
}

sub _record {
	my $self = shift;
	defined $self->{_current_record} or die($!);
	return $self->{_current_record};
}





sub index_extra {
	my $self = shift;	
	return 1;
}
=pod

=head1 CREATING YOUR OWN INDEXER

=head2 index_extra()

If you want to invent your own indexer, then this is the method to override.
For every file found, this method is run, it just inserts data into the record
for that file.
By default, all files will have 'filename', 'abs_loc', and 'ondisk', which is a
timestamp of when the file was seen (now).

for example, if you want the indexer to record mime types, you should override
the index_extra method as..

	package Indexer::WithMime;
	use File::MMagic;		
	use base 'Metadata::ByInode::Indexer';
	
	sub index_extra {
	
		my $self = shift;	
      
		# get hash with current record data
      my $record = $self->_record;      

		# by default, record holds 'abs_loc', 'filename', and 'ondisk'
      
	   # ext will be the distiction between dirs here
		if ($record->{filename}=~/\.\w{1,4}$/ ){ 
				
				my $m = new File::MMagic;
				my $mime = $m->checktype_filename( 
               $record->{abs_loc} .'/'. $record->{filename} 
            );
				
				if ($mime){ 
				   # and now we append to the record another key and value pair
					$self->_set('mime_type',$mime); 					
				}		
		}
	
		return 1;	
	}

Then in your script

	use Indexer::WithMime;

	my $i = new Indexer::WithMime({ abs_dbfile => '/home/myself/dbfile.db' });

	$i->index('/home/myself');

	# now you can search files by mime type residing somewhere in that dir

   $i->search({ mime_type => 'mp3' });

   #or 
   $i->search({ 
      mime_type => 'mp3',
      filename => 'u2',
   });

=head1 SEE ALSO

L<Metadata::ByInode> and L<Metadata::ByInode::Search>

=cut










# delete a slice of the indexed tree
sub _delete_treeslice {
	my $self = shift;
	my $arg = shift; $arg or croak('missing abs path arg to _delete_treeslice');
	my $ondisk = shift; #optional
	
	my $abs_path = Cwd::abs_path($arg);
	### recursive delete
	### $abs_path
	### $ondisk

	#delete by location AND by time
	if ($ondisk) { # if this was a dir
	# YEAH! IT WORKS !! :)
		### was dir, will get rid of sub not updt
		unless (defined $self->{_open_handle}->{recursive_delete_o}){	
			$self->{_open_handle}->{recursive_delete_o} = $self->dbh->prepare( 
			q{DELETE FROM metadata WHERE inode IN }
		 .q{(SELECT inode FROM metadata WHERE key='abs_loc' AND value LIKE ? AND inode IN }
		  .q{(SELECT inode FROM metadata WHERE key='ondisk' AND value < ?));"}) or croak( $self->dbh->errstr );
		}  
		
		$self->{_open_handle}->{recursive_delete_o}->execute("$abs_path%",$ondisk);
		my $rows_deleted_o = $self->{_open_handle}->{recursive_delete_o}->rows;
		### $rows_deleted_o
		$self->dbh->commit;	
			
	}

	# delete not by time
	else {	
		unless (defined $self->{_open_handle}->{recursive_delete}){	
			$self->{_open_handle}->{recursive_delete} = $self->dbh->prepare( 
				q{DELETE FROM metadata WHERE inode IN ( SELECT inode FROM metadata WHERE key='abs_loc' AND value LIKE ? )}
			) or croak( $self->dbh->errstr );
		}  
		
		$self->{_open_handle}->{recursive_delete}->execute("$abs_path%");
		my $rows_deleted = $self->{_open_handle}->{recursive_delete}->rows;
		### $rows_deleted	
		$self->dbh->commit;	
	}

	return 1;
}
=pod

=head1 AUTHOR

Leo Charre <leo@leocharre.com>

=cut

1;
