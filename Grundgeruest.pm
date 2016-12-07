package Kernel::System::PostMaster::Filter::Junk;

use strict;

our @ObjectDependencies = (
    'Kernel::System::Log', # und weitere Objekte
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    # und weitere Objekte

    # TicketID wird bei Post-Filtern benötigt
    for my $Needed (qw(JobConfig GetParam TicketID)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    return 1;
}

1;

