use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Metadata::ByInode',
    VERSION_FROM      => 'lib/Metadata/ByInode.pm', # finds $VERSION
    PREREQ_PM         => {
                'Carp'				=> '1', 
					 'DBI' => '1',
					 'DBD::SQLite'   => '1',
					 },
    EXE_FILES               => [qw(bin/mbi-find bin/mbi-index)],
);

