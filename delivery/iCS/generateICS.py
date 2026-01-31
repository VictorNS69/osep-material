#!/usr/bin/env python3
# -*- coding: utf-8 -*-

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

# Color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'
    GRAY = '\033[90m'

# Helper functions for colored output
def print_error(message):
    print(f"{Colors.RED}{Colors.BOLD}[ERROR]{Colors.END} {Colors.RED}{message}{Colors.END}")

def print_warning(message):
    print(f"{Colors.YELLOW}{Colors.BOLD}[WARNING]{Colors.END} {Colors.YELLOW}{message}{Colors.END}")

def print_success(message):
    print(f"{Colors.GREEN}{Colors.BOLD}[SUCCESS]{Colors.END} {Colors.GREEN}{message}{Colors.END}")

def print_info(message):
    print(f"{Colors.CYAN}{Colors.BOLD}[INFO]{Colors.END} {Colors.WHITE}{message}{Colors.END}")

def print_debug(message):
    print(f"{Colors.GRAY}[DEBUG]{Colors.END} {Colors.GRAY}{message}{Colors.END}")

def print_header(message):
    print(f"\n{Colors.BLUE}{Colors.BOLD}{'='*60}{Colors.END}")
    print(f"{Colors.BLUE}{Colors.BOLD}{message.center(60)}{Colors.END}")
    print(f"{Colors.BLUE}{Colors.BOLD}{'='*60}{Colors.END}")

def print_step(message):
    print(f"{Colors.MAGENTA}{Colors.BOLD}→{Colors.END} {Colors.MAGENTA}{message}{Colors.END}")


def parse_event_file():
    """Parse the mail_data.txt file and extract variables marked with ###"""
    variables = {}
    
    try:
        with codecs.open("mail_data.txt", 'r', 'utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print_error("mail_data.txt file not found.")
        print_info("Please create a mail_data.txt file with the expected format")
        sys.exit(1)
    
    # Use regex to find all sections between ### markers
    import re
    # Pattern to match ### VARIABLE_NAME ... ###
    pattern = r'###\s*([A-Z_]+)\s*\n(.*?)\s*###'
    matches = re.findall(pattern, content, re.DOTALL)
    
    for var_name, var_value in matches:
        variables[var_name] = var_value.strip()
    
    # Alternative simpler pattern if the above doesn't work
    if not variables:
        # Try a simpler approach - split by ### and process
        sections = [s.strip() for s in content.split('###') if s.strip()]
        for i in range(0, len(sections), 2):
            if i + 1 < len(sections):
                var_section = sections[i]
                # Get first line as variable name, rest as value
                lines = var_section.split('\n', 1)
                if lines:
                    var_name = lines[0].strip()
                    var_value = lines[1].strip() if len(lines) > 1 else ""
                    variables[var_name] = var_value
    
    if not variables:
        print_warning("No variables found in mail_data.txt. Using default values.")
    else:
        print_success(f"Loaded {len(variables)} variables from mail_data.txt")
    
    return variables


def load_template():
    try:
        with codecs.open("msTeams-template.html", 'r', 'utf-8') as f:
            template = f.read()
        print_success("Loaded email template from emsTeams-template.html")
        return template
    except FileNotFoundError:
        print_error("msTeams-template.html file not found.")
        sys.exit(1)


def prepare_template(event_text, event_url):
    email_template = load_template()
    email_template = email_template.format(EVENT_TEXT=event_text, EVENT_URL=event_url)
    return email_template


def load_ics():
    try:
        with codecs.open("iCalendar_template.ics", 'r', 'utf-8') as f:
            ics = f.read()
        print_success("Loaded iCalendar template from iCalendar_template.ics")
        return ics
    except FileNotFoundError:
        print_error("iCalendar_template.ics file not found.")
        sys.exit(1)


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
    print_step(f'Sending email to: {to}')
    
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
    
    try:
        print_step(f"Connecting to SMTP server: {smtp_server}:25")
        mailServer = smtplib.SMTP(smtp_server, 25)
        mailServer.ehlo()
        mailServer.ehlo()
        
        # Handle both single recipient and multiple recipients
        if isinstance(to, list):
            mailServer.sendmail(sender_email, to, msg.as_string())
        else:
            mailServer.sendmail(sender_email, [to], msg.as_string())
            
        mailServer.close()
        print_success(f"Email sent successfully to {to}")
        return True
    except Exception as e:
        print_error(f"Failed to send email to {to}: {e}")
        return False


def main():
    print_header("EMAIL CAMPAIGN SENDER")
    
    parser = argparse.ArgumentParser(
        description='Send calendar meeting invitations via email.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""{Colors.GREEN}
Example usage:
  {Colors.CYAN}python generateICS.py --smtp-server smtp.example.com \\
                        --sender sender@example.com \\
                        --recipient "user1@example.com,user2@example.com" \\
                        --event-url "https://meet.example.com/meeting-id"{Colors.END}
  
  {Colors.GREEN}To actually send emails (default is dry-run):{Colors.END}
  {Colors.CYAN}python generateICS.py --smtp-server smtp.example.com \\
                        --sender sender@example.com \\
                        --recipient "user1@example.com" \\
                        --event-url "https://meet.example.com/meeting-id" \\
                        --send-campaign{Colors.END}
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
    
    print_step("Parsing configuration...")
    print_info(f"SMTP Server: {Colors.BOLD}{args.smtp_server}{Colors.END}")
    print_info(f"Sender: {Colors.BOLD}{args.sender}{Colors.END}")
    print_info(f"Event URL: {Colors.BOLD}{args.event_url}{Colors.END}")
    
    # Parse the mail_data.txt file to get variables
    print_step("Loading email data from mail_data.txt...")
    event_file_vars = parse_event_file()
    
    # Parse recipients (handle single or multiple)
    if ',' in args.recipient:
        recipients = [email.strip() for email in args.recipient.split(',')]
        print_info(f"Recipients: {Colors.BOLD}{len(recipients)} recipients{Colors.END}")
    else:
        recipients = args.recipient
        print_info(f"Recipient: {Colors.BOLD}{recipients}{Colors.END}")
    
    # Check if all required variables are present
    required_vars = ['EMAIL_SUBJECT', 'EVENT_SUMMARY', 'ORGANIZER_NAME', 'EVENT_TEXT']
    missing_vars = []
    for var in required_vars:
        if var not in event_file_vars:
            missing_vars.append(var)
    
    if missing_vars:
        print_warning(f"Missing required variables: {', '.join(missing_vars)}")
        for var in missing_vars:
            print_warning(f"  - {var} will use default value")
    
    if args.send_campaign:
        print_header("SENDING EMAILS")
        print_warning("THIS WILL ACTUALLY SEND EMAILS!")
        
        # Ask for confirmation
        response = input(f"{Colors.YELLOW}Are you sure you want to send emails? (yes/NO): {Colors.END}")
        if response.lower() not in ['yes', 'y']:
            print_info("Campaign cancelled.")
            sys.exit(0)
        
        # Send email(s)
        success_count = 0
        fail_count = 0
        
        if isinstance(recipients, list):
            print_step(f"Starting campaign to {len(recipients)} recipients...")
            for i, recipient in enumerate(recipients, 1):
                print_step(f"Processing {i}/{len(recipients)}: {recipient}")
                if send_email(args.smtp_server, args.sender, recipient, 
                              args.event_url, event_file_vars):
                    success_count += 1
                else:
                    fail_count += 1
                print("")  # Empty line between emails
        else:
            print_step(f"Sending to single recipient: {recipients}")
            if send_email(args.smtp_server, args.sender, recipients, 
                          args.event_url, event_file_vars):
                success_count += 1
            else:
                fail_count += 1
        
        # Campaign summary
        print_header("CAMPAIGN SUMMARY")
        if success_count > 0:
            print_success(f"Successfully sent: {success_count} email(s)")
        if fail_count > 0:
            print_error(f"Failed to send: {fail_count} email(s)")
        
        if success_count == 0 and fail_count > 0:
            print_error("All emails failed to send. Please check your configuration.")
        elif success_count > 0:
            print_success("Campaign completed!")
            
    else:
        print_header("DRY RUN MODE")
        print_warning("Emails are NOT being sent (use --send-campaign to actually send)")
        
        print_step("Configuration Summary:")
        print_info(f"Subject: {Colors.BOLD}{event_file_vars.get('EMAIL_SUBJECT', 'Meeting Invitation')}{Colors.END}")
        print_info(f"From: {Colors.BOLD}{args.sender}{Colors.END}")
        print_info(f"Event Summary: {Colors.BOLD}{event_file_vars.get('EVENT_SUMMARY', 'Meeting')}{Colors.END}")
        print_info(f"Organizer: {Colors.BOLD}{event_file_vars.get('ORGANIZER_NAME', '')}{Colors.END}")
        
        event_text_preview = event_file_vars.get('EVENT_TEXT', '')
        if len(event_text_preview) > 100:
            print_info(f"Event Text: {Colors.BOLD}{event_text_preview[:100]}...{Colors.END}")
        else:
            print_info(f"Event Text: {Colors.BOLD}{event_text_preview}{Colors.END}")
        
        print_step("Recipient List:")
        if isinstance(recipients, list):
            print_info(f"Would send to {Colors.BOLD}{len(recipients)}{Colors.END} recipients:")
            for i, recipient in enumerate(recipients, 1):
                print_info(f"  {i}. {recipient}")
        else:
            print_info(f"Would send to: {Colors.BOLD}{recipients}{Colors.END}")
        
        print_step("SMTP Details:")
        print_info(f"Server: {Colors.BOLD}{args.smtp_server}:25{Colors.END}")
        
        print_warning("\nTo actually send emails, run with: --send-campaign")


if __name__ == "__main__":
    main()
