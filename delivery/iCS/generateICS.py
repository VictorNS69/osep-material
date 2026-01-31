#!/usr/bin/env python3
import time
import codecs
import smtplib
import datetime
import sys
import argparse
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email.encoders import encode_base64
from email.mime.multipart import MIMEMultipart
from email.utils import COMMASPACE, formatdate


def parse_event_file():
    """Parse the mail_data.txt file and extract variables marked with ###"""
    variables = {}
    
    try:
        with codecs.open("mail_data.txt", 'r', 'utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("Error: mail_data.txt file not found.")
        print("Please create a mail_data.txt file with the expected format")
        sys.exit(1)
    
    # Split the content by ### markers
    sections = content.split('###')
    
    # Process each section (skip empty ones)
    for i in range(1, len(sections) - 1, 2):  # Skip every other section
        if i + 1 < len(sections):
            # Get the variable name (first line after ###)
            var_section = sections[i].strip()
            if '\n' in var_section:
                var_name = var_section.split('\n')[0].strip()
                var_value = '\n'.join(var_section.split('\n')[1:]).strip()
            else:
                var_name = var_section
                var_value = sections[i + 1].strip()
            
            # Store the variable
            if var_name:
                variables[var_name] = var_value
    
    return variables

def load_template():
    template = ""
    with codecs.open("msTeams-template.html", 'r', 'utf-8') as f:
        template = f.read()
    return template


def prepare_template(event_text, event_url):
    email_template = load_template()
    email_template = email_template.format(EVENT_TEXT=event_text, EVENT_URL=event_url)
    return email_template


def load_ics():
    ics = ""
    with codecs.open("iCalendar_template.ics", 'r', 'utf-8') as f:
        ics = f.read()
    return ics


def prepare_ics(dtstamp, dtstart, dtend, sender_email, event_url, event_summary, organizer_name, attendees):
    ics_template = load_ics()
    ics_template = ics_template.format(
        DTSTAMP=dtstamp,
        DTSTART=dtstart,
        DTEND=dtend,
        ORGANIZER_NAME=organizer_name,
        ORGANIZER_EMAIL=sender_email,
        DESCRIPTION=event_url,  # Use event_url as DESCRIPTION
        SUMMARY=event_summary,
        ATTENDEES=generate_attendees(attendees)
    )
    return ics_template


def generate_attendees(attendees):
    attendees_ics = []
    for attendee in attendees:
        attendees_ics.append(
            "ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;RSVP=FALSE\r\n ;CN={attendee};X-NUM-GUESTS=0:\r\n mailto:{attendee}".format(attendee=attendee)
        )
    return "\r\n".join(attendees_ics)


def send_email(smtp_server, sender_email, to, event_url, event_file_vars):
    print(f'Sending email to: {to}')
    
    # Extract variables from event file
    email_subject = event_file_vars.get('EMAIL_SUBJECT', 'Meeting Invitation')
    event_summary = event_file_vars.get('EVENT_SUMMARY', 'Meeting')
    organizer_name = event_file_vars.get('ORGANIZER_NAME', '')
    event_text = event_file_vars.get('EVENT_TEXT', '')
    
    # in .ics file timezone is set to be utc
    utc_offset = time.localtime().tm_gmtoff / 60
    ddtstart = datetime.datetime.now()
    dtoff = datetime.timedelta(minutes=utc_offset + 5)  # meeting has started 5 minutes ago
    duration = datetime.timedelta(hours=1)  # meeting duration
    ddtstart = ddtstart - dtoff
    dtend = ddtstart + duration
    dtstamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%SZ")
    dtstart = ddtstart.strftime("%Y%m%dT%H%M%SZ")
    dtend = dtend.strftime("%Y%m%dT%H%M%SZ")
    
    # Use all attendees for the ICS file
    all_attendees = [to] if isinstance(to, str) else to
    
    ics = prepare_ics(dtstamp, dtstart, dtend, sender_email, event_url, 
                      event_summary, organizer_name, all_attendees)
    email_body = prepare_template(event_text, event_url)
    
    msg = MIMEMultipart('mixed')
    msg['Reply-To'] = sender_email
    msg['Date'] = formatdate(localtime=True)
    msg['Subject'] = email_subject
    msg['From'] = sender_email
    msg['To'] = to if isinstance(to, str) else COMMASPACE.join(to)
    
    part_email = MIMEText(email_body, "html")
    part_cal = MIMEText(ics, 'calendar;method=REQUEST')
    
    msgAlternative = MIMEMultipart('alternative')
    msg.attach(msgAlternative)
    
    ics_atch = MIMEBase('application/ics', ' ;name="%s"' % ("invite.ics"))
    ics_atch.set_payload(ics)
    encode_base64(ics_atch)
    ics_atch.add_header('Content-Disposition', 'attachment; filename="%s"' % ("invite.ics"))
    
    eml_atch = MIMEBase('text/plain', '')
    eml_atch.set_payload("")
    encode_base64(eml_atch)
    eml_atch.add_header('Content-Transfer-Encoding', "")
    
    msgAlternative.attach(part_email)
    msgAlternative.attach(part_cal)
    
    mailServer = smtplib.SMTP(smtp_server, 25)
    mailServer.ehlo()
    mailServer.ehlo()
    
    # Handle both single recipient and multiple recipients
    if isinstance(to, list):
        mailServer.sendmail(sender_email, to, msg.as_string())
    else:
        mailServer.sendmail(sender_email, [to], msg.as_string())
        
    mailServer.close()


def main():
    parser = argparse.ArgumentParser(
        description='Send calendar meeting invitations via email.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  python generateICS.py --smtp-server smtp.example.com \\
                        --sender sender@example.com \\
                        --recipient "user1@example.com,user2@example.com" \\
                        --event-url "https://meet.example.com/meeting-id"
  
  To actually send emails (default is dry-run):
  python generateICS.py --smtp-server smtp.example.com \\
                        --sender sender@example.com \\
                        --recipient "user1@example.com" \\
                        --event-url "https://meet.example.com/meeting-id" \\
                        --send-campaign
        """
    )
    
    parser.add_argument('--smtp-server', required=True,
                       help='SMTP server address (e.g., smtp.example.com)')
    
    parser.add_argument('--sender', required=True,
                       help='Sender email address')
    
    parser.add_argument('--recipient', required=True,
                       help='Recipient email address(es), comma-separated for multiple')
    
    parser.add_argument('--event-url', required=True,
                       help='Event/meeting URL')
    
    parser.add_argument('--send-campaign', action='store_true', default=False,
                       help='Actually send emails (default is dry-run mode)')
    
    args = parser.parse_args()
    
    # Parse the mail_data.txt file to get variables
    event_file_vars = parse_event_file()
    
    # Parse recipients (handle single or multiple)
    if ',' in args.recipient:
        recipients = [email.strip() for email in args.recipient.split(',')]
    else:
        recipients = args.recipient
    
    print(f"SMTP Server: {args.smtp_server}")
    print(f"Sender: {args.sender}")
    print(f"Recipient(s): {recipients}")
    print(f"Event URL: {args.event_url}")
    print(f"Send Campaign: {args.send_campaign}")
    print(f"Extracted variables from mail_data.txt: {list(event_file_vars.keys())}")
    
    # Check if all required variables are present
    required_vars = ['EMAIL_SUBJECT', 'EVENT_SUMMARY', 'ORGANIZER_NAME', 'EVENT_TEXT']
    for var in required_vars:
        if var not in event_file_vars:
            print(f"Warning: Required variable '{var}' not found in mail_data.txt")
    
    if args.send_campaign:
        print("\n=== SENDING EMAILS ===")
        # Send email(s)
        if isinstance(recipients, list):
            for recipient in recipients:
                try:
                    send_email(args.smtp_server, args.sender, recipient, 
                              args.event_url, event_file_vars)
                    print(f"✓ Email sent to {recipient}")
                except Exception as e:
                    print(f"✗ Failed to send email to {recipient}: {e}")
        else:
            try:
                send_email(args.smtp_server, args.sender, recipients, 
                          args.event_url, event_file_vars)
                print("✓ Email sent successfully")
            except Exception as e:
                print(f"✗ Failed to send email: {e}")
    else:
        print("\n=== DRY RUN MODE ===")
        print("Emails are NOT being sent (use --send-campaign to actually send)")
        print("\nEmail details that would be sent:")
        print(f"Subject: {event_file_vars.get('EMAIL_SUBJECT', 'Meeting Invitation')}")
        print(f"From: {args.sender}")
        print(f"To: {recipients}")
        print(f"Event Summary: {event_file_vars.get('EVENT_SUMMARY', 'Meeting')}")
        print(f"Organizer: {event_file_vars.get('ORGANIZER_NAME', '')}")
        print(f"Event Text Preview: {event_file_vars.get('EVENT_TEXT', '')[:100]}...")
        
        # Show what would be sent to each recipient
        if isinstance(recipients, list):
            print(f"\nWould send to {len(recipients)} recipients:")
            for i, recipient in enumerate(recipients, 1):
                print(f"  {i}. {recipient}")
        else:
            print(f"\nWould send to 1 recipient: {recipients}")


if __name__ == "__main__":
    main()
