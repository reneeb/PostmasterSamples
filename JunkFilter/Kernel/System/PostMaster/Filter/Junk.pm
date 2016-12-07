# --
# Kernel/System/PostMaster/Filter/Junk.pm - the global PostMaster module for OTRS
# Copyright (C) 2011 - 2014 Perl-Services.de, http://perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::Junk;

use strict;

our $VERSION = 0.03;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Email',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
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

    for my $Needed (qw(JobConfig GetParam)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    $LogObject->Log(
        Priority => 'notice',
        Message  => 'TicketID: ' . $Param{TicketID},
    );
  
    my $IsJunk = 0;

    TYPE: 
    for my $Type (qw(From Subject Body)) {
        my @Regexes = @{ $ConfigObject->Get( 'JunkFilter::' . $Type ) || [] };

        next TYPE if !@Regexes;

        my $RegexString = join '|', @Regexes;
        my $RegexObject;
        my $RegexFailure = 0;

        eval { $RegexObject = qr/($RegexString)/; 1; } or $RegexFailure = $@;

        if ( $RegexFailure ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Type: $Type -> Error: $@",
            );

            next TYPE;
        }

        if ( $Param{GetParam}->{$Type} =~ $RegexObject ) {
            $IsJunk = 1;
            $LogObject->Log(
                Priority => 'notice',
                Message  => "Junk ticket $Param{TicketID}: Match -> $1, Type -> $Type",
            );

            last TYPE;
        }
    }

    return 1 if !$IsJunk;

    my $Action = $ConfigObject->Get( 'JunkFilter::Action' );

    if ( $Action eq 'Move' ) {
        my $Queue = $ConfigObject->Get( 'JunkFilter::Queue' );
        my $State = $ConfigObject->Get( 'JunkFilter::State' );

        $Param{GetParam}->{'X-OTRS-Queue'} = $Queue;
        $Param{GetParam}->{'X-OTRS-State'} = $State;
    }
    else {
        $Param{GetParam}->{'X-OTRS-Ignore'} = 'yes';
    }

    return 1;
}

1;

