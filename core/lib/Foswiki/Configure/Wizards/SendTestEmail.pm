# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::SendTestEmail;

=begin TML

---++ package Foswiki::Configure::Wizards::SendTestEmail

Wizard to test email.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

# Use to disable stream redirection during $net->sendEmail. This is
# required because Foswiki::Net doesn't use the Foswiki::Sandbox :-(
use constant NOREDIRECT => 0;

# WIZARD
sub send {
    my ( $this, $reporter ) = @_;

    return 1 unless ( $Foswiki::cfg{EnableEmail} );

    # A non-null value is required for this to make sense
    return unless $this->getCfg();

    # Expand a couple of required config settings for
    # Foswiki::Net::sendEmail after making sure we can restore them.
    my $safe_smcf = $Foswiki::cfg{Email}{SmimeCertificateFile};
    Foswiki::Configure::Load::expandValue(
        $Foswiki::cfg{Email}{SmimeCertificateFile} );

    my $safe_smkf = $Foswiki::cfg{Email}{SmimeKeyFile};
    Foswiki::Configure::Load::expandValue( $Foswiki::cfg{Email}{SmimeKeyFile} );

    eval { _sendTestEmail( $Foswiki::cfg{WebMasterEmail}, $reporter ); };
    die $@ if $@;

    # Don't report these as changed - they are simply expansions
    $Foswiki::cfg{Email}{SmimeCertificateFile} = $safe_smcf;
    $Foswiki::cfg{Email}{SmimeKeyFile}         = $safe_smkf;
}

# Send a test email to the address in the value
sub _sendTestEmail {
    my ( $addrs, $reporter ) = @_;

    require Foswiki::Net;

    my $neterrors = '';
    my $stderr    = '';
    my $stdout    = '';

    {
        local $Foswiki::cfg{SMTP}{Debug} = 1;

        my $smimeHTMLText = << "NOTSMIME";

<p>You have not configured <b>Foswiki</b> to send S/MIME signed e-mail notifications.

<p>To assure your users of the authenticity of mail from <b>Foswiki</b>,
which often contains hyperlinks, you may wish to consider enabling
this feature.
NOTSMIME

        if ( $Foswiki::cfg{Email}{EnableSMIME} ) {
            my $smimeCert = '';
            if ( $Foswiki::cfg{Email}{SmimeCertificateFile} ) {
                $smimeCert =
"using the certificate in =$Foswiki::cfg{Email}{SmimeCertificateFile}=.";
            }
            else {
                $smimeCert =
"using a Foswiki self-signed or Foswiki-requested certificate.";
            }
            $smimeHTMLText = << "SMIME";
<p>You have configured <b>Foswiki</b> to send S/MIME signed e-mail notifications
$smimeCert

<p>This message should be signed with the certificate that you
selected.  Mail clients vary in how they present this; typically
they use a certificate or padlock icon.

<p>If this message is not signed or if the signature is invalid, check
the ={Email}{SmimeCertificateFile}=, ={Email}{SmimeKeyFile}=
and ={Email}{SmimeKeyPassword}= settings, as well as the system logs.
SMIME
        }

        my $smimePlainText = $smimeHTMLText;
        $smimePlainText =~ s/<[^>]*>//g;

        my $msg = << "MAILTEST";
From: "$Foswiki::cfg{WebMasterName}" <$Foswiki::cfg{WebMasterEmail}>
To: $addrs
Subject: Test of Foswiki e-mail to $addrs
Auto-Submitted: auto-generated
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="=_=0i0k0i0w0s0o0fXuOi0E0A"
Content-ID: <parta.08030205.07080409\@foswiki.org>

This is a multi-part message in MIME format.

--=_=0i0k0i0w0s0o0fXuOi0E0A
Content-Type: text/plain; charset=iso-8859-1; format=flowed
Content-Transfer-Encoding: 8bit

This is a test e-mail from Foswiki.  It is a slightly-modified copy
of an actual notification e-mail generated by the Foswiki topic change
notification system.  It is delivered in both plain text (what you
are viewing now) and HTML versions.  Your e-mail client determines
which version you view.
$smimePlainText
Successfully receiving and viewing this message indicates that
the destination e-mail address is active, and that the content
generated by Foswiki is not disturbed by any e-mail filters or
mail transport system barriers that may be present.

The sample notification follows. (Note that although the hyperlinks
in the message are active, the topic mentioned does not exist.):

--------------------------------------------------------------

This is an automated e-mail from Foswiki.

New or changed topics in Foswiki.Development, since 04 Nov 2012 - 12:40:

- SampleTopicName (SampleUser, 04 Nov 2012 - 23:16) r31->r32
http://foswiki.org/Development/ASampleTopic


Review recent changes in:
  http://foswiki.org/Development/WebChanges

Subscribe / Unsubscribe in:
  http://foswiki.org/Development/WebNotify

--=_=0i0k0i0w0s0o0fXuOi0E0A
Content-Type: multipart/related;
 boundary="------------010706080204060506050309"


--------------010706080204060506050309
Content-Type: text/html; charset=iso-8859-1
Content-Transfer-Encoding: 8bit
Content-ID: <partb.08030205.07080409\@foswiki.org>

<img src="cid:part1.08030205.07080409\@foswiki.org" alt="Powered by
      Foswiki, The Free and Open Source Wiki" style="border:none;"
      border="0"><br>
<h2>This is a test e-mail from Foswiki.</h2>  It is a slightly-modified copy
of an actual notification e-mail generated by the <b>Foswiki</b> topic change
notification system.  It is delivered in both HTML (what you
are viewing now) and plain text versions.  Your e-mail client determines
which version you view.
$smimeHTMLText
<p>Successfully receiving and viewing this message indicates that
the destination e-mail address is active, and that the content
generated by <b>Foswiki</b> is not disturbed by any e-mail filters or
mail transport system barriers that may be present.
<p>The sample notification follows. (Note that although the hyperlinks
in the message are active, the topic mentioned does not exist.):
<hr>
<h2>This is an automated e-mail from Foswiki.</h2>
<p>
<em>New or changed topics in Foswiki.Development, since 04 Nov 2012 - 12:40:</em>
</p>
<table width="100%" border="0" cellpadding="0" cellspacing="4" summary="Changes">
<tr bgcolor="#B9DAFF">
  <td width="50%">
    <b>Topics in Development web:</b>
  </td><td width="30%">
    <b>Changed:</b> (now 00:15)
  </td><td width="20%">
    <b>Changed by:</b>
  </td>
</tr>
<tr>
  <td width="50%">
    <a href="http://foswiki.org/Development/ASampleTopic"><b>ASampleTopic</b></a>
  </td><td width="30%">
    <a href="http://foswiki.org/bin/rdiff/Development/ASampleTopic?rev2=31&amp;rev1=32" rel='nofollow'>04 Nov 2012 - 23:16</a> - r31-&gt;r32
  </td><td width="20%">
    <a href="http://foswiki.org/Main/SampleUser">Sample Wiki User</a>
  </td>
</tr>
<tr>
  <td colspan="2">
    <font size="-1">
     This would include a few lines from the topic that changed.<br /><ins>   This indicates text that was added.</ins><br /><del>And this text was deleted</del>

<br />   Main.SampleUser   04 Nov 2012 </font>
  </td><td width="20%">
    &nbsp;
  </td>
</tr></table>
<br clear="all" />
<p>Review recent changes in:
  <a href="http://foswiki.org/Development/WebChanges">http://foswiki.org/Development/WebChanges</a> </p>

<p>Subscribe / Unsubscribe in:
  <a href="http://foswiki.org/Development/WebNotify">http://foswiki.org/Development/WebNotify</a> </p>


--------------010706080204060506050309
Content-Type: image/png;
 name="foswiki-logo.png"
Content-Transfer-Encoding: base64
Content-ID: <part1.08030205.07080409\@foswiki.org>
Content-Disposition: inline;
 filename="foswiki-logo.png"

iVBORw0KGgoAAAANSUhEUgAAAHsAAAAoCAYAAADe3YUmAAAAGXRFWHRTb2Z0d2FyZQBBZG9i
ZSBJbWFnZVJlYWR5ccllPAAAAyRpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tl
dCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1l
dGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUu
MC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1NzowMSAgICAgICAgIj4gPHJkZjpS
REYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgt
bnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8v
bnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNv
bS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEu
MC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9w
IENTNS4xIE1hY2ludG9zaCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo4NjUxQkZGQTBD
OTMxMUUyODU3M0Q2QkQxM0YwNzgxQSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDo4NjUx
QkZGQjBDOTMxMUUyODU3M0Q2QkQxM0YwNzgxQSI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJl
ZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjg2NTFCRkY4MEM5MzExRTI4NTczRDZCRDEzRjA3ODFB
IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjg2NTFCRkY5MEM5MzExRTI4NTczRDZCRDEz
RjA3ODFBIi8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8
P3hwYWNrZXQgZW5kPSJyIj8+qGVOFQAAC45JREFUeNrsWwtwFPUZ//ZySS7JBRJCCA8RAUHk
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
--------------010706080204060506050309--

--=_=0i0k0i0w0s0o0fXuOi0E0A--
MAILTEST

        my $net = Foswiki::Net->new();

        # Redirect streams so we can capture errors from the sendmail
        # program (which does not use Foswiki::Sandbox)
        my ( $savedOut, $savedErr );

        die "Can't save STDERR: $!"
          unless NOREDIRECT || open( $savedErr, '>&STDERR' );

        die "Can't close original STDERR: $!"
          unless NOREDIRECT || close(STDERR);

        eval {
            # STDERR has been closed
            die "Can't capture STDERR: $!"
              unless NOREDIRECT || open( STDERR, '+>', undef );

            local $/ = undef;
            eval {
                # STDERR has been captured
                die "Can't save STDOUT: $!"
                  unless NOREDIRECT || open( $savedOut, '>&STDOUT' );

                die "Can't close original STDOUT: $!"
                  unless NOREDIRECT || close(STDOUT);

                eval {
                    # STDOUT has been closed
                    die "Can't capture STDOUT: $!"
                      unless NOREDIRECT || open( STDOUT, '+>', undef );
                    eval {
                        eval { $neterrors .= $net->sendEmail( $msg, 1 ); };
                        print $savedErr($@) if $@;
                        $neterrors .= $@ if $@;

                        die "Seek: STDOUT: $!"
                          unless NOREDIRECT || seek( STDOUT, 0, 0 );

                        $stdout = <STDOUT>;
                    };
                    die( ( $@ || '' ) . " Can't close capturing STDOUT: $!" )
                      unless NOREDIRECT || close(STDOUT);
                };

                die( ( $@ || '' ) . " Can't restore STDOUT: $!" )
                  unless NOREDIRECT || open( STDOUT, '>&', $savedOut );
                close $savedOut;

                die "Seek: STDERR: $!"
                  unless NOREDIRECT || seek( STDERR, 0, 0 );
                $stderr = <STDERR> unless NOREDIRECT;
            };

            # Restore captured STDERR
            die( ( $@ || '' ) . " Can't close capturing STDERR: $!" )
              unless NOREDIRECT || close(STDERR);
        };
        die( ( $@ || '' ) . " Can't restore saved STDERR: $!" )
          unless NOREDIRECT || open( STDERR, '>&', $savedErr );
        close $savedErr unless NOREDIRECT;

        # sendmail in debug mode echoes the entire message - twice.
        # We'll remove that from the log.

        if ( $Foswiki::cfg{MailProgram} =~ /(?:^|\b)sendmail(?:\b|$)/ ) {
            if ( $stderr =~ /^(Please install an MTA.*)$/m ) {
                $neterrors .= $1;
            }
            my $stampre = qr/^(?:\d+\s+(<<<|>>>)\s+)/;
            my @lines = split( /\r?\n/, $stderr );

            # This could be an ugly RE, but a state machine is simpler
            $stderr = '';
            my $line;
            my $state = 0;
            while (@lines) {
                $line = shift @lines;
                if ( $state == 0 ) {
                    $stderr .= "$line\n";
                    if ( $line =~ /$stampre/ ) {
                        $state = 1;
                    }
                    next;
                }
                if ( $state == 1 || $state == 3 ) {
                    if ( $line =~ /$stampre$/ ) {
                        $stderr .= " ... Message contents ...\n";
                        $state++;
                        next;
                    }
                    $stderr .= $line . "\n";
                    next;
                }
                if ( $state == 2 ) {
                    next if ( $line !~ /$stampre\[EOF\]$/ );
                    $state++;
                }
                last if ( $line =~ /$stampre\.$/ );
            }
            $stderr .= join( "\n", @lines );
        }
    }

    if ($neterrors) {
        $reporter->ERROR($neterrors);
    }

    if ( $neterrors || $Foswiki::cfg{SMTP}{Debug} ) {
        if ($stdout) {
            $reporter->NOTE( "Mailer output", "PREFORMAT:$stdout" );
        }
        if ($stderr) {
            $stderr =~ s/<a\s+/<a target="_blank" /gms;
            $reporter->NOTE( 'Transcript of e-mail server dialog',
                "PREFORMAT:$stderr" );
        }

        return if $neterrors;
    }

    return $reporter->NOTE(<<ACCEPTED);
Mail was accepted for delivery to $addrs from $Foswiki::cfg{WebMasterEmail}. Be sure to check any SPAM and Bulk-email folders before assuming that delivery has failed.
ACCEPTED
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
