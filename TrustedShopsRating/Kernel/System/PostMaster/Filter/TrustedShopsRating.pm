# --
# Kernel/System/PostMaster/Filter/TrustedShopsRating.pm - the global PostMaster module for OTRS
# Copyright (C) 2012 perl-services.de, http://perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::TrustedShopsRating;

use strict;
use Kernel::System::Ticket;

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    for my $Object (
        qw(ConfigObject LogObject DBObject TimeObject MainObject EncodeObject)
        )
    {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    $Self->{TicketObject} = Kernel::System::Ticket->new( %{$Self} );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(JobConfig GetParam)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Email = $Param{GetParam};

    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => 'TicketID: ' . $Param{TicketID},
    );

    my $EnvelopeTo = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::XEnvelopeTo' );
    my $Sender     = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::XSender' );
    my $Subjects   = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::Subjects' ) || [];

    return 1 if $Email->{'X-Sender'} ne $Sender;
    return 1 if $Email->{'X-Envelope-To'} !~ m{$EnvelopeTo};

    my $SubjectOk;

    SUBJECT:
    for my $Subject ( @{$Subjects} ) {
        if ( $Email->{Subject} =~ m{Subject} ) {
            $SubjectOk = 1;
            last SUBJECT;
        }
    }

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => 'mail headers matched',
    );

    my ($Attachment) = grep{ $_->{MimeType} eq 'text/html' }@{ $Email->{Attachment} };
    return 1 if !$Attachment;

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => 'Attachment found: ' . $Attachment->{Content},
    );

    my ($Rating) = $Attachment->{Content} =~ m{Gesamtbewertung: <b>(\d\.\d\d)/5</b> Sterne};

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => "Rating: $Rating",
    );

    return 1 if !$Rating;
 
    my $QueueName = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::Queue' );
    my $NewState  = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::State' );

    if ( $Rating eq '5.00' ) { 
        $QueueName = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::5Stars::Queue' ); 
        $NewState  = $Self->{ConfigObject}->Get( 'Filter::TrustedShops::5Stars::State' );
    }

    if ( $QueueName ) {
        $Self->{TicketObject}->TicketQueueSet(
            TicketID => $Param{TicketID},
            Queue    => $QueueName,
            UserID   => 1,
        );
    }

    if ( $NewState ) {
        $Self->{TicketObject}->TicketStateSet(
            TicketID => $Param{TicketID},
            State    => $NewState,
            UserID   => 1,
        );
    }

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => "$QueueName // $NewState",
    );

    return 1;
}

1;

